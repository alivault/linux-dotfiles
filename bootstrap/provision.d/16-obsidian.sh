#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

if package_installed obsidian || flatpak_has md.obsidian.Obsidian ||
  [[ -x $HOME/.local/opt/obsidian/Obsidian.AppImage ]]; then
  exit 0
fi

if package_available obsidian; then
  ensure_package obsidian
else
  ensure_flathub
  flatpak install --user --noninteractive -y flathub md.obsidian.Obsidian
fi

package_installed obsidian || flatpak_has md.obsidian.Obsidian ||
  [[ -x $HOME/.local/opt/obsidian/Obsidian.AppImage ]] ||
  bootstrap_die "Obsidian was not installed"
