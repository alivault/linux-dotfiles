#!/bin/bash

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo"

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

python3 - <<'PY'
import pathlib
import tomllib

for path in (pathlib.Path('.chezmoiexternal.toml'),):
    with path.open('rb') as file:
        tomllib.load(file)
PY

if command -v lua >/dev/null 2>&1; then
  while IFS= read -r lua_file; do
    LUA_FILE="$lua_file" lua -e 'assert(loadfile(os.getenv("LUA_FILE")))'
  done < <(find dot_config -type f -name '*.lua' | sort)
fi

chezmoi execute-template <.chezmoiignore >/dev/null
chezmoi execute-template <.chezmoi.toml.tmpl >/dev/null
rendered_monitor=$(mktemp)
chezmoi execute-template <dot_config/hypr/monitors.lua.tmpl >"$rendered_monitor"
if command -v lua >/dev/null 2>&1; then
  LUA_FILE="$rendered_monitor" lua -e 'assert(loadfile(os.getenv("LUA_FILE")))'
fi
rm -f "$rendered_monitor"

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

rendered_shell="$temp_root/home/.config/omarchy/shell.json"
jq empty "$rendered_shell"

while IFS= read -r plugin_id; do
  if ! find "$temp_root/home/.config/omarchy/plugins" \
    -mindepth 2 -maxdepth 2 -name manifest.json -print0 |
    xargs -0 -r jq -e --arg id "$plugin_id" \
      'select(.id == $id)' >/dev/null; then
    printf 'missing custom bar plugin in isolated apply: %s\n' \
      "$plugin_id" >&2
    exit 1
  fi
done < <(jq -r '.bar.layout[][]?.id | select(startswith("omarchy.") | not)' \
  "$rendered_shell" | sort -u)

[[ ! -e $temp_root/home/bootstrap ]]
[[ ! -e $temp_root/home/.github ]]

printf 'Source validation passed.\n'
