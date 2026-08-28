#!/bin/bash

set -euo pipefail

plugin="$HOME/.config/omarchy/plugins/io.github.thisisgm.omapods"
daemon="$plugin/daemon"

if [[ -x "$HOME/.local/bin/librepods" && -x "$HOME/.local/bin/librepods-ctl" ]] &&
  systemctl --user is-enabled --quiet librepods.service; then
  exit 0
fi

if [[ ! -f "$daemon/CMakeLists.txt" ]]; then
  echo "omarchy-pods daemon source is missing: $daemon/CMakeLists.txt" >&2
  exit 1
fi

omarchy pkg add gcc cmake ninja qt6-connectivity qt6-tools qt6-declarative pkgconf libpulse

cmake \
  -S "$daemon" \
  -B "$daemon/build" \
  -G Ninja \
  -DBUILD_TESTING=OFF \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
cmake --build "$daemon/build"
cmake --install "$daemon/build" --prefix "$HOME/.local"

systemctl --user daemon-reload
systemctl --user enable librepods.service
# Restart instead of enable --now so an existing daemon uses the new binary.
systemctl --user restart librepods.service

echo "librepods is running."
echo "The bar icon stays hidden until AirPods are connected."
