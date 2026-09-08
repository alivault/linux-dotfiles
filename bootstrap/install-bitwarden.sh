#!/bin/bash
set -euo pipefail
command -v flatpak >/dev/null
# User scope only. No credentials or vault contents are provisioned.
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive --assumeyes flathub com.bitwarden.desktop
