#!/usr/bin/env bash

set -euo pipefail

pane_id=${1:?missing Herdr pane ID}
socket_path=${2:-}
herdr_bin=${3:-$(command -v herdr)}
plugin_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

[[ -z $socket_path ]] || export HERDR_SOCKET_PATH=$socket_path
# Resolve before changing Herdr's selection; refuse ambiguous windows.
window_id=$("$plugin_root/find-herdr-window.sh")

# Select the workspace, tab, and exact pane before raising the terminal so the
# requested agent is already visible when the Kitty window receives focus.
if [[ -n $socket_path ]]; then
  HERDR_SOCKET_PATH=$socket_path "$herdr_bin" agent focus "$pane_id" >/dev/null
else
  "$herdr_bin" agent focus "$pane_id" >/dev/null
fi

niri msg action focus-window --id "$window_id" >/dev/null
