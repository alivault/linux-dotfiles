#!/bin/bash
set -euo pipefail
# Upstream project can be used independently of the Omarchy desktop/packages.
# Requires official Arch rust + base-devel; Cargo.lock pins Rust dependencies.
revision=7203e354498462064b7c0a89375051f65cf2ce99
command -v cargo >/dev/null
cargo install --git https://github.com/omacom-io/ttfx.git \
  --rev "$revision" --locked --root "$HOME/.local" --jobs 4 ttfx
