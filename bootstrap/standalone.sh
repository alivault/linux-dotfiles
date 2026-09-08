#!/bin/bash
# Explicit provisioning only: chezmoi apply never installs packages or services.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case ${1:---help} in
  system|greeter)
    if (( $# > 2 )) || [[ -n ${2:-} && ${2:-} != --apply ]]; then
      echo 'Only an explicit --apply flag is accepted for this action.' >&2; exit 2
    fi ;;
  login)
    for argument in "${@:2}"; do
      case $argument in
        --apply|--autologin) ;;
        --help) exec python3 "$root/configure-login.py" --help ;;
        *) echo 'Unexpected login argument; use login --help.' >&2; exit 2 ;;
      esac
    done ;;
  *) if (( $# > 1 )); then echo 'Unexpected arguments; use --help.' >&2; exit 2; fi ;;
esac
case ${1:---help} in
  --help|--list)
    printf '%s\n' \
      'Usage: bash bootstrap/provision.sh packages|tools|editor|pi-packages|model|bitwarden|vite-plus|greeter|system|appearance|services|login|doctor' \
      'appearance: select Adwaita desktop icons for the current user' \
      'system: preview standalone system settings; explicit --apply requires local pkexec authentication' \
      'tools: install hash-pinned upstream apps and mise-managed tools' \
      'pi-packages: install the reviewed Pi extension versions (extensions execute code)' \
      'editor: restore LazyVim plugins to the checked-in lockfile' \
      'model: install/verify the pinned dictation model' \
      'bitwarden: install the desktop app from Flathub for this user' \
      'vite-plus: optional pinned Vite+; mise remains the Node manager' \
      'greeter: build the pinned greeter; --apply explicitly installs it' \
      'packages: install approved official-repository packages (no removals)' \
      'services: enable requested services, without starting/restarting them' \
      'login: preview greetd setup; --apply enables it for next boot; --autologin is opt-in' \
      'doctor: read-only dependency and configuration checks' \
      'Run login only after packages, chezmoi apply, and backup; takes effect next boot.'
    ;;
  packages)
    packages=()
    declare -A seen=()
    while read -r package; do
      [[ -z $package || $package == \#* ]] && continue
      [[ -z ${seen[$package]:-} ]] || continue
      seen[$package]=1
      # Force official repos: never silently draw replacements from third-party repos.
      selected=""
      for repo in core extra alarm; do
        if pacman -Si "$repo/$package" >/dev/null 2>&1; then
          selected="$repo/$package"; break
        fi
      done
      [[ -n $selected ]] || { echo "No official package for $package; aborting before installation." >&2; exit 1; }
      packages+=("$selected")
    done < <(cat "$root"/packages/*.txt)
    (( ${#packages[@]} > 0 )) || { echo 'Empty package manifest.' >&2; exit 1; }
    pkexec /usr/bin/pacman -S --needed "${packages[@]}"
    ;;
  tools)
    python3 "$root/install-tools.py" herdr mise voxtype obsidian strata vicinae yay
    bash "$root/install-ttfx.sh"
    "$HOME/.local/bin/mise" install node@26.8.1 pi@0.85.1 codex@0.153.4
    ;;
  model) exec bash "$root/install-dictation-model.sh" ;;
  editor) exec nvim --headless '+Lazy! restore' +qa ;;
  pi-packages)
    # Read pins from the same pure JSON modifier used by chezmoi; no duplicate list.
    mapfile -t pi_packages < <(printf '{}' | sh "$root/../dot_pi/agent/modify_private_settings.json" | jq -r '.packages[]')
    [[ ${#pi_packages[@]} == 5 ]] || { echo 'Unexpected Pi package manifest.' >&2; exit 1; }
    for package in "${pi_packages[@]}"; do
      "$HOME/.local/bin/mise" exec node@26.8.1 pi@0.85.1 -- pi install "$package" --no-approve
    done
    ;;
  bitwarden) exec bash "$root/install-bitwarden.sh" ;;
  vite-plus) exec bash "$root/install-vite-plus.sh" ;;
  greeter) shift; exec bash "$root/install-greeter.sh" "$@" ;;
  appearance)
    [[ -f /usr/share/icons/Adwaita/index.theme ]] || { echo 'Install adwaita-icon-theme first.' >&2; exit 1; }
    if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
      gsettings set org.gnome.desktop.interface icon-theme Adwaita
    else
      dbus-run-session -- gsettings set org.gnome.desktop.interface icon-theme Adwaita
    fi
    ;;
  system)
    if [[ ${2:-} == --apply ]]; then
      exec pkexec /usr/bin/python3 "$root/install-system.py" --apply
    fi
    exec python3 "$root/install-system.py"
    ;;
  services)
    # No Docker-group grant (equivalent to root) and no firewall changes.
    pkexec /usr/bin/systemctl enable NetworkManager systemd-resolved bluetooth power-profiles-daemon sshd tailscaled cups avahi-daemon keyd
    systemctl --user enable syncthing.service
    systemctl --user enable fcitx5.service
    systemctl --user enable bt-agent.service
    # Noctalia's community Tailscale plugin replaces the standalone tray app.
    systemctl --user disable --now tailscale-systray.service 2>/dev/null || true
    if [[ -x $HOME/.local/bin/voxtype ]]; then
      systemctl --user enable voxtype.service
    else
      echo 'Dictation binary missing: finish the platform-specific installation.' >&2
    fi
    ;;
  login)
    shift
    login_args=(--user "$(id -un)" "$@")
    if [[ " $* " == *' --apply '* ]]; then
      exec pkexec /usr/bin/python3 "$root/configure-login.py" "${login_args[@]}"
    fi
    exec python3 "$root/configure-login.py" "${login_args[@]}"
    ;;
  doctor) exec bash "$root/standalone-doctor.sh" ;;
  *) echo 'Unknown action; use --help.' >&2; exit 2 ;;
esac
