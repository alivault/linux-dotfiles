#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

ensure_package keyd

config="$script_dir/files/keyd-default.conf"
keyd check "$config"

if ! cmp -s "$config" /etc/keyd/default.conf; then
  sudo install -d -o root -g root -m 0755 /etc/keyd

  if [[ -e /etc/keyd/default.conf ]]; then
    sudo cp -a /etc/keyd/default.conf \
      "/etc/keyd/default.conf.bak.$(date +%s)"
  fi

  sudo install -o root -g root -m 0644 "$config" /etc/keyd/default.conf
  sudo keyd check /etc/keyd/default.conf
fi

if systemctl is-active --quiet keyd; then
  sudo keyd reload
else
  sudo systemctl enable --now keyd
fi
