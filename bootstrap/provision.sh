#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
steps_dir="$script_dir/provision.d"

usage() {
  cat <<'EOF'
Usage: bootstrap/provision.sh [--list] [step ...]

Run all idempotent workstation provisioning steps, or only the named steps.
Names may be given with or without their numeric prefix and .sh suffix.
EOF
}

list_steps() {
  local step
  for step in "$steps_dir"/*.sh; do
    basename "$step" .sh
  done
}

resolve_step() {
  local requested=$1
  local step base short

  requested=${requested%.sh}
  for step in "$steps_dir"/*.sh; do
    base=$(basename "$step" .sh)
    short=${base#*-}
    if [[ $requested == "$base" || $requested == "$short" ]]; then
      printf '%s\n' "$step"
      return 0
    fi
  done

  printf 'error: unknown provisioning step: %s\n' "$requested" >&2
  return 1
}

case ${1:-} in
--help | -h)
  usage
  exit 0
  ;;
--list)
  list_steps
  exit 0
  ;;
esac

steps=()
if (($#)); then
  for requested in "$@"; do
    steps+=("$(resolve_step "$requested")")
  done
else
  while IFS= read -r step; do
    steps+=("$step")
  done < <(printf '%s\n' "$steps_dir"/*.sh | sort)
fi

for step in "${steps[@]}"; do
  printf '\n==> Provisioning: %s\n' "$(basename "$step" .sh)"
  bash "$step"
done

printf '\nProvisioning complete.\n'
