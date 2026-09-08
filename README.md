# Ali's Linux dotfiles

Personal **Arch Linux / Arch Linux ARM** desktop configuration and explicit setup
scripts, managed by [chezmoi](https://www.chezmoi.io/). The desktop uses **Niri**,
**Noctalia** and **Vicinae**, with **Kitty + Herdr + Pi** for coding.

Used on an Asahi MacBook Air M1. The manifests and release pins also target
x86_64, but fresh-machine and x86_64 boot smoke tests remain outstanding.

This is a standalone profile for an **already installed, bootable Arch system**,
not an OS installer. It does not require Omarchy, partition disks, or install or
replace Asahi kernels, firmware, bootloaders or speaker-safety components.

The bar includes a native [iWeather widget](dot_local/share/noctalia-local-plugins/iweather/README.md)
with hourly/five-day forecasts, city search and unit switching. No API key is
needed; chosen locations and cached forecasts stay outside the public source.

## Install

Start with an updated Arch Linux or Arch Linux ARM system, networking, a normal
login user, and `git`, `curl` and `polkit` installed. Review the
[setup requirements](bootstrap/README.md) and [release notes](bootstrap/RELEASE.md).

```sh
curl -fsSL https://dots.aliabbas.dev -o /tmp/dotfiles-bootstrap.sh
less /tmp/dotfiles-bootstrap.sh
sh /tmp/dotfiles-bootstrap.sh
```

The bootstrap endpoint verifies the script checksum and selects an immutable
repository commit. Setup asks before provisioning and applying configuration;
package installation and system changes require local administrator approval.
The hosted release is pinned separately from this repository's latest commit.

For the current local checkout:

```sh
cd "$(chezmoi source-path)"
bash bootstrap/check-source.sh
bash bootstrap/setup.sh --plan
# Review bootstrap/README.md, then explicitly run bootstrap/setup.sh when needed.
```

To preview and apply configuration from your current chezmoi checkout without
running the provisioning pipeline:

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
- Kitty, Herdr and Pi, including clickable desktop notifications that return to
  the originating agent pane and raise its Kitty window through Niri.
- Chromium, Obsidian, LibreOffice, LazyVim/Neovim, tmux, mise-managed
  Node/Pi/Codex CLI, and F9 toggle dictation.
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
are pinned and Pi telemetry is disabled. Herdr plugin registration preserves
other installed plugins and the notification plugin's enabled/disabled choice.

The existing personal `~/.local/share/desktop-assets/wallpaper.jpg` is preserved
if present, but is not redistributed. Fresh installs use the original generated
`wallpaper.png`; its generator is in `bootstrap/`. Third-party attributions and
license exceptions are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

See [setup and recovery](bootstrap/README.md), [release review](bootstrap/RELEASE.md)
and [validation](.github/workflows/validate.yml). Arch and Flatpak remain rolling
repositories: these pins are **not a hermetic OS snapshot**.
