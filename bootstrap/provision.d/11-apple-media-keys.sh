#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

if ! is_asahi; then
  bootstrap_log "Skipping Apple media keys: not an Asahi machine"
  exit 0
fi

require_command sudo mkinitcpio

config="$script_dir/files/apple-media-keys.conf"
# Load after Omarchy's hid_apple.conf without replacing other driver options.
destination=/etc/modprobe.d/zz-apple-media-keys.conf

if ! cmp -s "$config" "$destination"; then
  sudo install -d -o root -g root -m 0755 /etc/modprobe.d
  if [[ -e $destination ]]; then
    sudo cp -a "$destination" "$destination.bak.$(date +%s)"
  fi
  sudo install -o root -g root -m 0644 "$config" "$destination"
fi

if [[ -e /sys/module/hid_apple/parameters/fnmode ]]; then
  printf '1\n' | sudo tee /sys/module/hid_apple/parameters/fnmode >/dev/null
fi

# Rebuild even on a rerun so an interrupted/failed previous build is retried.
sudo mkinitcpio -P
bootstrap_log "Apple media keys enabled; hold Fn for F1-F12"
