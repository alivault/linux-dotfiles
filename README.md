# linux-dotfiles

Public, allowlisted Chezmoi source for Ali's Omarchy workstation.

## Bootstrap

Install **Omarchy 4 first** (including the supported Apple Silicon port on
Asahi). This repository is your chezmoi configuration layer, not an OS installer.
It does not install Niri/Noctalia, replace the login manager, or change disks,
bootloaders or the boot setup.

The public bootstrap hostname remains **`dots.aliabbas.dev`**:

```bash
curl -fsSL https://dots.aliabbas.dev -o /tmp/dotfiles-bootstrap.sh
less /tmp/dotfiles-bootstrap.sh
sh /tmp/dotfiles-bootstrap.sh --plan
# Only after reviewing the plan and confirming this is the Omarchy release:
sh /tmp/dotfiles-bootstrap.sh
```

The hosted script must identify itself as the **Omarchy 4** profile. Never run
an older standalone-desktop release on Omarchy. The Worker is pinned separately
from this repository; see [`bootstrap/RELEASE.md`](bootstrap/RELEASE.md) when
publishing changes. To use a reviewed local checkout instead, run
`bash bootstrap/setup.sh --plan` and `bash bootstrap/setup.sh` there.

The Worker pins a reviewed Git commit and the bootstrap script checksum. It
installs pinned chezmoi into `~/.local/bin`, checks out the release into
`~/.local/share/chezmoi`, then runs the same explicit `bootstrap/setup.sh`
pipeline: preview/apply configuration, provision tools and services, activate
Ashen, and check health. Provisioning may request `sudo` in the terminal.
See [`bootstrap/README.md`](bootstrap/README.md) for checkout-based setup.

Normal Chezmoi applies are configuration-only. Package installation, service
activation, and system-wide configuration live under `bootstrap/` in the
source repository and never run implicitly during `chezmoi apply`.

## Normal workflow

```bash
# See local files that differ from the saved source state
chezmoi status

# Refresh a managed file in the source state
chezmoi add ~/.config/hypr/bindings.lua

# Review and apply repository changes to this machine
chezmoi diff
chezmoi apply

# Pull from GitHub and apply
chezmoi update

# Install packages and configure services explicitly
~/.local/share/chezmoi/bootstrap/provision.sh

# Re-run one provisioning step
~/.local/share/chezmoi/bootstrap/provision.sh tailscale

# Validate a configured workstation
~/.local/share/chezmoi/bootstrap/doctor.sh
```

The source repository is available locally with `chezmoi cd` or at
`~/.local/share/chezmoi`.

## Omarchy compatibility

This repository targets Omarchy 4. Its paths follow the Omarchy 4 split:

- `/usr/share/omarchy` contains packaged Omarchy files.
- `~/.config/omarchy` contains user configuration managed by chezmoi.
- `~/.local/state/omarchy/current` contains generated current-theme state and
  must not be added to chezmoi.

The chezmoi source checkout living under `~/.local/share/chezmoi` is normal
chezmoi behavior and is unrelated to the Omarchy version.

Chezmoi uses a private temporary directory beneath its cache. An initialization
hook creates it with mode `0700`. This keeps temporary files on the same
filesystem as the source state, enabling `chezmoi edit` hardlinks and watch
mode on systems where `/tmp` is a tmpfs.

## Managed configuration

- Omarchy shell settings, branding, menu extension, and `ali.menu` plugin,
  presented as the process-free Unified Launcher with integrated clipboard history
  plus emoji picker and reminder views; the companion `ali.indicators` clone
  routes the bar reminder button into those views
- Public iWeather plugin installed as a weekly fast-forward-only Chezmoi Git
  external
- Timezones bar widget with system-local Home and Bergen clocks, a static bar
  icon, and right-click 12/24-hour switching
- Bootstrap installation of Tailscale, Syncthing, Bitwarden, and Obsidian,
  enabling Syncthing's user service automatically and using native Omarchy
  packages where available with Flatpak fallbacks on ARM, plus Chromium Google
  account support through Omarchy's stock installer
- Hyprland bindings, input, appearance, and monitor overrides
- System-wide keyd Caps Lock mapping: tap for Escape, hold for Control, with a 150 ms tap timeout
- Alacritty, Foot, Ghostty, and Kitty settings, with Kitty as the default terminal
- Vite+ (`vp`) installed in `~/.vite-plus` without replacing the existing Node.js manager
- Git, Herdr, imv, and the Hyprland preview share picker
- Pi settings, keybindings, extensions, theme, and shared Herdr skill
- Retained desktop-independent Fish/Starship preferences, current Herdr
  keybindings, and pinned mise/Pi/Codex tools and package preferences

The Vite+ bootstrap is pinned to version `0.3.0`. Its versioned installer is
downloaded from the upstream release tag and verified with SHA-256 before use.
The public bootstrap similarly pins Chezmoi and verifies its installer.

Asahi-specific screen-recording compatibility files and 2x display scaling are
enabled only when the device tree identifies an Apple ARM platform. Other
Omarchy systems use normal 1x automatic monitor scaling.

Tmux is deliberately not included.

The Omarchy configuration is restored from `29c2d3b`, the last revision before
the standalone-desktop migration. It includes the Arch-logo screensaver from
`6f4d8e8`, natural trackpad scrolling, and the original personal Omarchy plugins.
Newer desktop-independent preferences are retained. Nothing in this restoration
automatically applies files to an existing desktop or removes its old live data.

## Security boundary

This is an allowlisted repository. It intentionally excludes browser
profiles and preferences, OAuth-bearing Chromium flags, GitHub CLI auth,
password stores, Pi auth and sessions, Syncthing identities and configuration,
cookies, caches, generated package trees, logs, session state, themes generated
by Omarchy, and historical backups. Do not bulk-add `$HOME` or `~/.config`.

## License

Original work in this repository is available under the [MIT License](LICENSE).
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for code copied from or
derived from Omarchy.
