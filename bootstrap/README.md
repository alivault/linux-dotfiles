# ALNIAC + chezmoi setup

Start with a working **ALNIAC** installation: a staged release in
`~/.local/share/alniac/current` and the checkout in `~/code/alniac`. This
bootstrap only configures an existing ALNIAC system. It does not partition,
install a desktop or login manager, replace bootloaders or reboot. The Asahi
media-key step rebuilds the initramfs to keep its keyboard-driver setting.

## From a reviewed checkout

```bash
alniac pkg add chezmoi git
chezmoi init https://github.com/alivault/linux-dotfiles.git
cd "$(chezmoi source-path)"
bash bootstrap/setup.sh --plan
bash bootstrap/setup.sh
```

For another checkout, such as `~/code/linux-dotfiles`, run the last two
commands there. Look at `git status` first. The plan makes no changes. Setup
asks for confirmation, shows `chezmoi diff`, asks again before it applies, and
keeps chezmoi's overwrite prompts. `--apply` skips the two confirmations of
the script, not the package-manager or authentication prompts.

The pipeline initializes chezmoi against the checkout, applies the user files,
runs `provision.sh` and then `doctor.sh`.

## Configuration versus provisioning

`chezmoi diff` and `chezmoi apply` manage user configuration only. The only
initialization hook makes a private temporary directory. Packages, tool
downloads, system files and services are explicit:

```bash
bash bootstrap/provision.sh --list
bash bootstrap/provision.sh                  # all steps, after chezmoi apply
bash bootstrap/provision.sh voxtype          # one step
bash bootstrap/provision.sh apple-media-keys # Asahi: media keys without Fn
bash bootstrap/doctor.sh
```

Provisioning can ask for `sudo` and can start or reload keyd, Syncthing and
Tailscale. The steps that need ALNIAC (`kitty`, `chromium-google-account`,
`alniac-apps`, `airpods`) use its commands and its checkout.

On Asahi, provisioning makes the brightness and volume keys work without Fn
(`hid_apple fnmode=1`). A separate modprobe file keeps other driver options,
applies the mode at once when the driver is loaded, and rebuilds the initramfs
so that the setting stays after a reboot. Other machines skip this step.

## Session units

The ALNIAC login (`alniac-session`) starts `alniac.service` and expects its
helper units in `~/.config/systemd/user`. Chezmoi links them to
`~/.local/share/alniac/current/session/systemd`, so they follow the staged
release. The `session-units` step checks the links and reloads the user
manager. The apps and the AirPods setup make their own timers and units.

## Journal retention and Voxtype

The `journal-retention` step installs `files/journald-retention.conf` into
`/etc/systemd/journald.conf.d/retention.conf` and restarts journald. Persistent
logs are limited to 256 MiB and seven days. This can delete older diagnostics
permanently. To remove archived logs at once after the limits apply:

```bash
bash bootstrap/provision.sh journal-retention
sudo journalctl --rotate
sudo journalctl --vacuum-time=7d --vacuum-size=256M
```

ALNIAC's dictation (`profile/dictation.py`) runs `~/.local/bin/voxtype` with
`--no-hotkey`, so the dictation key belongs to ALNIAC. The `voxtype` step
installs voxtype 1.1.1 and its OSD (`voxtype-osd`, `voxtype-osd-gtk4`) from
the release binaries, verified with SHA-256, downloads the base.en model, and
enables `voxtype.service`. Chezmoi links ALNIAC's service drop-in and keeps a
privacy drop-in that sets `RUST_LOG=warn`, so dictated text stays out of the
journal. To update voxtype, change the version and the three checksums in
`provision.d/31-voxtype.sh`.

## Hosted bootstrap

Keep **https://dots.aliabbas.dev**. The Worker is a separate project,
`~/code/dotfiles-bootstrap`. It serves the head of `main`; see
[RELEASE.md](RELEASE.md).

## Validation

```bash
bash bootstrap/check-source.sh
git diff --check
git status --short
```

Validation runs offline safety tests, source and credential checks, syntax
checks and a chezmoi apply into a disposable home. It does not provision the
host, and it is not a substitute for a test on a fresh ALNIAC machine.
