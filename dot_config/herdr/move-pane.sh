#!/usr/bin/env bash
# Custom commands provide the focused pane and the running Herdr's binary.
set -euo pipefail

herdr=${HERDR_BIN_PATH:?Herdr must supply its binary path}
pane=${HERDR_ACTIVE_PANE_ID:?Herdr must supply the active pane}

case "${1:-}" in
  new)
    exec "$herdr" pane move "$pane" --new-tab --focus
    ;;
  previous)
    # Resolve live ownership rather than relying on inherited tab/workspace IDs.
    current=$("$herdr" pane get "$pane")
    workspace=$(jq -er '.result.pane.workspace_id' <<< "$current")
    tab=$(jq -er '.result.pane.tab_id' <<< "$current")
    tabs=$("$herdr" tab list --workspace "$workspace")
    previous=$(jq -r --arg tab "$tab" '
      .result.tabs | sort_by(.number) | map(.tab_id) |
      index($tab) as $index |
      if length < 2 or $index == null then empty
      else .[($index - 1 + length) % length] end
    ' <<< "$tabs")
    # There is nowhere to join when this workspace has only one tab.
    [[ -n "$previous" ]] || exit 0
    exec "$herdr" pane move "$pane" --tab "$previous" --split down --focus
    ;;
  *)
    echo "Usage: $0 new|previous" >&2
    exit 2
    ;;
esac
