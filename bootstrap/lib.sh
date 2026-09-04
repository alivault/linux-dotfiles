#!/bin/bash

set -euo pipefail

bootstrap_log() {
  printf '==> %s\n' "$*"
}

bootstrap_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 ||
      bootstrap_die "required command is missing: $command_name"
  done
}

package_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

package_available() {
  pacman -Si "$@" >/dev/null 2>&1
}

ensure_package() {
  omarchy pkg add "$@"
}

flatpak_has() {
  command -v flatpak >/dev/null 2>&1 &&
    flatpak info "$1" >/dev/null 2>&1
}

ensure_flathub() {
  ensure_package flatpak
  flatpak remote-add --user --if-not-exists \
    flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

is_asahi() {
  grep -aq 'apple,arm-platform' \
    /sys/firmware/devicetree/base/compatible 2>/dev/null
}

download_verified() {
  local url=$1
  local destination=$2
  local expected_sha256=$3

  curl -fL --retry 3 --retry-delay 1 "$url" -o "$destination"
  printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum --check --status ||
    bootstrap_die "checksum mismatch for $url"
}
