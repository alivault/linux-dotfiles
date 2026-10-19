#!/bin/bash

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo"

python3 -m unittest discover -s bootstrap -p 'test_*.py'
python3 bootstrap/check-public.py

for script in bootstrap/*.sh bootstrap/provision.d/*.sh run_*.sh run_*.sh.tmpl; do
  [[ -f $script ]] || continue
  bash -n "$script"
done

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck --severity=warning \
    bootstrap/*.sh bootstrap/provision.d/*.sh run_*.sh.tmpl
fi

while IFS= read -r json_file; do
  if [[ $(head -c 2 "$json_file") == '#!' ]]; then
    continue
  fi
  jq empty "$json_file"
done < <(find . -type f -name '*.json' -not -path './.git/*' | sort)

if command -v lua >/dev/null 2>&1; then
  while IFS= read -r lua_file; do
    LUA_FILE="$lua_file" lua -e 'assert(loadfile(os.getenv("LUA_FILE")))'
  done < <(find dot_config -type f -name '*.lua' | sort)
fi

chezmoi execute-template <.chezmoiignore >/dev/null
chezmoi execute-template <.chezmoi.toml.tmpl >/dev/null

temp_root=$(mktemp -d)
trap 'rm -rf "$temp_root"' EXIT
mkdir -p \
  "$temp_root/home" \
  "$temp_root/config/chezmoi" \
  "$temp_root/cache/tmp"
printf 'tempDir = "%s"\n' "$temp_root/cache/tmp" \
  >"$temp_root/config/chezmoi/chezmoi.toml"

HOME="$temp_root/home" \
XDG_CONFIG_HOME="$temp_root/config" \
XDG_CACHE_HOME="$temp_root/cache" \
  chezmoi \
  --source "$repo" \
  --destination "$temp_root/home" \
  --config "$temp_root/config/chezmoi/chezmoi.toml" \
  --cache "$temp_root/cache/chezmoi" \
  apply --force --exclude scripts

# ALNIAC's user profile renders and parses.
profile="$temp_root/home/.config/alniac"
jq empty "$profile/shell.json" "$profile/dock.json"
[[ -s $profile/config.kdl && -s $profile/bindings.kdl ]]

# Session unit links point into the staged release, as the login expects.
units="$temp_root/home/.config/systemd/user"
release="$temp_root/home/.local/share/alniac/current/session/systemd"
for unit in alniac alniac-audio alniac-bt-agent alniac-crash-watch alniac-fcitx5 alniac-tailscale-receive; do
  [[ $(readlink "$units/$unit.service") == "$release/$unit.service" ]] || {
    printf 'unexpected ALNIAC unit link: %s\n' "$unit.service" >&2
    exit 1
  }
done
for unit in alniac-bt-agent alniac-crash-watch alniac-fcitx5 alniac-tailscale-receive; do
  [[ $(readlink "$units/graphical-session.target.wants/$unit.service") == "$units/$unit.service" ]] || {
    printf 'unexpected graphical-session want: %s\n' "$unit.service" >&2
    exit 1
  }
done

[[ ! -e $temp_root/home/bootstrap ]]
[[ ! -e $temp_root/home/.github ]]

printf 'Source validation passed.\n'
