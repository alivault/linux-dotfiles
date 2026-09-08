#!/bin/sh
# Hosted entry point. The Worker injects the reviewed, immutable DOTFILES_REF.
set -eu
die() { printf '%s\n' "$*" >&2; exit 1; }
[ "$#" -le 1 ] || die 'Usage: bootstrap [--plan|--apply]'
case ${1:-} in ''|--plan|--apply) ;; *) die 'Usage: bootstrap [--plan|--apply]' ;; esac
[ "$(id -u)" != 0 ] || die 'Run as your normal desktop user, not root.'
case ${DOTFILES_REF:-} in ''|*[!0-9a-f]*) die 'A reviewed DOTFILES_REF commit is required.' ;; esac
[ "${#DOTFILES_REF}" = 40 ] || die 'DOTFILES_REF must be a full commit hash.'
for command_name in bash git curl install sha256sum mktemp pacman; do
  command -v "$command_name" >/dev/null 2>&1 || die "Install prerequisite: $command_name"
done
. /etc/os-release
case ${ID:-} in arch|archarm) ;; *) die 'This profile requires an existing, bootable Arch or Arch Linux ARM installation.' ;; esac
case $(uname -m) in aarch64|x86_64) ;; *) die 'Supported architectures: aarch64, x86_64.' ;; esac

source_dir="$HOME/.local/share/chezmoi"
repository=https://github.com/alivault/linux-dotfiles.git
if [ -d "$source_dir/.git" ]; then
  [ -z "$(git -C "$source_dir" status --porcelain --untracked-files=all)" ] ||
    die "Dirty checkout: $source_dir. Back it up and review your changes first."
  case $(git -C "$source_dir" config --get remote.origin.url) in
    https://github.com/alivault/linux-dotfiles.git|git@github.com:alivault/linux-dotfiles.git) ;;
    *) die 'Unexpected source remote; refusing to replace it.' ;;
  esac
  case $(git -C "$source_dir" branch --show-current) in
    main|'') ;; *) die 'Development branch detected; use bootstrap/setup.sh from that checkout.' ;;
  esac
elif [ -e "$source_dir" ]; then
  die "Existing non-repository source directory: $source_dir"
else
  mkdir -p "$(dirname "$source_dir")"
  git clone --no-checkout --depth 1 "$repository" "$source_dir"
fi
git -C "$source_dir" fetch --depth 1 origin "$DOTFILES_REF"
git -C "$source_dir" checkout --detach "$DOTFILES_REF"
[ -f "$source_dir/bootstrap/standalone.sh" ] || die 'Selected release is not the standalone profile; stopping.'

version=2.72.1
installer_sha256=75de125a45a82b53c16546db7057052e98c11866ded27c4b6f95a51f59432e7b
chezmoi_bin="$HOME/.local/bin/chezmoi"
if [ ! -x "$chezmoi_bin" ] || ! "$chezmoi_bin" --version | grep -q "^chezmoi version v$version,"; then
  directory=$(mktemp -d)
  trap 'rm -rf "$directory"' 0 1 2 15
  curl -fL --retry 3 "https://raw.githubusercontent.com/twpayne/chezmoi/v$version/assets/scripts/install.sh" -o "$directory/install.sh"
  printf '%s  %s\n' "$installer_sha256" "$directory/install.sh" | sha256sum --check --status || die 'Chezmoi installer checksum mismatch.'
  sh "$directory/install.sh" -b "$HOME/.local/bin" -t "v$version"
  rm -rf "$directory"
  trap - 0 1 2 15
fi
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
install -d -m 700 "$HOME/.cache/chezmoi/tmp"
"$chezmoi_bin" init --source "$source_dir"
exec bash "$source_dir/bootstrap/setup.sh" "$@"
