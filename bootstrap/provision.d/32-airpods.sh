#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# ALNIAC's setup builds airpodsd into ~/.local and enables airpods.service.
setup="$HOME/code/alniac/airpods/setup"
[[ -x $setup ]] || bootstrap_die "missing ALNIAC checkout: $setup"
"$setup" </dev/null
