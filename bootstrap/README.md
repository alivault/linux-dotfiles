# Explicit setup and recovery

## Preconditions

Start from an already bootable, fully updated Arch Linux or Arch Linux ARM
installation, with networking and a normal PAM-login user. Install `git`, `curl`
and `polkit` using your existing local administrator access. Package database
refreshes must be part of a full Arch upgrade, not `pacman -Sy` partial upgrades.
Use the appropriate upstream Asahi installation process before this profile;
this project never supplies kernels, firmware, boot configuration or disk setup.

Keep another TTY/login available. Review these files before privileged setup:

- `packages/*.txt`: official packages only; availability is checked before the
  transaction. No removals or AUR dependency resolution. Native tool pins are in
  `tools.lock.json`; Node/Pi/Codex pins are also explicit in mise/wrappers.
- `system-files/`: resolver discovery settings, Wi-Fi power-saving,
  sysctl/logind/limits, and Caps Control/Escape keyd.
  These are **this profile's policies**, not universal defaults. Custom existing
  files cause refusal rather than silent replacement. No Docker bridge or
  container DNS listener is configured.
- `asahi-files/`: verbatim tested keyboard-backlight suspend/resume workaround,
  applied only on detected Asahi. Historical comments are retained deliberately.
- `greeter/`: SHA256-pinned Noctalia Greeter 1.3.1 build. Its upstream setup helper
  adds the PAM runtime-session module, preserves a backup and prepares greeter
  state. No blanket passwordless appearance-sync permission is installed.

## Pipeline

```sh
bash bootstrap/setup.sh --plan   # read-only plan, no provisioning
bash bootstrap/setup.sh          # interactive review and explicit setup
```

`--apply` explicitly skips the two top-level confirmation questions, **not** local
authentication, pacman confirmations or chezmoi conflict handling. Normal
`chezmoi apply` never performs these provisioning actions.

The pipeline installs packages, previews/applies configuration, installs native
tools and pinned editor/Pi packages, downloads the dictation model, installs
Bitwarden through user-scoped Flathub, builds the greeter, installs system files,
enables services and configures the next login. It does not reboot or restart the
current desktop. Extensions/plugins execute code as your user: review their
pinned sources before accepting the pipeline.

Individual actions are available through `bash bootstrap/provision.sh --help`.
`system` and `login` are previews unless passed `--apply`. `greeter` builds only
unless passed `--apply`. Packages/tools/model/editor/Pi/Bitwarden/appearance and
service-enabling actions are explicit mutations, not previews.

### Login

New installs use password-protected Noctalia Greeter and Niri. Existing Noctalia
login/autologin and nonempty appearance configuration are preserved. Only the
stock `agreety --cmd /bin/sh` greetd configuration may be replaced automatically;
custom login files or another enabled display manager require a manual merge.
On a **new** setup only, autologin can be deliberately selected with:

```sh
bash bootstrap/provision.sh login --apply --autologin
```

This allows anyone at the machine to enter the initial session without a
password. It is not the fresh-install default and does not change an existing
Noctalia setup. `greetd` is enabled for next boot, never restarted by this script.

### Optional tools

```sh
bash bootstrap/provision.sh vite-plus
bash bootstrap/build-qemu-static.sh                # ARM64 build only; no installation
```

Vite+ 0.3.0 is optional and does not take over mise's Node management. Static
QEMU is documented in [qemu-static/README.md](qemu-static/README.md): the retained
10.0.11 package pin needs a future security/version review. It is not presented
as the latest security release and is not installed by the default pipeline.

## After reboot

- Log in to Pi (`/login`, then select your provider/model), Codex CLI and
  Bitwarden. Source includes no credentials. Pi packages are pinned; unrelated
  settings and resource filters survive the chezmoi settings merge.
- Authenticate Tailscale explicitly. Create/import SSH keys locally and verify
  host fingerprints. SSH/firewall exposure is your explicit network decision.
- Open `http://127.0.0.1:8384`, pair the new Syncthing device and share your vault.
  Select its local directory in Obsidian; no device ID or vault data is imported.
- Configure a printer; install any hardware-specific driver separately. No
  printer is assumed by this profile.
- Confirm lock/unlock, suspend/resume, internal/keyboard brightness, Wi-Fi,
  Bluetooth, safe audio, screen sharing, printing and F9 dictation notifications.
  `screen-share-test.html` is a local browser test page, not a hosted service.
- Docker is not installed or enabled by this profile. The optional historical
  `check-qemu-static.sh` test requires a separately installed Docker engine;
  QEMU itself does not require Docker.
  Review `/etc/resolv.conf` against the enabled resolver on a new installation;
  the installer deliberately does not replace an existing resolver symlink.

## Recovery

Switch to another TTY, sign in and inspect `journalctl -b -u greetd` and
`journalctl --user -b`. For login recovery, use a local administrator shell to
disable greetd for the next boot, then restore the individually reviewed backup
from `/var/backups/standalone-login/`; do not restore unrelated old desktop files.
System-policy backups are under `/var/backups/standalone-desktop/`. Do not remove
Asahi packages or the keyboard-backlight helper as part of desktop recovery.

Installer failures stop the pipeline. There is no blanket transaction rollback:
inspect the failed step and backups, correct it, then rerun that explicit action.
No fresh-machine VM boot is claimed by the offline/source tests.
