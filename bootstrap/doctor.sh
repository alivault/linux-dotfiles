#!/bin/bash

set -uo pipefail

passes=0
warnings=0
failures=0

pass() {
  printf 'PASS  %s\n' "$*"
  ((passes += 1))
}

warn() {
  printf 'WARN  %s\n' "$*"
  ((warnings += 1))
}

fail() {
  printf 'FAIL  %s\n' "$*"
  ((failures += 1))
}

has_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is available"
  else
    fail "$1 is missing"
  fi
}

printf '%s\n' 'Omarchy bootstrap doctor' '========================'

for command_name in chezmoi git jq omarchy; do
  has_command "$command_name"
done

if command -v omarchy >/dev/null 2>&1; then
  omarchy_version=$(omarchy version 2>/dev/null || true)
  case $omarchy_version in
  4.*) pass "Omarchy version is supported: $omarchy_version" ;;
  '') fail 'could not determine the Omarchy version' ;;
  *) fail "unsupported Omarchy version: $omarchy_version" ;;
  esac
fi

shell_config="$HOME/.config/omarchy/shell.json"
if command -v jq >/dev/null 2>&1 && jq empty "$shell_config" >/dev/null 2>&1; then
  pass 'Omarchy shell configuration is valid JSON'
else
  fail "invalid or missing shell configuration: $shell_config"
fi

if command -v omarchy >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 &&
  [[ -r $shell_config ]]; then
  plugin_json=$(omarchy plugin list --json 2>/dev/null || true)
  if jq -e 'type == "array"' >/dev/null 2>&1 <<<"$plugin_json"; then
    plugin_failure=0
    while IFS= read -r plugin_id; do
      if jq -e --arg id "$plugin_id" \
        'any(.[]; .id == $id and .enabled == true)' \
        >/dev/null <<<"$plugin_json"; then
        pass "bar plugin is installed and enabled: $plugin_id"
      else
        fail "bar plugin is missing or disabled: $plugin_id"
        plugin_failure=1
      fi
    done < <(jq -r '.bar.layout[][]?.id' "$shell_config" | sort -u)

    if ((plugin_failure == 0)); then
      pass 'all configured bar plugins are available'
    fi
  else
    fail 'could not read the Omarchy plugin registry'
  fi

  for manifest in "$HOME/.config/omarchy/plugins"/*/manifest.json; do
    [[ -f $manifest ]] || continue
    plugin_dir=${manifest%/manifest.json}
    plugin_id=$(jq -r '.id // empty' "$manifest")
    if omarchy plugin validate "$plugin_dir" >/dev/null 2>&1; then
      pass "plugin manifest is valid: $plugin_id"
    else
      fail "plugin validation failed: $plugin_dir"
    fi
  done
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  if OMARCHY_SHELL_IPC_TIMEOUT=3s omarchy-shell shell ping >/dev/null 2>&1; then
    pass 'Omarchy shell IPC is healthy'
  else
    warn 'Omarchy shell is not running or did not answer IPC'
  fi
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hypr_errors=$(hyprctl configerrors 2>/dev/null || true)
  if [[ -z $hypr_errors ]]; then
    pass 'Hyprland reports no configuration errors'
  else
    fail "Hyprland configuration errors: $hypr_errors"
  fi
else
  warn 'Hyprland is not active; runtime configuration check skipped'
fi

if command -v chezmoi >/dev/null 2>&1; then
  if chezmoi verify --exclude scripts >/dev/null 2>&1; then
    pass 'Chezmoi-managed configuration matches its source state'
  else
    fail 'Chezmoi-managed configuration differs from its source state'
  fi
fi

if pacman -Q kitty >/dev/null 2>&1; then
  pass 'Kitty is installed'
else
  fail 'Kitty is not installed'
fi

if [[ -x $HOME/.vite-plus/bin/vp && -r $HOME/.vite-plus/env ]]; then
  pass "$($HOME/.vite-plus/bin/vp --version 2>/dev/null | head -n 1) is installed"
else
  fail 'Vite+ is not installed completely'
fi

if systemctl is-active --quiet keyd; then
  pass 'keyd is active'
else
  fail 'keyd is not active'
fi

if systemctl --user is-active --quiet syncthing.service; then
  pass 'Syncthing user service is active'
else
  fail 'Syncthing user service is not active'
fi

if systemctl is-active --quiet tailscaled.service; then
  pass 'Tailscale service is active'
else
  fail 'Tailscale service is not active'
fi

if tailscale status >/dev/null 2>&1; then
  pass 'Tailscale is authenticated'
else
  warn 'Tailscale still needs authentication'
fi

if pacman -Q bitwarden >/dev/null 2>&1 ||
  { command -v flatpak >/dev/null 2>&1 &&
    flatpak info com.bitwarden.desktop >/dev/null 2>&1; }; then
  pass 'Bitwarden desktop is installed'
else
  fail 'Bitwarden desktop is not installed'
fi

if pacman -Q obsidian >/dev/null 2>&1 ||
  [[ -x $HOME/.local/opt/obsidian/Obsidian.AppImage ]] ||
  { command -v flatpak >/dev/null 2>&1 &&
    flatpak info md.obsidian.Obsidian >/dev/null 2>&1; }; then
  pass 'Obsidian is installed'
else
  fail 'Obsidian is not installed'
fi

if grep -aq 'apple,arm-platform' \
  /sys/firmware/devicetree/base/compatible 2>/dev/null; then
  if [[ -x $HOME/.local/bin/gpu-screen-recorder &&
    -x $HOME/.local/libexec/omarchy-asahi-screenrecord.py ]]; then
    pass 'Asahi screen-recording compatibility files are installed'
  else
    fail 'Asahi screen-recording compatibility files are missing'
  fi
fi

if command -v omarchy >/dev/null 2>&1; then
  current_theme=$(omarchy theme current 2>/dev/null || true)
  if [[ $current_theme == Ashen ]]; then
    pass 'Ashen theme is active'
  else
    warn "Ashen theme is not active (current: ${current_theme:-unknown})"
  fi
fi

printf '\nSummary: %d passed, %d warning(s), %d failed.\n' \
  "$passes" "$warnings" "$failures"

((failures == 0))
