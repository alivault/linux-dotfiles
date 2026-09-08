#!/bin/bash
set -uo pipefail
failed=0
for cmd in niri noctalia kitty chromium nvim tmux tailscale syncthing sshd \
  mise node pi codex herdr vicinae strata voxtype ttfx; do
  if command -v "$cmd" >/dev/null; then printf 'OK %s\n' "$cmd";
  else printf 'MISSING %s\n' "$cmd"; failed=1; fi
done
niri validate || failed=1
noctalia config validate || failed=1
[[ -r $HOME/.local/share/desktop-assets/screensaver.txt ]] || { echo 'MISSING screensaver asset'; failed=1; }
[[ -r $HOME/.local/share/desktop-assets/wallpaper.jpg || -r $HOME/.local/share/desktop-assets/wallpaper.png ]] || { echo 'MISSING wallpaper'; failed=1; }
if grep -Eq '^[^#]*(source|include).*omarchy' "$HOME/.bashrc" "$HOME/.config/kitty/kitty.conf"; then
  echo 'BLOCKER: active shell/terminal still depends on Omarchy'; failed=1
fi
systemctl is-enabled --quiet greetd.service 2>/dev/null || { echo 'MISSING enabled greetd login'; failed=1; }
[[ -r $HOME/.local/share/voxtype/models/ggml-base.en.bin ]] || { echo 'MISSING dictation model'; failed=1; }
for tool in herdr mise voxtype strata ttfx; do
  if [[ -x $HOME/.local/bin/$tool ]]; then
    if ldd "$HOME/.local/bin/$tool" 2>/dev/null | grep 'not found'; then
      echo "BLOCKER: missing runtime libraries for $tool"; failed=1
    fi
  fi
done
echo 'Also test: login/logout, lock/unlock, suspend, Wi-Fi, audio, screen sharing, printing and dictation.'
exit "$failed"
