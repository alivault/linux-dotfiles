#!/bin/bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# mise may come from its own installer in ~/.local/bin; install the package only when absent.
command -v mise >/dev/null 2>&1 || ensure_package mise
config="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
[[ -f $config ]] || bootstrap_die 'Apply the chezmoi configuration before provisioning mise tools.'
mise trust "$config"
mise --cd "$HOME" install
