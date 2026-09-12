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
blocked = ('dot_ssh/', 'dot_aws/', 'dot_kube/', 'dot_local/state/',
           'dot_pi/agent/sessions/', 'dot_pi/agent/npm/', 'dot_pi/agent/git/',
           'dot_config/syncthing/', 'dot_config/Bitwarden/',
           'dot_config/niri/', 'dot_config/noctalia/',
           'dot_local/share/noctalia-local-plugins/', 'dot_local/share/sddm/')
files = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-co', '--exclude-standard', '-z']).decode().split('\0')
failures = []
count = 0
for name in sorted(set(files)):
    path = ROOT / name
    if not name or not path.is_file():
        continue
    count += 1
    if (name.startswith(blocked)
            or name == 'dot_local/share/desktop-assets/wallpaper.jpg'
            or path.name in {'auth.json', 'private_auth.json', '.env', 'credentials'}):
        failures.append(f'Forbidden source path: {name}')
    if any(pattern.search(path.read_bytes()) for pattern in patterns):
        failures.append(f'Possible credential in {name} (value suppressed)')
if failures:
    raise SystemExit('\n'.join(failures))
print(f'Public-tree path/credential checks passed: {count} files. Manual review is still required.')
