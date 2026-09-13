# Omarchy + chezmoi setup

Start with a working, updated **Omarchy 4** installation. On Apple Silicon, use
the supported Asahi Omarchy port first. This bootstrap only configures an
existing Omarchy system; it does not partition, install a desktop/login manager,
replace bootloaders, or reboot. The Asahi media-key step rebuilds the initramfs
to persist its keyboard-driver setting.

## From a reviewed checkout

Install chezmoi and Git with Omarchy's package workflow if missing. On a fresh
machine, after the restored revision has been published:

```bash
omarchy pkg add chezmoi git
chezmoi init https://github.com/alivault/linux-dotfiles.git
cd "$(chezmoi source-path)"
bash bootstrap/setup.sh --plan
bash bootstrap/setup.sh
```

For an existing checkout such as `~/code/linux-dotfiles`, run those final two
commands there instead. Review `git status` first. The plan makes no changes.
This does not switch your default chezmoi source directory: with a separate
clone, use `chezmoi --source ~/code/linux-dotfiles diff` and
`chezmoi --source ~/code/linux-dotfiles apply` for subsequent updates. The normal
commands in the root README assume the standard `~/.local/share/chezmoi` source.
Normal setup asks for confirmation, shows `chezmoi diff`, asks before applying,
and retains chezmoi's overwrite/conflict prompts. `--apply` explicitly skips the
two wrapper confirmations, not package-manager or authentication prompts.

The pipeline initializes chezmoi against that checkout, applies user files,
runs `provision.sh`, selects Ashen, and runs `doctor.sh`. It does not run the
retired standalone installers. Running setup is an explicit opt-in to your
personal Omarchy profile, including its shell/menu plugins and shortcuts.

## Configuration versus provisioning

`chezmoi diff` / `chezmoi apply` manage user configuration only. The sole
initialization hook creates a private temporary directory. Packages, mise tool
downloads, keyd configuration and service activation remain explicit:

```bash
bash bootstrap/provision.sh --list
bash bootstrap/provision.sh                 # all steps, after chezmoi apply
bash bootstrap/provision.sh tailscale       # one step
bash bootstrap/provision.sh apple-media-keys # Asahi: media keys without Fn
bash bootstrap/doctor.sh
```

Provisioning installs Kitty, mise tools, pinned Vite+, keyd, Bitwarden,
Obsidian, Syncthing, Chromium account support and Tailscale. It may request
`sudo` and start/reload keyd, Syncthing and Tailscale. Fish configuration is
retained but does not change your login shell; install Fish separately if wanted.

On Asahi, provisioning restores brightness/volume keys without holding Fn
(`hid_apple fnmode=1`). A separate modprobe override preserves Omarchy's driver
configuration, applies the mode immediately when the driver is loaded, and
rebuilds the initramfs for reboot persistence. Other machines skip this step.

Sign into applications and Pi/Codex manually. Pair Syncthing devices/folders,
authenticate Tailscale, and choose the Obsidian vault yourself. No identities,
passwords, browser profiles or authentication stores are imported.

## Journal retention and Voxtype

The `journal-retention` provisioning step installs
`files/journald-retention.conf` into `/etc/systemd/journald.conf.d/retention.conf`
and restarts journald. Persistent logs are limited to 256 MiB and seven days;
activating these limits can permanently delete older diagnostics. This step
runs only during explicit provisioning, never during `chezmoi apply`.
For an immediate archived-log cleanup after applying the limits:

```bash
bash bootstrap/provision.sh journal-retention
sudo journalctl --rotate
sudo journalctl --vacuum-time=7d --vacuum-size=256M
```

Chezmoi manages Voxtype's configuration, its **Voxtype Configuration** desktop
entry (launching `omarchy voxtype config`), and a user-service privacy drop-in.
The drop-in sets `RUST_LOG=warn` to suppress INFO-level dictated-text logging
while retaining warnings/errors. Existing journal entries are not scrubbed.
After applying it, restart Voxtype while idle:

```bash
systemctl --user daemon-reload
systemctl --user restart voxtype.service
```

Voxtype, its model, and its daemon service must already be installed. Built
binaries, models, audio, and journals are not stored in this repository.
The ARM workstation uses source-built Voxtype 0.7.2 with its own GTK4 OSD,
not an Omarchy OSD bridge. To reproduce just the matching OSD binaries on a
machine with Rust, Git, GTK4, gtk4-layer-shell, ALSA, clang, CMake and pkgconf:

```bash
build_dir=$(mktemp -d)
git clone https://github.com/peteonrails/voxtype.git "$build_dir/voxtype"
git -C "$build_dir/voxtype" checkout --detach 858a4ece13490bc6cdba88777c56246d8e89ffad
(
  cd "$build_dir/voxtype"
  cargo build --locked --release --features osd-gtk4 \
    --bin voxtype-osd --bin voxtype-osd-gtk4 -j 2
)
mkdir -p ~/.local/bin
install -m755 "$build_dir/voxtype/target/release/voxtype-osd" \
  "$build_dir/voxtype/target/release/voxtype-osd-gtk4" ~/.local/bin/
systemctl --user restart voxtype.service
```

Both `voxtype-osd` and `voxtype-osd-gtk4` must be on the daemon's PATH.
Version 0.7.2 enables the GTK4 OSD by default and supervises it automatically;
no separate OSD service is needed. Match the OSD version to the installed
daemon rather than mixing these binaries with a newer release.
Syncthing discovery and firewall rules are deliberately not changed.

## Hosted bootstrap

Keep **https://dots.aliabbas.dev**. The Worker lives separately at
`~/code/dotfiles-bootstrap`; changing this repo cannot update its release pin.
See [RELEASE.md](RELEASE.md). Never use the old standalone release to test this
Omarchy restoration on a live machine.

## Validation

```bash
bash bootstrap/check-source.sh
git diff --check
git status --short
```

Validation runs offline safety tests, source/credential heuristics, syntax
checks and a disposable-home chezmoi apply. That apply fetches the public
iWeather and Omachron externals, so it needs GitHub access. It does not provision the host.
These checks are not a substitute for a fresh-machine test or physical
lock/unlock, suspend, capture and hardware checks.
