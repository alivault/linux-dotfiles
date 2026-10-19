# linux-dotfiles

Public, allowlisted chezmoi source for Ali's personal layer on top of
[ALNIAC](https://github.com/alivault/alniac), the Niri desktop on the Asahi Mac.

ALNIAC owns the desktop: Niri, the shell, themes, the login, the configs it
ships (Kitty, herdr, Alacritty, Foot, Ghostty, lazygit, Starship, imv, btop),
Neovim and the apps. This repository keeps only what is personal, and the few
system settings that ALNIAC does not make.

The Omarchy 4 profile that came before is at the tag `omarchy-final`.

## Bootstrap

Install **ALNIAC first**: a staged release in `~/.local/share/alniac/current`
and its checkout in `~/code/alniac`. This repository is a configuration layer,
not an OS installer.

```bash
curl -fsSL https://dots.aliabbas.dev -o /tmp/dotfiles-bootstrap.sh
less /tmp/dotfiles-bootstrap.sh
sh /tmp/dotfiles-bootstrap.sh --plan
# Only after you review the plan:
sh /tmp/dotfiles-bootstrap.sh
```

The hosted script must identify itself as the **ALNIAC** profile. The Worker
pins a reviewed commit and the checksum of `bootstrap/start.sh`; see
[`bootstrap/RELEASE.md`](bootstrap/RELEASE.md). The script installs pinned
chezmoi into `~/.local/bin`, checks out the release into
`~/.local/share/chezmoi`, and runs `bootstrap/setup.sh`: review and apply the
configuration, provision tools and services, and check health. Provisioning
can ask for `sudo` in the terminal. From a reviewed checkout, run
`bash bootstrap/setup.sh --plan` and `bash bootstrap/setup.sh` there.

## Normal workflow

```bash
chezmoi status                 # local files that differ from the source
chezmoi diff && chezmoi apply  # review and apply repository changes
chezmoi update                 # pull from GitHub and apply

# ALNIAC's Settings app writes ~/.config/alniac; save your changes with:
chezmoi re-add ~/.config/alniac

~/.local/share/chezmoi/bootstrap/provision.sh          # all provisioning steps
~/.local/share/chezmoi/bootstrap/provision.sh voxtype  # one step
~/.local/share/chezmoi/bootstrap/doctor.sh             # health check
```

`chezmoi apply` changes configuration only. Package installation, service
activation and system-wide files live in `bootstrap/` and never run during an
apply.

## Managed configuration

- **ALNIAC user profile** (`~/.config/alniac`): `config.kdl`, `bindings.kdl`,
  `shell.json`, `dock.json`, the launcher menu (`extensions/alniac-menu.jsonc`)
  and the selected theme. Files that ALNIAC generates from the release
  (`theme.kdl`, `defaults.kdl`, `default-bindings.kdl`, wallpapers, themed
  templates) are not managed.
- **ALNIAC session units**: links in `~/.config/systemd/user` to the units of
  the staged release (`alniac.service` and its helpers, plus the voxtype
  drop-in). The login needs them, and no ALNIAC script creates them.
- **Bash**: ALNIAC's default `~/.bashrc` with personal settings (editor, vi
  mode, fzf previews, the `v`, `lg` and `j` aliases) and Vite+ on `PATH`.
- **Git** settings, and **mise** tools: node and python pinned; chezmoi,
  codex and pi on `latest`.
- **Pi** settings, keybindings and extensions; **Claude Code** settings; shared
  agent skills (herdr, tanstack-cli).
- **Voxtype** configuration, its launcher (`alniac voxtype config`) and a
  service drop-in that keeps dictated text out of the journal.
- **fastfetch** layout for ALNIAC's About window; a Neovim neo-tree override;
  an `obsidian` launcher that finds the package, AppImage or Flatpak.

## Provisioning

`bootstrap/provision.sh` runs these steps in order. Each one is idempotent.

| Step | Does |
| --- | --- |
| `preflight` | Requires ALNIAC; installs `jq` |
| `session-units` | Checks the unit links; reloads the user manager |
| `kitty` | `alniac-install-terminal kitty` |
| `mise-tools` | `mise install` from the managed config |
| `vite-plus` | Installs Vite+ 0.3.0 from a checksum-pinned installer (`vp upgrade` updates it) |
| `keyd` | Caps Lock: tap for Escape, hold for Control (150 ms) |
| `apple-media-keys` | Asahi: media keys without Fn; rebuilds the initramfs |
| `bitwarden`, `obsidian` | Installs the apps (package, else Flatpak) |
| `syncthing`, `tailscale` | Installs and starts the services |
| `chromium-google-account` | `alniac-install-chromium-google-account` |
| `journal-retention` | Limits the journal to 256 MiB and seven days |
| `alniac-apps` | Runs `ui/install.sh` and every `apps/*/install.sh` from `~/code/alniac` |
| `voxtype` | Installs checksum-pinned voxtype 1.1.1, its OSD and the base.en model |
| `airpods` | Runs `~/code/alniac/airpods/setup` (builds airpodsd) |

Sign in to the apps, Pi, Codex and Claude Code yourself. Pair Syncthing
devices, authenticate Tailscale and open the Obsidian vault yourself.

## Security boundary

This is an allowlisted repository. It excludes browser profiles and
preferences, OAuth-bearing Chromium flags, GitHub CLI auth, password stores,
Pi auth and sessions, Syncthing identities and configuration, SSH keys,
cookies, caches, logs, session state, generated theme files and backups. Do
not bulk-add `$HOME` or `~/.config`.

Chezmoi is not a backup. Documents, code and app data need their own backups.

## License

Original work in this repository is available under the [MIT License](LICENSE).
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for code derived from
Omarchy.
