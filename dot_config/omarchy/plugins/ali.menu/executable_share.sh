#!/bin/bash

set -u

notify_error() {
  local message=$1
  if command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -g "" -u critical "Could not share clipboard" "$message"
  else
    notify-send -u critical "Could not share clipboard" "$message"
  fi
}

# Run LocalSend in a transient user service so it survives the menu process.
# Temporary clipboard payloads are removed only after LocalSend exits.
if [[ ${1:-} == "--worker" ]]; then
  temporary=${2:-0}
  shift 2
  if ! localsend --headless send "$@"; then
    notify_error "LocalSend failed while sending the clipboard."
    status=1
  else
    status=0
  fi
  (( temporary )) && rm -f -- "$@"
  exit "$status"
fi

if ! command -v localsend >/dev/null 2>&1; then
  notify_error "LocalSend is not installed."
  exit 1
fi

if ! command -v wl-paste >/dev/null 2>&1; then
  notify_error "wl-paste is not installed."
  exit 1
fi

types=$(wl-paste --list-types 2>/dev/null) || {
  notify_error "The clipboard is empty or unavailable."
  exit 1
}

has_type() {
  grep -Fqx -- "$1" <<<"$types"
}

mime=""
suffix=".bin"
for candidate in \
  "image/png:.png" \
  "image/jpeg:.jpg" \
  "image/webp:.webp" \
  "image/gif:.gif" \
  "image/svg+xml:.svg" \
  "application/pdf:.pdf" \
  "text/plain;charset=utf-8:.txt" \
  "text/plain:.txt" \
  "UTF8_STRING:.txt" \
  "STRING:.txt" \
  "text/html:.html" \
  "text/uri-list:.uri-list"; do
  type=${candidate%:*}
  if has_type "$type"; then
    mime=$type
    suffix=${candidate##*:}
    break
  fi
done

if [[ -z $mime ]]; then
  mime=$(head -n 1 <<<"$types")
fi

[[ -n $mime ]] || {
  notify_error "The clipboard has no shareable content."
  exit 1
}

payload=$(mktemp --suffix="$suffix") || {
  notify_error "Could not create a temporary clipboard file."
  exit 1
}

if ! wl-paste --type "$mime" >"$payload" 2>/dev/null || [[ ! -s $payload ]]; then
  rm -f -- "$payload"
  notify_error "Could not read clipboard data of type $mime."
  exit 1
fi

script_path=$(readlink -f "$0")
if ! systemd-run --user --quiet --collect "$script_path" --worker 1 "$payload"; then
  rm -f -- "$payload"
  notify_error "Could not start LocalSend."
  exit 1
fi
