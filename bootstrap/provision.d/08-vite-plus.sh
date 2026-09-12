#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

vp_bin="$HOME/.vite-plus/bin/vp"
if [[ -x $vp_bin && -r $HOME/.vite-plus/env ]]; then
  bootstrap_log "Vite+ is already installed: $($vp_bin --version | head -n 1)"
  exit 0
fi

version=0.3.0
installer_url="https://raw.githubusercontent.com/voidzero-dev/vite-plus/v${version}/packages/cli/install.sh"
installer_sha256=3dd88cedb6d9b2665c305eda5413971417c8f183a819386148131b66a2cc6b2e
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT

download_verified "$installer_url" "$installer" "$installer_sha256"
VP_HOME="$HOME/.vite-plus" VP_NODE_MANAGER=no VP_VERSION="$version" bash "$installer"

[[ -x $vp_bin ]] || bootstrap_die "Vite+ executable was not installed"
[[ -r $HOME/.vite-plus/env ]] || bootstrap_die "Vite+ environment file was not installed"
