#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

ensure_package syncthing
systemctl --user enable --now syncthing.service
systemctl --user is-active --quiet syncthing.service
