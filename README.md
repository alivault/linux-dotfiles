# Ali's Linux dotfiles

Standalone **Arch Linux / Arch Linux ARM + Niri + Noctalia + Vicinae**, managed by
chezmoi. Tested on an Asahi MacBook Air M1; x86_64 is supported by the manifests
and release pins but still needs a fresh-machine smoke test.

No Omarchy installation, repository, service or runtime integration is required.
This configures an **already installed, bootable Arch system**; it never partitions
disks or installs/replaces Asahi kernels, firmware, bootloaders or speaker safety.

The bar includes a native [iWeather widget](dot_local/share/noctalia-local-plugins/iweather/README.md)
with hourly/five-day forecasts, city search and unit switching. No API key is
needed; chosen locations and cached forecasts stay outside the public source.

## Install

The canonical entry point is below. The old `d.aliabbas.dev` hostname is retired;
do not use old installer copies. Fresh-machine and x86_64 boot smoke tests are
still outstanding; review the [release notes](bootstrap/RELEASE.md).

```sh
curl -fsSL https://dots.aliabbas.dev -o /tmp/dotfiles-bootstrap.sh
less /tmp/dotfiles-bootstrap.sh
sh /tmp/dotfiles-bootstrap.sh
```

The Worker verifies the bootstrap checksum and injects an immutable repository
commit. Setup asks before provisioning and applying configuration. Local
authentication stays in pkexec; never paste a password into a chat or script.

For the current local checkout:

```sh
cd "$(chezmoi source-path)"
bash bootstrap/check-source.sh
bash bootstrap/setup.sh --plan
# Review bootstrap/README.md, then explicitly run bootstrap/setup.sh when needed.
```

Normal updates remain configuration-only:

```sh
chezmoi diff
chezmoi apply --exclude scripts
```

## Included

- Niri-native columns, 12 px rounded/clipped windows with non-xray background
  blur (visible through transparent backgrounds), 250 ms / 50 Hz keyboard repeat;
  2x internal-panel scaling only on detected Asahi machines.
- Noctalia shell, notifications, authentication, idle/lock, Tokyo Night and
  Adwaita icons; Vicinae launcher, clipboard and emoji.
- Kitty, Chromium, Obsidian, LibreOffice, LazyVim/Neovim, tmux, Herdr,
  mise-managed Node/Pi/Codex CLI, F9 toggle dictation.
- Explicit setup for Tailscale, Syncthing, SSH, printing, Bitwarden, keyd,
  Noctalia Greeter and the tested Asahi keyboard-backlight suspend helper.
- SHA256-pinned native tools/model/build sources; separate optional Vite+,
  and static QEMU installation. Docker is not included.

## Key bindings

| Keys | Action |
| --- | --- |
| Super+Space / Ctrl+Space | Launcher / clipboard |
| Super+Ctrl+E | Emoji |
| Super+E | Strata file manager |
| Super+S / Super+Comma | Control center / settings |
| Super+D | Dark/light mode |
| Super+F / Super+Shift+F | Maximize column / fullscreen |
| Super+Shift+PageUp / PageDown | Reorder workspaces |
| Super+Shift+E | Logout |
| Super+brightness keys | Keyboard brightness, 10% increments |
| F9 | Toggle dictation recording |

Tmux retains Ctrl+B as its secondary prefix (Ctrl+Space is intercepted by the
desktop clipboard binding); prefix+`?` opens tmux's native binding list.

## Privacy and appearance

Only selected source files are managed. Credentials, browser profiles, SSH keys,
Pi history/auth/trust, Bitwarden vaults, Syncthing identities and runtime state
are not captured. Noctalia GUI overrides remain local. Pi settings are merged,
preserving unrelated local values and package filters; required package versions
are pinned and telemetry is disabled.

The existing personal `~/.local/share/desktop-assets/wallpaper.jpg` is preserved
if present, but is not redistributed. Fresh installs use the original generated
`wallpaper.png`; its generator is in `bootstrap/`. Third-party attributions and
license exceptions are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

See [setup and recovery](bootstrap/README.md), [release review](bootstrap/RELEASE.md)
and [validation](.github/workflows/validate.yml). Arch and Flatpak remain rolling
repositories: these pins are **not a hermetic OS snapshot**.
