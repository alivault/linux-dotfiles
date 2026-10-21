#!/bin/bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# mise may come from its own installer in ~/.local/bin. Without it: the package
# where the repositories have one, else the pinned release (Arch Linux ARM has
# no mise package), checked against its SHA-256. `mise self-update` updates it.
install_mise_release() {
  local version=2026.10.15 arch sha directory
  case $(uname -m) in
  aarch64) arch=arm64 sha=ae36e72ea72d337ab7b367edb0f7016fa1502aa0e36ccb705acad7902c60677b ;;
  x86_64) arch=x64 sha=1c2d85dc42bef51e0bb20780093c746d6e12dfd15ca461f3979bd52cc214bc19 ;;
  *) bootstrap_die "no pinned mise release for $(uname -m)" ;;
  esac
  directory=$(mktemp -d)
  trap 'rm -rf "$directory"' RETURN
  download_verified "https://github.com/jdx/mise/releases/download/v$version/mise-v$version-linux-$arch.tar.gz" \
    "$directory/mise.tar.gz" "$sha"
  tar -xzf "$directory/mise.tar.gz" -C "$directory"
  install -Dm755 "$directory/mise/bin/mise" "$HOME/.local/bin/mise"
  bootstrap_log "Installed mise $version in ~/.local/bin"
}

export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  if package_available mise; then
    ensure_package mise
  else
    install_mise_release
  fi
fi
config="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
[[ -f $config ]] || bootstrap_die 'Apply the chezmoi configuration before provisioning mise tools.'
mise trust "$config"
mise --cd "$HOME" install
