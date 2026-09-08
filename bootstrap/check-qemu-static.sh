#!/bin/bash
# Explicit local-Docker test of amd64 emulation on this ARM64 machine.
set -euo pipefail
[[ $(uname -m) == aarch64 ]] || { echo 'This test targets ARM64 hosts.' >&2; exit 1; }
unset DOCKER_CONTEXT
export DOCKER_HOST=unix:///run/docker.sock
image='docker.io/library/busybox@sha256:7a3ebe5bfd1a4a19797d20b0c0bb39d44393e9a03fd852c0865b0f540d868df0'
docker run --rm --platform=linux/amd64 --read-only --network=none \
  --cap-drop=ALL --security-opt=no-new-privileges --pids-limit=32 \
  --memory=64m --cpus=1 --user=65534:65534 --entrypoint=sh "$image" -ec '
    arch=$(uname -m)
    test "$arch" = x86_64
    echo "PASS: amd64 container executed on ARM64; uname=$arch"
  '
