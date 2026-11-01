#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# Chezmoi links Oasis's user units into ~/.config/systemd/user; the login
# (oasis-session) starts oasis.service and needs every link to resolve.
units="$HOME/.config/systemd/user"
for unit in oasis oasis-audio oasis-bt-agent oasis-crash-watch oasis-fcitx5 oasis-tailscale-receive; do
  [[ -f $units/$unit.service ]] ||
    bootstrap_die "missing or broken Oasis unit link: $units/$unit.service (run chezmoi apply)"
done

systemctl --user daemon-reload
bootstrap_log "Oasis session units are linked to the staged release"
