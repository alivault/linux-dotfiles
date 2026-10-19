#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# Chezmoi links ALNIAC's user units into ~/.config/systemd/user; the login
# (alniac-session) starts alniac.service and needs every link to resolve.
units="$HOME/.config/systemd/user"
for unit in alniac alniac-audio alniac-bt-agent alniac-crash-watch alniac-fcitx5 alniac-tailscale-receive; do
  [[ -f $units/$unit.service ]] ||
    bootstrap_die "missing or broken ALNIAC unit link: $units/$unit.service (run chezmoi apply)"
done

systemctl --user daemon-reload
bootstrap_log "ALNIAC session units are linked to the staged release"
