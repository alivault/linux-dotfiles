#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# The apps are not part of an ALNIAC release: each installs from the checkout.
# Every installer is idempotent; the sync apps also enable their user timers.
repo="$HOME/code/alniac"
[[ -x $repo/ui/install.sh ]] || bootstrap_die "missing ALNIAC checkout: $repo"
"$repo/ui/install.sh"

failed=()
for installer in "$repo"/apps/*/install.sh; do
  app=$(basename "$(dirname "$installer")")
  bootstrap_log "Installing ALNIAC app: $app"
  # Unset: a session's pinned ALNIAC_PATH may point at an older release.
  if ! env -u ALNIAC_PATH "$installer" </dev/null; then
    failed+=("$app")
  fi
done

((${#failed[@]} == 0)) || bootstrap_die "app installers failed: ${failed[*]}"
