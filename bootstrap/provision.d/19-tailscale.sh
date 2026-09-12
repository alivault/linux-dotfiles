#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

ensure_package tailscale
sudo systemctl enable --now tailscaled.service

if systemctl --user cat omarchy-tailscale-receive.service >/dev/null 2>&1; then
  systemctl --user enable --now omarchy-tailscale-receive.service
fi

if tailscale status >/dev/null 2>&1; then
  sudo tailscale set --operator="$USER"
else
  printf '%s\n' \
    'Tailscale is installed but not authenticated.' \
    'After bootstrap, run: sudo tailscale up --accept-routes'
fi
