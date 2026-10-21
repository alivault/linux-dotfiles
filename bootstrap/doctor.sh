#!/bin/bash

set -uo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

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

printf '%s\n' 'ALNIAC bootstrap doctor' '======================='

for command_name in chezmoi git jq; do
  has_command "$command_name"
done

release="$HOME/.local/share/alniac/current"
if [[ -x $release/bin/alniac-version ]]; then
  pass "ALNIAC release is staged: $("$release/bin/alniac-version")"
else
  fail "no staged ALNIAC release: $release"
fi

if [[ -d $HOME/code/alniac/.git ]]; then
  pass 'ALNIAC checkout exists: ~/code/alniac'
else
  fail 'ALNIAC checkout is missing: ~/code/alniac'
fi

# The same preflight the login runs: release hashes, tuned Niri, config validation.
if [[ -r $release/session/check.py ]] &&
  env -u ALNIAC_PATH /usr/bin/python3 "$release/session/check.py" >/dev/null 2>&1; then
  pass 'ALNIAC login preflight passes'
else
  fail 'ALNIAC login preflight fails; run: python3 ~/.local/share/alniac/current/session/check.py'
fi

if [[ -r $HOME/.config/alniac/shell.json ]] && jq empty "$HOME/.config/alniac/shell.json" >/dev/null 2>&1; then
  pass 'ALNIAC shell configuration is valid JSON'
else
  fail 'invalid or missing ALNIAC shell configuration: ~/.config/alniac/shell.json'
fi

for unit in alniac alniac-audio alniac-bt-agent alniac-crash-watch alniac-fcitx5 alniac-tailscale-receive; do
  if [[ -f $HOME/.config/systemd/user/$unit.service ]]; then
    pass "ALNIAC unit is linked: $unit.service"
  else
    fail "ALNIAC unit link is missing or broken: $unit.service"
  fi
done

if [[ -f $HOME/.config/autostart/org.fcitx.Fcitx5.desktop ]]; then
  pass 'The system Fcitx5 autostart is hidden (ALNIAC runs its own)'
else
  fail 'The system Fcitx5 autostart is not hidden; run: bootstrap/provision.sh alniac-configs'
fi

fcitx_count=$(pgrep -u "$USER" -x fcitx5 | wc -l)
if ((fcitx_count <= 1)); then
  pass "One Fcitx5 at most is running ($fcitx_count)"
else
  fail "$fcitx_count Fcitx5 processes are running; stop: systemctl --user stop app-org.fcitx.Fcitx5@autostart.service"
fi

if systemctl --user is-active --quiet alniac.service; then
  pass 'ALNIAC session is running'
else
  warn 'ALNIAC session is not running (not logged in graphically?)'
fi

if command -v chezmoi >/dev/null 2>&1; then
  if chezmoi --source "$repo" verify --exclude scripts >/dev/null 2>&1; then
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

if git config --file "$HOME/.gitconfig" --get user.email >/dev/null 2>&1; then
  pass 'Git has an identity (~/.gitconfig)'
else
  fail 'Git has no identity: bash bootstrap/provision.sh 04-git'
fi

if gh auth status --hostname github.com >/dev/null 2>&1 &&
  git config --file "$HOME/.gitconfig" --get-all credential.https://github.com.helper 2>/dev/null |
  grep -q 'gh auth git-credential'; then
  pass 'Git uses the GitHub CLI login'
else
  warn 'Git has no GitHub login: gh auth login --web, then bash bootstrap/provision.sh 04-git'
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

if command -v rbw >/dev/null 2>&1; then
  pass 'rbw is installed (the Secrets app)'
else
  warn 'rbw is not installed: bash bootstrap/provision.sh 15-bitwarden'
fi

if pacman -Q obsidian >/dev/null 2>&1 ||
  [[ -x $HOME/.local/opt/obsidian/Obsidian.AppImage ]] ||
  { command -v flatpak >/dev/null 2>&1 &&
    flatpak info md.obsidian.Obsidian >/dev/null 2>&1; }; then
  pass 'Obsidian is installed'
else
  fail 'Obsidian is not installed'
fi

if [[ -x $HOME/.local/bin/voxtype && -x $HOME/.local/bin/voxtype-osd-gtk4 ]]; then
  pass "$("$HOME/.local/bin/voxtype" --version 2>/dev/null) and its OSD are installed"
else
  fail 'voxtype or its OSD is not installed in ~/.local/bin'
fi

if systemctl --user is-active --quiet voxtype.service; then
  pass 'voxtype service is active'
else
  fail 'voxtype service is not active'
fi

if systemctl --user is-active --quiet airpods.service; then
  pass 'AirPods daemon is active'
else
  warn 'AirPods daemon is not active'
fi

missing_apps=()
for installer in "$HOME"/code/alniac/apps/*/install.sh; do
  [[ -f $installer ]] || continue
  app=$(basename "$(dirname "$installer")")
  [[ -e $HOME/.local/bin/$app ]] || missing_apps+=("$app")
done
if ((${#missing_apps[@]} == 0)); then
  pass 'ALNIAC apps are installed'
else
  fail "ALNIAC apps are not installed: ${missing_apps[*]}"
fi

# Work that exists only on this disk is lost with it (2026-10-19): every
# repository in ~/code needs a remote, and its commits pushed.
for repo in "$HOME"/code/*/; do
  repo=${repo%/}
  [[ -e $repo/.git ]] || continue
  name=${repo#"$HOME"/}
  if [[ -z $(git -C "$repo" remote 2>/dev/null) ]]; then
    fail "$name has no remote: its history exists only on this disk"
    continue
  fi
  unpushed=$(git -C "$repo" log --branches --not --remotes --oneline 2>/dev/null | wc -l)
  if ((unpushed > 0)); then
    warn "$name has $unpushed commit(s) that are not pushed"
  fi
  if [[ -n $(git -C "$repo" status --porcelain 2>/dev/null) ]]; then
    warn "$name has uncommitted changes"
  fi
  if ((unpushed == 0)) && [[ -z $(git -C "$repo" status --porcelain 2>/dev/null) ]]; then
    pass "$name is pushed"
  fi
done

printf '\nSummary: %d passed, %d warning(s), %d failed.\n' \
  "$passes" "$warnings" "$failures"

((failures == 0))
