#!/bin/bash
# Build only. Installing/upgrading the resulting packages is a separate review.
set -euo pipefail
[[ $EUID != 0 ]] || { echo 'Build as your normal user, not root.' >&2; exit 1; }
[[ $(uname -m) == aarch64 ]] || { echo 'This Debian ARM64 repack is only for aarch64.' >&2; exit 1; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
build=$(mktemp -d "$HOME/.cache/standalone-qemu.XXXXXX")
cp "$root/qemu-static/PKGBUILD" "$build/PKGBUILD"
cd "$build"
makepkg --noconfirm
echo "Built packages in $build (not installed)."
