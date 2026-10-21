#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# rbw: the Bitwarden client the Secrets app (ALNIAC apps/secrets) uses;
# a small Rust binary without Node.
package_available rbw && ensure_package rbw

# bitwarden-cli depends on nodejs-lts-jod, which conflicts with the nodejs
# package (ALNIAC's base packages: its release tests run node). Keep nodejs and
# skip the CLI then; rbw does the CLI's work.
nodejs_package_installed() {
  [[ $(pacman -Qq nodejs 2>/dev/null) == nodejs ]]
}

if nodejs_package_installed; then
  bootstrap_log 'Skipping bitwarden-cli: it would replace the nodejs package'
  package_available bitwarden && ensure_package bitwarden
elif package_available bitwarden bitwarden-cli; then
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
