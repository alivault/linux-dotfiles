#!/bin/bash
# Explicit Omarchy configuration pipeline; never a chezmoi apply hook.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
(( $# <= 1 )) || { echo 'Usage: setup.sh [--plan|--apply]' >&2; exit 2; }
case ${1:-} in ''|--plan|--apply) ;; *) echo 'Usage: setup.sh [--plan|--apply]' >&2; exit 2 ;; esac
cat <<'PLAN'
Omarchy 4 workstation configuration (install Omarchy itself first):
  1. Review and apply the chezmoi user configuration from this checkout.
  2. Explicitly provision Kitty, mise tools, Vite+, keyd, apps and sync services.
  3. Activate the restored Ashen theme and run the bootstrap health check.
Provisioning may request sudo and start/reload keyd, Syncthing and Tailscale.
No disk, bootloader, login-manager, desktop-session replacement or reboot actions.
PLAN
[[ ${1:-} != --plan ]] || exit 0
[[ $EUID != 0 ]] || { echo 'Run as your desktop user, not root.' >&2; exit 1; }
for command_name in chezmoi omarchy; do
  command -v "$command_name" >/dev/null || { echo "Install $command_name first." >&2; exit 1; }
done
case $(omarchy version) in 4.*) ;; *) echo 'This repository requires Omarchy 4.' >&2; exit 1 ;; esac

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
omarchy theme set ashen
bash "$root/doctor.sh"
printf '%s\n' 'Complete. Sign in to apps and pair sync devices manually; no credentials were imported.'
