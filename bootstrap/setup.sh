#!/bin/bash
# Explicit ALNIAC personal-configuration pipeline; never a chezmoi apply hook.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
(( $# <= 1 )) || { echo 'Usage: setup.sh [--plan|--apply]' >&2; exit 2; }
case ${1:-} in ''|--plan|--apply) ;; *) echo 'Usage: setup.sh [--plan|--apply]' >&2; exit 2 ;; esac
cat <<'PLAN'
ALNIAC workstation configuration (install ALNIAC itself first):
  1. Review and apply the chezmoi user configuration from this checkout.
  2. Explicitly provision session units, Kitty, mise tools, Vite+, keyd, apps,
     voxtype, AirPods and sync services.
  3. Run the bootstrap health check.
Provisioning may request sudo and start/reload keyd, Syncthing and Tailscale.
No disk, bootloader, login-manager, desktop-session replacement or reboot actions.
PLAN
[[ ${1:-} != --plan ]] || exit 0
[[ $EUID != 0 ]] || { echo 'Run as your desktop user, not root.' >&2; exit 1; }
command -v chezmoi >/dev/null || { echo 'Install chezmoi first.' >&2; exit 1; }
[[ -x $HOME/.local/share/alniac/current/bin/alniac-version && -d $HOME/code/alniac/.git ]] ||
  { echo 'This repository requires ALNIAC: a staged release and ~/code/alniac.' >&2; exit 1; }

confirm() {
  local answer
  [[ ${1:-} != --apply ]] || return 0
  read -r -p 'Proceed? [y/N] ' answer </dev/tty
  [[ $answer == y || $answer == Y ]]
}
confirm "${1:-}" || exit 0
install -d -m 700 "${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi/tmp"
chezmoi init --source "$root/.."
chezmoi --source "$root/.." diff --exclude scripts
confirm "${1:-}" || exit 0
chezmoi --source "$root/.." apply --exclude scripts
bash "$root/provision.sh"
bash "$root/doctor.sh"
printf '%s\n' 'Complete. Sign in to apps and pair sync devices manually; no credentials were imported.'
