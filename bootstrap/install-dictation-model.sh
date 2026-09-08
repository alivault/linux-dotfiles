#!/bin/bash
set -euo pipefail
path="$HOME/.local/share/voxtype/models/ggml-base.en.bin"
hash=a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002
if [[ -f $path ]] && echo "$hash  $path" | sha256sum --check --status; then
  echo 'Verified existing base.en model'; exit 0
fi
mkdir -p "$(dirname "$path")"
tmp=$(mktemp "${path}.download.XXXXXX")
trap 'rm -f "$tmp"' EXIT
curl -fL --retry 3 'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.en.bin' -o "$tmp"
echo "$hash  $tmp" | sha256sum --check --status
mv "$tmp" "$path"
