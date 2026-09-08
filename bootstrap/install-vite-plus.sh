#!/bin/bash
# Optional Vite+ install; do not replace mise's Node management.
set -euo pipefail
version=0.3.0
expected=3dd88cedb6d9b2665c305eda5413971417c8f183a819386148131b66a2cc6b2e
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl -fL --retry 3 "https://raw.githubusercontent.com/voidzero-dev/vite-plus/v${version}/packages/cli/install.sh" -o "$installer"
printf '%s  %s\n' "$expected" "$installer" | sha256sum --check --status
VP_HOME="$HOME/.vite-plus" VP_NODE_MANAGER=no VP_VERSION="$version" bash "$installer"
