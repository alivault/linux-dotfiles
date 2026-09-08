#!/bin/bash
# Niri ttfx screensaver. Only manages its own child; see THIRD_PARTY_NOTICES.md.
set -u
effect_pid=""
cleanup() {
  trap - EXIT INT TERM HUP QUIT
  if [[ -n "$effect_pid" ]]; then
    kill "$effect_pid" 2>/dev/null || true
    wait "$effect_pid" 2>/dev/null || true
  fi
  printf '\033[?25h'
}
trap cleanup EXIT
trap 'exit 0' INT TERM HUP QUIT
printf '\033]11;rgb:00/00/00\007\033[?25l'

# Let Kitty receive the compositor's fullscreen size before sizing the canvas.
sleep 0.2
deadline=$((SECONDS + 2))
while (( SECONDS < deadline )) && [[ $(stty size 2>/dev/null) == '24 80' ]]; do
  sleep 0.02
done

while true; do
  "$HOME/.local/bin/ttfx" -i "$HOME/.local/share/desktop-assets/screensaver.txt" \
    --frame-rate 120 --canvas-width 0 --canvas-height 0 --reuse-canvas \
    --anchor-canvas c --anchor-text c --random-effect --no-eol --no-restore-cursor &
  effect_pid=$!
  while kill -0 "$effect_pid" 2>/dev/null; do
    # Manual preview can also be dismissed with a key. Idle resume handles mouse input.
    if IFS= read -rsn1 -t 0.2; then exit 0; fi
  done
  wait "$effect_pid" || exit 1
  effect_pid=""
done
