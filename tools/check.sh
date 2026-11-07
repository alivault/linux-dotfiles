#!/bin/bash
# The repository's checks (CI: .github/workflows/validate.yml). Nix is
# optional here: the Oasis flake's system build is the full test of nix/.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo"

python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/check-public.py

scripts=(tools/check.sh bin/dotfiles-seed home/.bashrc home/.bash_profile
  home/.claude/hooks/herdr-agent-state.sh home/.config/herdr/move-pane.sh
  home/.local/bin/obsidian home/.local/share/agent-guard/bin/rm)
for script in "${scripts[@]}"; do
  bash -n "$script"
done
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck --severity=warning --shell=bash --exclude=SC1090,SC1091 "${scripts[@]}"
fi

while IFS= read -r json_file; do
  jq empty "$json_file"
done < <(find home seed -type f -name '*.json' | sort)
jq -n -f seed/pi-settings.jq >/dev/null

if command -v lua >/dev/null 2>&1; then
  while IFS= read -r lua_file; do
    LUA_FILE="$lua_file" lua -e 'assert(loadfile(os.getenv("LUA_FILE")))'
  done < <(find home -type f -name '*.lua' | sort)
fi

# The seed script copies into an empty home, and a second run copies nothing.
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
HOME="$scratch" bin/dotfiles-seed >/dev/null
[[ -s $scratch/.config/oasis/shell.json && -s $scratch/.pi/agent/settings.json ]]
HOME="$scratch" bin/dotfiles-seed | grep -q '^copied 0 file'

if command -v nix >/dev/null 2>&1; then
  nix --extra-experimental-features 'nix-command flakes' flake show "path:$repo" >/dev/null
fi

printf 'Checks passed.\n'
