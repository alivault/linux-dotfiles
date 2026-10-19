#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# ALNIAC ships default user configs in config/ (terminals, btop, Chromium flags,
# and autostart overrides that hide the system Fcitx5 and print applet) but no
# command installs them. Install every one that is missing; never replace a
# file that exists. alniac-refresh-config also writes $HOME out in the
# Chromium flags.
export ALNIAC_PATH="$HOME/.local/share/alniac/current"
defaults="$ALNIAC_PATH/config"
[[ -d $defaults ]] || bootstrap_die "missing ALNIAC config defaults: $defaults"

installed=0
while IFS= read -r -d '' file; do
  relative=${file#"$defaults"/}
  [[ -e $HOME/.config/$relative ]] && continue
  alniac-refresh-config "$relative" >/dev/null
  bootstrap_log "Installed ALNIAC default: ~/.config/$relative"
  installed=$((installed + 1))
done < <(find "$defaults" -type f -print0 | sort -z)

bootstrap_log "ALNIAC defaults: $installed installed, existing files kept"
