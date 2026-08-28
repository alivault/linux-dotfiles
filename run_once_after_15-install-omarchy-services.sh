#!/bin/bash

set -euo pipefail

flatpak_has() {
  command -v flatpak >/dev/null 2>&1 && flatpak info "$1" >/dev/null 2>&1
}

ensure_flathub() {
  omarchy pkg add flatpak
  flatpak remote-add --user --if-not-exists \
    flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_bitwarden() {
  if pacman -Si bitwarden bitwarden-cli >/dev/null 2>&1; then
    omarchy pkg add bitwarden bitwarden-cli
    return
  fi

  # Omarchy's ARM repositories currently carry the CLI but not the desktop app.
  if pacman -Si bitwarden-cli >/dev/null 2>&1; then
    omarchy pkg add bitwarden-cli
  fi

  if ! flatpak_has com.bitwarden.desktop; then
    ensure_flathub
    flatpak install --user --noninteractive -y flathub com.bitwarden.desktop
  fi
}

install_obsidian() {
  if pacman -Q obsidian >/dev/null 2>&1 ||
    flatpak_has md.obsidian.Obsidian ||
    [[ -x "$HOME/.local/opt/obsidian/Obsidian.AppImage" ]]; then
    return
  fi

  if pacman -Si obsidian >/dev/null 2>&1; then
    omarchy pkg add obsidian
  else
    ensure_flathub
    flatpak install --user --noninteractive -y flathub md.obsidian.Obsidian
  fi
}

install_tailscale() {
  omarchy pkg add tailscale
  sudo systemctl enable --now tailscaled.service
  systemctl --user enable --now omarchy-tailscale-receive.service

  if tailscale status >/dev/null 2>&1; then
    sudo tailscale set --operator="$USER"
  else
    echo "Tailscale is installed but not authenticated."
    echo "After bootstrap, run: sudo tailscale up --accept-routes"
  fi
}

echo "Installing Bitwarden..."
install_bitwarden

echo "Installing Obsidian..."
install_obsidian

echo "Enabling Google account sign-in for Chromium..."
omarchy install chromium google account

echo "Installing Tailscale..."
install_tailscale
