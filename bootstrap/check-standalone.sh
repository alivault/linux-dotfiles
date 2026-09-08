#!/bin/bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for script in "$repo"/bootstrap/*.sh; do bash -n "$script"; done
sh -n "$repo/bootstrap/start.sh"
if command -v shellcheck >/dev/null; then shellcheck --severity=warning "$repo"/bootstrap/*.sh; fi
if command -v luac >/dev/null; then
  shopt -s globstar
  for source in "$repo"/dot_config/nvim/**/*.lua; do luac -p "$source"; done
fi
python3 -m unittest discover -s "$repo/bootstrap" -p 'test_*.py'
python3 "$repo/bootstrap/check-public.py"
bash -n "$repo/bootstrap/asahi-files/usr/local/libexec/mac-kbd-backlight-sleep"
bash -n "$repo/bootstrap/check-qemu-static.sh" "$repo/bootstrap/build-qemu-static.sh" "$repo/bootstrap/qemu-static/PKGBUILD"
bash -n "$repo/bootstrap/greeter/PKGBUILD" "$repo/bootstrap/greeter/noctalia-greeter.install"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/cache/tmp"
printf 'tempDir = "%s"\n' "$tmp/cache/tmp" > "$tmp/chezmoi.toml"
HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" XDG_CACHE_HOME="$tmp/cache" \
  chezmoi --source "$repo" --destination "$tmp/home" --config "$tmp/chezmoi.toml" \
  --cache "$tmp/cache" apply --force --exclude scripts
[[ ! -e $tmp/home/.config/omarchy ]]
[[ ! -e $tmp/home/.config/hypr ]]
[[ ! -e $tmp/home/bootstrap ]]
[[ ! -e $tmp/home/.local/share/sddm ]]
[[ ! -e $tmp/home/.local/share/applications/Docker.desktop ]]
[[ -s $tmp/home/.local/share/desktop-assets/screensaver.txt ]]
[[ -s $tmp/home/.local/share/desktop-assets/wallpaper.png ]]
python3 - "$tmp/home" <<'PY'
import json, pathlib, sys, tomllib
home = pathlib.Path(sys.argv[1])
for path in (home / '.config/noctalia').glob('*.toml'):
    tomllib.loads(path.read_text())
json.loads((home / '.config/vicinae/settings.json').read_text())
json.loads((home / '.config/nvim/lazy-lock.json').read_text())
assert 'require("config.lazy")' in (home / '.config/nvim/init.lua').read_text()
assert not (home / '.config/nvim/lua/plugins/theme.lua').is_symlink()
assert not (home / '.pi/agent/extensions/omarchy-system-theme.ts').exists()
for directory in ['.config/nvim', '.config/fastfetch', '.config/btop', '.config/tmux', '.pi/agent/extensions']:
    for path in (home / directory).rglob('*'):
        if path.is_file():
            assert 'omarchy' not in path.read_text().lower(), path
for name in ['.bashrc', '.config/niri/config.kdl', '.config/kitty/kitty.conf', '.config/niri/screensaver.sh']:
    text = (home / name).read_text()
    assert '/home/ali/' not in text, name
    assert '/usr/share/omarchy' not in text, name
    assert '.local/state/omarchy' not in text, name
PY
if command -v niri >/dev/null; then niri validate --config "$tmp/home/.config/niri/config.kdl"; fi
if command -v noctalia >/dev/null; then
  noctalia config validate "$tmp/home/.config/noctalia"
  noctalia plugins lint "$tmp/home/.local/share/noctalia-local-plugins/iweather"
fi
bash -n "$tmp/home/.bashrc" "$tmp/home/.config/niri/screensaver.sh" "$tmp/home/.local/bin/pi" "$tmp/home/.local/bin/codex"
echo 'Standalone isolated render and validation passed. No live files were applied.'
