#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# Oasis's setup builds airpodsd into ~/.local and enables airpods.service.
setup="$HOME/code/oasis/airpods/setup"
[[ -x $setup ]] || bootstrap_die "missing Oasis checkout: $setup"
"$setup" </dev/null
