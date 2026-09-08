#!/usr/bin/env python3
"""Explicit system provisioning. Default is a read-only plan; never restart services."""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
COMMON = (
    'etc/systemd/resolved.conf.d/99-standalone.conf',
    'etc/NetworkManager/conf.d/99-standalone-wifi.conf',
    'etc/sysctl.d/99-standalone.conf',
    'etc/systemd/logind.conf.d/99-standalone.conf',
    'etc/systemd/system.conf.d/99-standalone.conf',
    'etc/systemd/user.conf.d/99-standalone.conf',
    'etc/keyd/default.conf',
)
ASAHI = (
    'etc/systemd/system/mac-kbd-backlight-resume.service',
    'etc/systemd/system/systemd-suspend.service.d/keyboard-backlight.conf',
    'usr/local/libexec/mac-kbd-backlight-sleep',
)


def is_asahi():
    path = Path('/sys/firmware/devicetree/base/compatible')
    return path.exists() and b'apple,arm-platform' in path.read_bytes()


def check_destination(path, data):
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise RuntimeError(f'Refusing symlink destination: {parent}')
    if path.exists() and (not path.is_file() or path.read_bytes() != data):
        raise RuntimeError(f'Existing custom configuration differs; merge manually: {path}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Install the printed plan; requires root')
    args = parser.parse_args()
    if args.apply and os.geteuid() != 0:
        parser.error('Use local pkexec authentication for --apply')
    sources = [(ROOT / 'system-files' / name, Path('/') / name) for name in COMMON]
    if is_asahi():
        sources += [(ROOT / 'asahi-files' / name, Path('/') / name) for name in ASAHI]
    files = [(src, dest, src.read_bytes()) for src, dest in sources]
    for _, dest, data in files:
        check_destination(dest, data)

    for _, dest, data in files:
        print(('Keep identical ' if dest.exists() else 'Install        ') + str(dest), flush=True)
    if not args.apply:
        print('Plan only. No changes made. Use --apply after review.')
        return

    os.umask(0o077)
    backup = Path('/var/backups/standalone-desktop') / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True, mode=0o700)
    existing = {dest for _, dest, _ in files if dest.exists()}
    for path in sorted(existing):
        target = backup / str(path).lstrip('/')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target, follow_symlinks=False)
    (backup / 'plan.json').write_text(json.dumps({
        'destinations': [str(dest) for _, dest, _ in files],
        'created': [str(dest) for _, dest, _ in files if not dest.exists()],
        'asahi': is_asahi(),
    }, indent=2) + '\n')
    print(f'Backup: {backup}', flush=True)
    os.umask(0o022)
    for _, dest, data in files:
        if dest.exists():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
        # Existing directory permissions are deliberately not changed.
        fd, temp = tempfile.mkstemp(prefix='.standalone-', dir=dest.parent)
        try:
            with os.fdopen(fd, 'wb') as out:
                out.write(data)
                os.fchmod(out.fileno(), 0o755 if str(dest).startswith('/usr/local/libexec/') else 0o644)
            os.replace(temp, dest)
        finally:
            if os.path.exists(temp):
                os.unlink(temp)
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    if is_asahi():
        subprocess.run(['systemctl', 'enable', 'mac-kbd-backlight-resume.service'], check=True)
    print('Installed. No services restarted; new daemon policies take effect on next start/reboot.')


if __name__ == '__main__':
    main()
