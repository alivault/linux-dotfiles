#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

alniac-install-terminal kitty
pacman -Q kitty >/dev/null
grep -q '^kitty\.desktop$' "$HOME/.config/xdg-terminals.list"
