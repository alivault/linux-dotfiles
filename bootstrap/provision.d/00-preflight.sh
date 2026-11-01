#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

require_command curl git pacman sha256sum sudo systemctl

oasis_installed ||
  bootstrap_die "this repository requires Oasis: a staged release and ~/code/oasis"

ensure_package jq
require_command jq

bootstrap_log "Oasis $(oasis-version) on $(uname -m)"
