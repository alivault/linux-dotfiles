#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# ALNIAC's dictation (profile/dictation.py) runs ~/.local/bin/voxtype; the
# voxtype.service drop-in that hands it the daemon is linked by chezmoi.
version=1.1.1
case $(uname -m) in
aarch64)
  declare -A sha256=(
    [cpu]=f29bdbf6c3c2535ebe8be3abb6ded7d6c0ac9b16392ea3b5ba231e06a7b05687
    [osd]=0ea8b8c2c4c1b2947181efafd1d159684b06d97d90c6b5350e0fda384e645914
    [osd-gtk4]=4cdff10f6e41d538998c59c374ce971c651f14aab4ea4a437a0c612b825d80f9
  )
  ;;
*)
  bootstrap_log "Skipping voxtype: ALNIAC dictation is pinned for aarch64"
  exit 0
  ;;
esac

bin="$HOME/.local/bin"
if [[ -x $bin/voxtype ]] && "$bin/voxtype" --version 2>/dev/null | grep -qx "voxtype $version" &&
  [[ -x $bin/voxtype-osd && -x $bin/voxtype-osd-gtk4 ]]; then
  bootstrap_log "voxtype $version is already installed"
else
  directory=$(mktemp -d)
  trap 'rm -rf "$directory"' EXIT
  base="https://github.com/peteonrails/voxtype/releases/download/v$version"
  for part in cpu osd osd-gtk4; do
    download_verified "$base/voxtype-$version-linux-aarch64-$part" "$directory/$part" "${sha256[$part]}"
  done
  install -d "$bin"
  install -m 0755 "$directory/cpu" "$bin/voxtype"
  install -m 0755 "$directory/osd" "$bin/voxtype-osd"
  install -m 0755 "$directory/osd-gtk4" "$bin/voxtype-osd-gtk4"
fi

"$bin/voxtype" setup --download --model base.en --quiet --no-post-install
[[ -f $HOME/.config/systemd/user/voxtype.service ]] ||
  "$bin/voxtype" setup --quiet systemd
systemctl --user daemon-reload
systemctl --user enable voxtype.service
systemctl --user restart voxtype.service
bootstrap_log "voxtype $version is installed for ALNIAC dictation"
