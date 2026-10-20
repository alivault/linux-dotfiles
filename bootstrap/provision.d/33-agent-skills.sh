#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib.sh
source "$script_dir/lib.sh"

# ALNIAC ships agent skills (alniac, diagnose-crash) in its release; link them
# into every agent's skills directory (~/.agents, ~/.claude, ~/.codex,
# ~/.pi/agent, ~/.hermes, where present). Re-running relinks them.
alniac-agent-skills
