#!/bin/bash

set -euo pipefail

if [[ -x "$HOME/.vite-plus/bin/vp" && -r "$HOME/.vite-plus/env" ]]; then
  exit 0
fi

curl -fsSL https://vite.plus | \
  VP_HOME="$HOME/.vite-plus" VP_NODE_MANAGER=no bash

[[ -x "$HOME/.vite-plus/bin/vp" ]]
[[ -r "$HOME/.vite-plus/env" ]]
