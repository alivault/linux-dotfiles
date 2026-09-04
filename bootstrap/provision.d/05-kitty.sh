#!/bin/bash

set -euo pipefail

omarchy install terminal kitty
pacman -Q kitty >/dev/null
grep -q '^kitty\.desktop$' "$HOME/.config/xdg-terminals.list"
