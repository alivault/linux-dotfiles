#!/usr/bin/env python3
"""Check the current candidate tree, not personal runtime state or Git history."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
patterns = [
    re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}'),
    re.compile(rb'sk-(?:proj-)?[A-Za-z0-9_-]{30,}'),
]
# Paths in home/ (linked) and seed/ (copied) that must never be in this repository.
private = ('.ssh/', '.aws/', '.kube/', '.gnupg/', '.local/state/',
           '.pi/agent/sessions/', '.pi/agent/npm/', '.pi/agent/git/', '.pi/agent/auth.json',
           '.config/syncthing/', '.config/Bitwarden/', '.config/rclone/', '.config/gh/',
           '.config/chromium', '.config/rbw/', '.claude/.credentials.json', '.codex/auth.json')
blocked = tuple(f'{top}/{p}' for top in ('home', 'seed') for p in private)
files = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-co', '--exclude-standard', '-z']).decode().split('\0')
failures = []
count = 0
for name in sorted(set(files)):
    path = ROOT / name
    if not name or not path.is_file():
        continue
    count += 1
    if (name.startswith(blocked)
            or path.name in {'auth.json', 'private_auth.json', '.env', 'credentials'}):
        failures.append(f'Forbidden source path: {name}')
    if any(pattern.search(path.read_bytes()) for pattern in patterns):
        failures.append(f'Possible credential in {name} (value suppressed)')
if failures:
    raise SystemExit('\n'.join(failures))
print(f'Public-tree path/credential checks passed: {count} files. Manual review is still required.')
