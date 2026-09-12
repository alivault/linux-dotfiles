#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

if package_available bitwarden bitwarden-cli; then
  ensure_package bitwarden bitwarden-cli
elif package_available bitwarden-cli; then
  ensure_package bitwarden-cli
fi

if ! package_installed bitwarden && ! flatpak_has com.bitwarden.desktop; then
  ensure_flathub
  flatpak install --user --noninteractive -y flathub com.bitwarden.desktop
fi

package_installed bitwarden || flatpak_has com.bitwarden.desktop ||
  bootstrap_die "Bitwarden desktop was not installed"
