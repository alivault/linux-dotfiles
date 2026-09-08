#!/usr/bin/env python3
"""Install reviewed, hash-pinned upstream artifacts; never execute remote scripts.

Only installs tools explicitly named on the command line. Does not need root,
stop processes, change credentials, or remove distro packages. Replaced local
binaries are backed up. Updating means reviewing and editing tools.lock.json.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tarfile
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parent
HOME = Path.home()


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def deploy(source, dest, backup):
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.is_file() and digest(source) == digest(dest):
        return
    if dest.exists() or dest.is_symlink():
        backup.mkdir(parents=True, exist_ok=True)
        shutil.copy2(dest, backup / dest.name, follow_symlinks=True)
    temp = dest.with_name(dest.name + '.new')
    shutil.copy2(source, temp)
    temp.chmod(0o755)
    os.replace(temp, dest)


def install(name, spec, arch, backup):
    if name == 'voxtype' and arch == 'x86_64' and 'avx2' not in Path('/proc/cpuinfo').read_text():
        raise RuntimeError('Pinned Voxtype x86 build requires AVX2; select another build explicitly.')
    asset, expected = spec[arch]
    cache = HOME / '.cache/standalone-tools'
    cache.mkdir(parents=True, exist_ok=True)
    artifact = cache / asset
    if not artifact.exists() or digest(artifact) != expected:
        url = f'https://github.com/{spec["repo"]}/releases/download/{spec["tag"]}/{asset}'
        print(f'Downloading {name} {spec["tag"]}', flush=True)
        temp = artifact.with_name(artifact.name + '.download')
        with urllib.request.urlopen(url, timeout=120) as response, temp.open('wb') as output:
            shutil.copyfileobj(response, output)
        if digest(temp) != expected:
            temp.unlink()
            raise RuntimeError(f'{name}: checksum mismatch')
        os.replace(temp, artifact)
    target = HOME / '.local/bin' / name
    kind = spec['kind']
    if kind == 'binary':
        deploy(artifact, target, backup)
    elif kind == 'appimage':
        deploy(artifact, HOME / '.local/opt/obsidian/Obsidian.AppImage', backup)
    elif kind == 'tar-binary':
        with tarfile.open(artifact) as archive, tempfile.TemporaryDirectory() as temp:
            # Extract only a regular binary; no paths or links from the archive.
            matches = [m for m in archive.getmembers() if m.isfile() and Path(m.name).name == name]
            if len(matches) != 1:
                raise RuntimeError(f'{name}: unexpected archive layout')
            binary = Path(temp) / name
            with archive.extractfile(matches[0]) as source, binary.open('wb') as output:
                shutil.copyfileobj(source, output)
            deploy(binary, target, backup)
    elif kind == 'vicinae-appimage':
        prefix = HOME / '.local/opt' / f'vicinae-{spec["tag"]}-{expected[:12]}'
        if not (prefix / 'usr/bin/vicinae').is_file():
            prefix.parent.mkdir(parents=True, exist_ok=True)
            artifact.chmod(0o755)
            with tempfile.TemporaryDirectory(dir=prefix.parent) as temp:
                subprocess.run([str(artifact), '--appimage-extract'], cwd=temp, check=True,
                               stdout=subprocess.DEVNULL)
                os.replace(Path(temp) / 'squashfs-root', prefix)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and not target.is_symlink():
            backup.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup / name)
        link = target.with_name(name + '.new')
        link.unlink(missing_ok=True)
        link.symlink_to(prefix / 'usr/bin/vicinae')
        os.replace(link, target)
        for folder in ['vicinae/themes', 'applications', 'icons']:
            source = prefix / 'usr/share' / folder
            if source.is_dir():
                shutil.copytree(source, HOME / '.local/share' / folder, dirs_exist_ok=True)
        if shutil.which('update-desktop-database'):
            subprocess.run(['update-desktop-database', str(HOME / '.local/share/applications')], check=True)
    print(f'Installed {name} {spec["tag"]} independently of system packages', flush=True)


def main():
    lock = json.loads((ROOT / 'tools.lock.json').read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tools', nargs='+', choices=sorted(lock))
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as your normal user, not root.')
    arch = platform.machine()
    if arch not in ['aarch64', 'x86_64']:
        parser.error(f'Unsupported architecture: {arch}')
    backup = HOME / '.local/state/standalone-tool-backups' / str(time.time_ns())
    for name in args.tools:
        install(name, lock[name], arch, backup)


if __name__ == '__main__':
    main()
