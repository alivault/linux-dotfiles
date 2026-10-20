# linux-dotfiles

Public, allowlisted chezmoi source for Ali's personal layer on top of
[ALNIAC](https://github.com/alivault/alniac), the Niri desktop on the Asahi Mac.

ALNIAC owns the desktop: Niri, the shell, themes, the login, the configs it
ships (Alacritty, Foot, Ghostty, lazygit, Starship, imv, btop),
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
serves `bootstrap/start.sh` from the head of `main`, so **every push to `main`
is live for new machines within minutes**; see
[`bootstrap/RELEASE.md`](bootstrap/RELEASE.md). The script installs pinned
chezmoi into `~/.local/bin`, checks out that commit into
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
  `shell.json`, `dock.json`, `desktop.json` (icons, title bars), `appearance`,
  the theme choice (`themes/installed.json`), the launcher menu (`extensions/alniac-menu.jsonc`)
  the selected theme, and the branding art (`branding/screensaver.txt`, the
  screensaver's Arch logo, and `branding/about.txt`). Files that ALNIAC generates from the release
  (`theme.kdl`, `defaults.kdl`, `default-bindings.kdl`, wallpapers, themed
  templates) are not managed.
- **ALNIAC session units**: links in `~/.config/systemd/user` to the units of
  the staged release (`alniac.service` and its helpers, plus the voxtype
  drop-in). The login needs them, and no ALNIAC script creates them.
- **Bash**: ALNIAC's default `~/.bashrc` with personal settings (editor, vi
  mode, fzf previews, the `v`, `lg` and `j` aliases) and Vite+ on `PATH`.
- **Git** settings, and **mise** tools: node and python pinned; chezmoi,
  codex and pi on `latest`.
- **Pi** settings, keybindings, extensions and packages as on the Mac (packages not
  pinned: `pi update` keeps them current); **Claude Code** settings; shared
  agent skills (herdr, tanstack-cli).
- **Voxtype** configuration, its launcher (`alniac voxtype config`) and a
  service drop-in that keeps dictated text out of the journal.
- **Kitty** (no window padding, JetBrainsMono 12, hidden decorations, tab bar;
  colours from the ALNIAC theme) and **herdr** (keybindings, `move-pane.sh`, the
  terminal's palette). ALNIAC ships defaults for both; these replace them.
- **fastfetch** layout for ALNIAC's About window; a Neovim neo-tree override;
  an `obsidian` launcher that finds the package, AppImage or Flatpak.

## Agent safety

On 2026-10-19 an agent ran `rm -rf $T/*` in a new shell where `T` was empty,
and deleted the home directory. These guard every coding agent:

- **`set -u` before every command:** pi's `shellCommandPrefix`
  (`~/.pi/agent/settings.json`, which Pico's agents also use). An unset
  variable stops the command before it runs.
- **An `rm` guard first on agents' `PATH`** (`~/.local/share/agent-guard/bin/rm`):
  it refuses `/`, top-level directories, `$HOME` and what is directly in it,
  the directories directly in `~/.config`, `~/.local/share`, `~/.local/state`
  and `~/code`, and git repositories. Tests: `bootstrap/test_agent_guard.py`.
- **One set of agent rules** in `~/.pi/agent/AGENTS.md`, linked as
  `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`: each bash call is a new
  shell; use `gio trash`, not `rm`; push what you commit.
- **The doctor fails a repository in `~/code` without a remote**, and warns
  about commits that are not pushed.

## Provisioning

`bootstrap/provision.sh` runs these steps in order. Each one is idempotent.

| Step | Does |
| --- | --- |
| `preflight` | Requires ALNIAC; installs `jq` |
| `session-units` | Checks the unit links; reloads the user manager |
| `alniac-configs` | Installs ALNIAC's missing default configs (terminals, Chromium flags, autostart overrides); keeps existing files |
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
| `agent-skills` | Links ALNIAC's agent skills (`alniac`, `diagnose-crash`) into every agent |

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
