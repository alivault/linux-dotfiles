#!/bin/bash

set -euo pipefail

plugin="$HOME/.config/omarchy/plugins/io.github.thisisgm.omapods"

if [[ -x "$HOME/.local/bin/librepods" && -x "$HOME/.local/bin/librepods-ctl" ]] &&
  systemctl --user is-enabled --quiet librepods.service; then
  exit 0
fi

if [[ ! -x "$plugin/setup" ]]; then
  echo "omarchy-pods setup script is missing: $plugin/setup" >&2
  exit 1
fi

"$plugin/setup"
