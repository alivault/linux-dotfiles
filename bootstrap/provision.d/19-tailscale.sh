#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

ensure_package tailscale
sudo systemctl enable --now tailscaled.service

# Taildrop receiving is the ALNIAC session unit alniac-tailscale-receive.service.

if tailscale status >/dev/null 2>&1; then
  sudo tailscale set --operator="$USER"
else
  printf '%s\n' \
    'Tailscale is installed but not authenticated.' \
    'After bootstrap, run: sudo tailscale up --accept-routes'
fi
