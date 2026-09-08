#!/bin/bash
# Explicit fresh-machine pipeline, never a chezmoi hook.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
(( $# <= 1 )) || { echo 'Unexpected setup arguments.' >&2; exit 2; }
case ${1:-} in ''|--plan|--apply) ;; *) echo 'Usage: setup.sh [--plan|--apply]' >&2; exit 2 ;; esac
cat <<'PLAN'
Standalone Arch desktop setup (no package removal, reboot or disk/bootloader changes):
  1. Install reviewed official packages (update Arch fully before starting).
  2. Preview and apply user configuration; existing runtime identities remain local.
  3. Install pinned tools and dictation model, Bitwarden (user Flathub), build greeter.
  4. Review/install system policies and keyd; enable services for next boot.
  5. Configure password-protected Noctalia login; preserve existing autologin if present.
  6. Check configuration and print manual account/device setup steps.
System authentication is handled locally by pkexec. No automatic service restarts.
PLAN
[[ ${1:-} != --plan ]] || exit 0
[[ $EUID != 0 ]] || { echo 'Run as your desktop user, not root.' >&2; exit 1; }
if [[ ${1:-} != --apply ]]; then
  exec </dev/tty
  read -r -p 'Proceed with this setup? [y/N] ' answer </dev/tty
  [[ $answer == y || $answer == Y ]] || exit 0
fi
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
command -v pkexec >/dev/null || { echo 'Install polkit first (local administrator action).' >&2; exit 1; }
bash "$root/provision.sh" packages
install -d -m 700 "$HOME/.cache/chezmoi/tmp"
install -d "$HOME/Pictures/Wallpapers"
chezmoi init --source "$root/.."
chezmoi --source "$root/.." diff --exclude scripts
if [[ ${1:-} != --apply ]]; then
  read -r -p 'Apply the displayed configuration diff? [y/N] ' answer </dev/tty
  [[ $answer == y || $answer == Y ]] || exit 0
fi
# Do not force-overwrite: chezmoi retains its own conflict prompts.
chezmoi --source "$root/.." apply --exclude scripts
bash "$root/provision.sh" tools
bash "$root/provision.sh" editor
bash "$root/provision.sh" pi-packages
bash "$root/provision.sh" model
bash "$root/provision.sh" bitwarden
bash "$root/provision.sh" greeter --apply
bash "$root/provision.sh" system
bash "$root/provision.sh" system --apply
bash "$root/provision.sh" services
bash "$root/provision.sh" appearance
bash "$root/provision.sh" login --apply
bash "$root/provision.sh" doctor
cat <<'DONE'
Setup checks passed. Review bootstrap/README.md before rebooting.
Manual: Pi/Codex login; Bitwarden login; tailscale up; SSH keys; Syncthing device/folder
pairing (http://127.0.0.1:8384); Obsidian vault selection; printer configuration.
No credentials, device identities, Docker-group grants or firewall rules were imported.
After reboot, test lock/unlock, suspend, audio, screen sharing, printing and dictation.
DONE
