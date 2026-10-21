#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# The identity and the GitHub login live in ~/.gitconfig, which chezmoi does not
# manage: `gh auth setup-git` writes its credential helper there. The shared
# settings are in ~/.config/git/config (chezmoi).
ensure_package github-cli

gitconfig="$HOME/.gitconfig"
git config --file "$gitconfig" --get user.name >/dev/null ||
  git config --file "$gitconfig" user.name 'Ali Abbas'
git config --file "$gitconfig" --get user.email >/dev/null ||
  git config --file "$gitconfig" user.email '48610822+alivault@users.noreply.github.com'

if gh auth status --hostname github.com >/dev/null 2>&1; then
  gh auth setup-git --hostname github.com
  bootstrap_log "Git uses the GitHub CLI login for github.com"
else
  bootstrap_log "Not logged in to GitHub: run gh auth login --web, then bash bootstrap/provision.sh 04-git"
fi
