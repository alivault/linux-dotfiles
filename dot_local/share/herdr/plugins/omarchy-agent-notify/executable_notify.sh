#!/usr/bin/env bash

set -euo pipefail

event_json=${HERDR_PLUGIN_EVENT_JSON:-}
context_json=${HERDR_PLUGIN_CONTEXT_JSON:-}
herdr_bin=${HERDR_BIN_PATH:-herdr}
plugin_root=${HERDR_PLUGIN_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
state_dir=${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/herdr/omarchy-agent-notify}

[[ -n $event_json ]] || exit 0
[[ -n $context_json ]] || context_json='{}'

status=$(jq -r '.data.agent_status // empty | ascii_downcase' <<<"$event_json")
pane_id=$(jq -r '.data.pane_id // empty' <<<"$event_json")

[[ -n $status && -n $pane_id ]] || exit 0
[[ $(jq -r '.data.agent // empty' <<<"$event_json") == pi ]] || exit 0

# Event hooks can repeat when presentation metadata changes without a state
# transition. Remember every state, but notify only on entry into done/blocked.
mkdir -p "$state_dir/status"
state_key=$(printf '%s:%s' "${HERDR_SOCKET_PATH:-}" "$pane_id" | sha256sum | cut -d ' ' -f 1)
state_file="$state_dir/status/$state_key"
exec 9>"$state_dir/status.lock"
flock 9
previous=$(cat "$state_file" 2>/dev/null || true)
printf '%s\n' "$status" >"$state_file"
flock -u 9

[[ $status == done || $status == blocked || ( $status == idle && $previous == working ) ]] || exit 0
[[ $previous != "$status" ]] || exit 0

# Match Herdr's default delay and drop stale notifications if the agent moved
# to another state during that delay.
sleep 1
agent_json=$($herdr_bin agent get "$pane_id" 2>/dev/null) || exit 0
current_status=$(jq -r '.result.agent.agent_status // empty | ascii_downcase' <<<"$agent_json")
[[ $current_status == "$status" ]] || exit 0

# Do not notify when this exact pane is already visible in the active Herdr
# terminal. A focused pane still notifies when the user is in another app.
pane_focused=$(jq -r '.result.agent.focused // false' <<<"$agent_json")
herdr_window=$("$plugin_root/find-herdr-window.sh")
active_window=$(niri msg --json focused-window | jq -r '.id // empty')
if [[ $pane_focused == true && -n $herdr_window && $active_window == "$herdr_window" ]]; then
  exit 0
fi

agent=$(jq -r '.data.display_agent // .data.agent // "agent"' <<<"$event_json")
workspace=$(jq -r '.workspace_label // .workspace_id // "Herdr"' <<<"$context_json")
tab=$(jq -r '.tab_label // empty' <<<"$context_json")

case $status in
  blocked) event_text="needs attention" ;;
  done|idle) event_text="finished" ;;
esac

agent=${agent^}
title="$agent $event_text"
body=$workspace
if [[ -n $tab && ! $tab =~ ^[0-9]+$ ]]; then
  body+=" · $tab"
fi

session_name=$(jq -r '.result.agent.tokens.session_name // empty' <<<"$agent_json")
[[ -z $session_name ]] || body+=" · $session_name"
identity=$(jq -c '.result.agent | {terminal_id, agent_session}' <<<"$agent_json")
python3 "$plugin_root/desktop-notify.py" --spawn "$pane_id" "$title" "$body" "$identity"
