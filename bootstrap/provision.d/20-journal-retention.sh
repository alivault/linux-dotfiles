#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

require_command sudo systemctl

config="$script_dir/files/journald-retention.conf"
destination=/etc/systemd/journald.conf.d/retention.conf

if ! cmp -s "$config" "$destination"; then
  bootstrap_log "Applying 256 MiB / 7-day journal limits; older diagnostics may be deleted"
  sudo install -d -o root -g root -m 0755 /etc/systemd/journald.conf.d
  if [[ -e $destination ]]; then
    sudo cp -a "$destination" "$destination.bak.$(date +%s)"
  fi
  sudo install -o root -g root -m 0644 "$config" "$destination"
fi

# Also retry activation if a previous provisioning run was interrupted.
sudo systemctl restart systemd-journald.service
bootstrap_log "Journal retention applied; firewall logging and keyboard settings unchanged"
