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
saved=$(mktemp -d)
trap 'rm -rf "$installer" "$saved"' EXIT

# The installer appends a source line to every shell profile it finds and has
# no option to skip it. ~/.bashrc (chezmoi) already sources ~/.vite-plus/env,
# so the profiles are saved first and put back afterwards.
profiles=("$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile")
for f in "${profiles[@]}"; do
  [[ -f $f ]] && cp -p "$f" "$saved/${f##*/}"
done

download_verified "$installer_url" "$installer" "$installer_sha256"
VP_HOME="$HOME/.vite-plus" VP_NODE_MANAGER=no VP_VERSION="$version" bash "$installer"

# (It only edits profiles that exist, so there is nothing new to take away.)
for f in "${profiles[@]}"; do
  [[ -f $saved/${f##*/} ]] && cp -p "$saved/${f##*/}" "$f"
done

[[ -x $vp_bin ]] || bootstrap_die "Vite+ executable was not installed"
[[ -r $HOME/.vite-plus/env ]] || bootstrap_die "Vite+ environment file was not installed"
