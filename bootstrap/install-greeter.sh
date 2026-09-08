#!/bin/bash
# Build as user; explicit --apply installs the resulting reviewed local package.
set -euo pipefail
case ${1:-} in ''|--apply) ;; *) echo 'Usage: install-greeter.sh [--apply]' >&2; exit 2 ;; esac
[[ $EUID != 0 ]] || { echo 'Do not build as root.' >&2; exit 1; }
case $(uname -m) in aarch64|x86_64) ;; *) exit 1 ;; esac
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if pacman -Q noctalia-greeter 2>/dev/null | grep -Fxq 'noctalia-greeter 1.3.1-2'; then
  echo 'Pinned greeter already installed.'; exit 0
fi
mkdir -p "$HOME/.cache"
build=$(mktemp -d "$HOME/.cache/standalone-greeter.XXXXXX")
cp "$root/greeter/PKGBUILD" "$root/greeter/noctalia-greeter.install" "$build/"
cd "$build"
# Dependencies come from the official package manifest; never auto-install AUR dependencies.
makepkg --noconfirm
mapfile -t packages < <(makepkg --packagelist)
if [[ ${1:-} == --apply ]]; then
  pkexec /usr/bin/pacman -U --needed "${packages[@]}"
else
  printf 'Built, not installed: %s\n' "${packages[@]}"
fi
