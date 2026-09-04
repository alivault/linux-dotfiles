#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

require_command curl git omarchy pacman sha256sum sudo systemctl

case $(omarchy version) in
4.*) ;;
*) bootstrap_die "this repository requires Omarchy 4" ;;
esac

ensure_package jq
require_command jq

bootstrap_log "Omarchy $(omarchy version) on $(uname -m)"
