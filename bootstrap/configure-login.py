#!/usr/bin/env python3
"""Preview/explicitly configure Noctalia Greeter. Never stop the current desktop."""
import argparse
import datetime
import json
import os
from pathlib import Path
import pwd
import shutil
import subprocess
import tomllib


def login_config(user, autologin=False):
    text = '[terminal]\nvt = 1\n\n[default_session]\ncommand = "/usr/bin/noctalia-greeter-session"\nuser = "greeter"\n'
    if autologin:
        text += '\n[initial_session]\ncommand = "niri-session"\nuser = ' + json.dumps(user) + '\n'
    return text


def existing_policy(text):
    config = tomllib.loads(text)
    session = config.get('default_session', {})
    if session.get('command') == '/usr/bin/noctalia-greeter-session' and session.get('user') == 'greeter':
        return 'preserve'
    if config == {'terminal': {'vt': 1}, 'default_session': {'command': 'agreety --cmd /bin/sh', 'user': 'greeter'}}:
        return 'stock'
    raise RuntimeError('Custom greetd configuration: merge manually; no changes made.')


def reject_symlinks(path):
    for part in (path, *path.parents):
        if part.is_symlink():
            raise RuntimeError(f'Refusing symlink destination: {part}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--user', required=True, help='Existing unprivileged desktop account')
    parser.add_argument('--autologin', action='store_true', help='Opt in to passwordless initial session on a NEW setup')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    account = pwd.getpwnam(args.user)
    if account.pw_uid < 1000:
        parser.error('Select an unprivileged desktop account, not root/a system account')
    if args.apply and os.geteuid() != 0:
        parser.error('--apply requires local pkexec authentication')
    config = Path('/etc/greetd/config.toml')
    appearance = Path('/var/lib/noctalia-greeter/greeter.toml')
    for path in ([config, appearance] if args.apply else [config]):
        reject_symlinks(path)
    display_manager = Path('/etc/systemd/system/display-manager.service')
    if display_manager.exists() or display_manager.is_symlink():
        if not display_manager.is_symlink() or display_manager.resolve() != Path('/usr/lib/systemd/system/greetd.service'):
            raise RuntimeError('Another display manager is enabled. Review its retirement first.')
    for command in ['noctalia-greeter-session', 'niri-session']:
        if not shutil.which(command):
            raise RuntimeError(f'Install {command} before configuring login')
    policy = existing_policy(config.read_text()) if config.exists() else 'new'
    desired = login_config(args.user, args.autologin)
    print('Preserve existing Noctalia login/autologin configuration.' if policy == 'preserve' else desired)
    print('Enable greetd for next boot. No services will be started or stopped.')
    if not args.apply:
        print('Plan only. Pass --apply after review.')
        return
    backup = Path('/var/backups/standalone-login') / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True, mode=0o700)
    had_appearance = appearance.exists()
    empty_appearance = had_appearance and not any(tomllib.loads(appearance.read_text()).values())
    for path in [config, appearance, Path('/etc/pam.d/greetd')]:
        if path.is_file():
            shutil.copy2(path, backup / ('greetd.toml' if path == config else path.name))
    try:
        pwd.getpwnam('greeter')
    except KeyError:
        subprocess.run(['useradd', '--system', '--user-group', '--shell', '/usr/bin/nologin', '--home-dir', '/var/lib/noctalia-greeter', 'greeter'], check=True)
    if policy != 'preserve':
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(desired)
        config.chmod(0o644)
    # Reviewed upstream helper supplies the PAM runtime session and private state directories.
    if policy != 'preserve' or not had_appearance:
        subprocess.run(['/usr/share/noctalia-greeter/setup_greeter_system.sh'], check=True)
    # The package hook creates a comment-only factory file. Customize that, not user preferences.
    if not had_appearance or (policy != 'preserve' and empty_appearance):
        asahi = Path('/sys/firmware/devicetree/base/compatible')
        scale = 2 if asahi.exists() and b'apple,arm-platform' in asahi.read_bytes() else 1
        appearance.write_text('[session]\ndefault = "Niri"\n\n[user]\ndefault = ' + json.dumps(args.user)
                              + '\n\n[appearance]\nscheme = "Tokyo-Night"\nhide_logo = true\npassword_style = "default"\n'
                              + f'\n[output]\nscale = {scale}\n\n[idle]\ntimeout = 60\n')
        greeter = pwd.getpwnam('greeter')
        os.chown(appearance, greeter.pw_uid, greeter.pw_gid)
        appearance.chmod(0o640)
    subprocess.run(['systemctl', 'enable', 'greetd.service'], check=True)
    print(f'Backup: {backup}. Reboot only after checking login and doctor output.')


if __name__ == '__main__':
    main()
