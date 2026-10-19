#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

require_command curl git pacman sha256sum sudo systemctl

alniac_installed ||
  bootstrap_die "this repository requires ALNIAC: a staged release and ~/code/alniac"

ensure_package jq
require_command jq

bootstrap_log "ALNIAC $(alniac-version) on $(uname -m)"
