# linux-dotfiles

Ali's personal files on top of [Oasis](https://github.com/alivault/oasis), the
Niri desktop on NixOS on both Macs (`oasis`, the M1 Max, and `asahi`, the M1
Air).

Oasis owns the desktop: Niri, the shell, themes, the login, the configs it
ships (Alacritty, Foot, Ghostty, lazygit, Starship, imv, btop), Neovim, the
apps, the session units and the system. This repository keeps only what is
personal.

Up to November 2026 this was a chezmoi source with Arch provisioning scripts
(`bootstrap/`). That is the commit before "Moving off chezmoi" on `main`
(`70c7108`); the Omarchy 4 profile before it is at the tag `omarchy-final`.

## How it works

```
flake.nix              homeManagerModules.default (the Oasis flake imports it for ali)
nix/home.nix           the module: links home/, writes ~/.pi/agent/mcp.json
home/                  files linked into ~ at the same path (home/.bashrc -> ~/.bashrc)
seed/                  files that apps write: copied once, never linked
bin/dotfiles-seed      copies the missing seeds; --pi-settings merges pi's settings
tests/, tools/check.sh the checks (CI: .github/workflows/validate.yml)
```

- **home/** is linked, not copied. Each file in the home is a link to
  this checkout, through the Nix store:
  `~/.bashrc -> /nix/store/...-hm_.bashrc -> ~/code/dotfiles/home/.bashrc`
  (home-manager's `mkOutOfStoreSymlink`). An edit in the home is an edit in
  git at once: `git -C ~/code/dotfiles diff` shows it. Commit and push it.
- The module reads the **list** of files from the flake input that the Oasis
  flake locks, and the **content** from the checkout. So:
  - an edit to a file: nothing more to do;
  - a new file or a deleted file in `home/`: commit, push, then in
    `~/code/oasis` run `nix flake update dotfiles`, commit, and ship
    (`oasis-sync` tells you when a pull needs this).
- The checkout is at `~/code/dotfiles` (option `dotfiles.checkout`). The
  activation stops before it changes a file if the checkout is not there.
- **seed/** is for files that apps write (Oasis Settings, pi, Claude Code,
  voxtype). A link there would break: an app that writes a new file and
  renames it over the old one replaces the link, and the next switch moves the
  app's file away. These files stay each Mac's own. `bin/dotfiles-seed` copies
  a seed only where the file is missing.

## Normal workflow

```bash
git -C ~/code/dotfiles status        # what you changed in the home
git -C ~/code/dotfiles commit -am "..." && git -C ~/code/dotfiles push
oasis-sync                           # pulls oasis and this checkout, then ships

~/code/dotfiles/bin/dotfiles-seed --dry-run      # which seeds are missing here
~/code/dotfiles/bin/dotfiles-seed                # copy them (never replaces a file)
~/code/dotfiles/bin/dotfiles-seed --pi-settings  # also merge seed/pi-settings.jq into pi's settings
tools/check.sh                                   # the checks
```

To save a Mac's current Oasis profile as the seed:
`cp ~/.config/oasis/{bindings.kdl,dock.json,shell.json} seed/.config/oasis/`
(choose the files), then commit.

## Moving off chezmoi

### Inventory

Kind 1 is system setup (now NixOS, in the Oasis repository). Kind 2 is a
static file (linked from `home/`). Kind 3 is a file that its app writes (a seed
in `seed/`, not managed).

| chezmoi source | Target | Kind | Now |
| --- | --- | --- | --- |
| `private_dot_bashrc`, `dot_bash_profile` | `~/.bashrc`, `~/.bash_profile` | 2 | `home/` |
| `dot_config/git/config` | `~/.config/git/config` | 2 | `home/`; also has `[user]` now (was `provision.d/04-git.sh`) |
| `dot_config/kitty/kitty.conf` | | 2 | `home/` |
| `dot_config/fastfetch/config.jsonc` | | 2 | `home/` |
| `dot_config/mise/config.toml` | | 2 | `home/` |
| `dot_config/nvim/lua/plugins/neo-tree.lua` | | 2 | `home/` |
| `dot_config/herdr/config.toml`, `move-pane.sh` | | 2 | `home/` (config: the live file from oasis) |
| `dot_config/systemd/user/voxtype.service.d/privacy.conf` | | 2 | `home/` |
| `dot_local/bin/executable_obsidian` | `~/.local/bin/obsidian` | 2 | `home/` |
| `dot_local/share/agent-guard/bin/executable_rm` | `~/.local/share/agent-guard/bin/rm` | 2 | `home/` |
| `dot_local/share/applications/voxtype.desktop` | | 2 | `home/` |
| `dot_agents/skills/{herdr,tanstack-cli}/SKILL.md` | `~/.agents/skills/` | 2 | `home/` |
| `dot_claude/hooks/executable_herdr-agent-state.sh` | | 2 | `home/` |
| `private_dot_pi/agent/AGENTS.md` | `~/.pi/agent/AGENTS.md` | 2 | `home/` (the live file from oasis, 2026-11-05) |
| `private_dot_pi/agent/extensions/*.ts`, `keybindings.json` | | 2 | `home/` |
| `dot_claude/symlink_CLAUDE.md.tmpl`, `dot_codex/symlink_AGENTS.md.tmpl` | `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` | 2 | links to `home/.pi/agent/AGENTS.md` (`nix/home.nix`) |
| `private_dot_pi/agent/mcp.json.tmpl` | `~/.pi/agent/mcp.json` | 2 | written by Nix (`nix/home.nix`; it has the home's path) |
| `dot_config/systemd/user/symlink_oasis*.service.tmpl`, `graphical-session.target.wants/*`, `oasis.service.d/60-airpods.conf`, `voxtype.service.d/oasis.conf` | | 1 | removed: Oasis's home-manager module links them (`nix/modules/home/oasis.nix`) |
| `dot_config/oasis/{bindings.kdl,dock.json,branding/*,extensions/oasis-menu.jsonc}` | `~/.config/oasis/` | 3 | `seed/` |
| `dot_config/oasis/create_{appearance,config.kdl,desktop.json,private_shell.json,theme}` | `~/.config/oasis/` | 3 | `seed/` |
| `private_dot_pi/agent/modify_private_settings.json` | `~/.pi/agent/settings.json` | 3 | `seed/pi-settings.jq` (the filter) and `seed/.pi/agent/settings.json` (the filter on `{}`) |
| `dot_claude/settings.json` | `~/.claude/settings.json` | 3 | `seed/` |
| `dot_config/voxtype/create_config.toml` | `~/.config/voxtype/config.toml` | 3 | `seed/` |
| `.chezmoi.toml.tmpl`, `run_once_before_00-create-chezmoi-temp.sh.tmpl` | | – | removed |
| `.chezmoiignore` | | – | now ignores every path, so chezmoi writes nothing from this tree |

Oasis seeds some kind-3 files itself. On a new Mac, the Oasis home-manager
module copies its own `home/` (`bindings.kdl`, `config.kdl`, `shell.json`,
`extensions/`) to `~/.config/oasis` when that folder does not exist, and the
Oasis config templates (`config/`: kitty, herdr, git...) where a folder in
`~/.config` is missing. Oasis Settings writes `appearance`, `theme`,
`desktop.json`, `dock.json` and `~/.config/voxtype/config.toml` with its
defaults. `bin/dotfiles-seed` then fills in only what is still missing, so
run it after the first switch. To use Ali's seed for a file that Oasis
seeded, copy that file by hand.

### Provisioning steps (`bootstrap/provision.d`) on NixOS

| Step | On NixOS |
| --- | --- |
| `00-preflight` | Obsolete (pacman, Arch checks). |
| `02-session-units` | Covered: Oasis's home-manager module links the units and reloads the user manager. |
| `03-oasis-configs` | Covered: Oasis's home-manager module copies its `config/` where `~/.config/<name>` is missing. |
| `04-git` | `gh` is in the system. `[user]` is now in `home/.config/git/config`. `gh auth setup-git` needs a login: run it once by hand. |
| `05-kitty` | Kitty is in the system. The default terminal (`~/.config/xdg-terminals.list`) is user state: `oasis-install-terminal kitty` once on a new Mac. |
| `06-mise-tools` | Mostly obsolete: node, codex, pi, claude and chezmoi come from nixpkgs (host configs). `mise` in `~/.local/bin` and its config stay for the tools it still runs. |
| `08-vite-plus` | Not Nix: a generic build in `~/.vite-plus` (runs through nix-ld). The `.bashrc` line stays. Install by hand on a new Mac. |
| `10-keyd` | Covered: `services.keyd` in `nixosModules.oasis`, both Macs. |
| `11-apple-media-keys` | Covered on oasis (`boot.extraModprobeConfig`). **Was missing on asahi** (fnmode=3): added to `nix/hosts/asahi-test`. |
| `15-bitwarden` | `rbw` is in the system (patched, for Safe). The desktop app is a user Flatpak (state): `flatpak install --user flathub com.bitwarden.desktop`. |
| `16-obsidian` | Flatpak is on, both hosts. The app is a user Flatpak (state); `home/.local/bin/obsidian` starts it. |
| `17-syncthing` | Package and user unit in the system. **The enable was a link in the home**: now `wantedBy default.target` in `nixosModules.oasis`. |
| `18-chromium-google-account` | User state (`~/.config/chromium-flags.conf`): `oasis-install-chromium-google-account` once on a new Mac. |
| `19-tailscale` | Covered: `services.tailscale` on both hosts. **The operator was only state**: `services.tailscale.extraSetFlags = [ "--operator=ali" ]` added to both hosts. |
| `20-journal-retention` | Covered on oasis. **Was missing on asahi**: added to `nix/hosts/asahi-test`. |
| `30-oasis-apps` | Covered: `oasis-release ship` runs `tools/apps-install`; the built parts are Nix packages. |
| `31-voxtype` | Covered: voxtype (patched, with the OSD) is in the system; Oasis's drop-in runs the dictation. Open: the base `~/.config/systemd/user/voxtype.service` is a file from Arch (see below). The models are user data. |
| `32-airpods` | Covered: airpodsd is a Nix package with a drop-in. Open: the base `~/.local/share/systemd/user/airpods.service` is a file from Arch (see below). |
| `33-agent-skills` | **Was missing**: Oasis's home-manager module now runs `oasis-agent-skills` at each activation. |

Open on NixOS: two base user units are still files that Arch made in the
home: `voxtype.service` (`voxtype setup systemd`) and `airpods.service`
(`airpods/setup`). Both Macs have them, so nothing breaks now, but a new Mac
would not. The fix belongs in Oasis (`session/systemd/`, which its module
links), with a test in a nested session.

### What the first switch does

On each Mac, the first `oasis-release ship` with this module:

1. Stops at once if `~/code/dotfiles/home` is not there (nothing changes).
2. Moves each file that chezmoi wrote, and the old `CLAUDE.md` and
   `AGENTS.md` links, to `<file>.before-nixos`
   (`home-manager.backupFileExtension`), and puts the link in its place. If a
   `<file>.before-nixos` is there already, home-manager stops; move that old
   backup away first.
3. Leaves every kind-3 file alone.

To check: `readlink -f ~/.bashrc` is `~/code/dotfiles/home/.bashrc`, and
`find ~ -name '*.before-nixos' -newer ~/code/dotfiles/flake.nix` lists the
files that were moved.

To undo: `oasis-release rollback` (the system generation before; home-manager
puts back the links of that generation, which had none of these files), then
for each backup `mv <file>.before-nixos <file>`.

### Retire chezmoi

Nothing runs chezmoi now: `oasis-sync` pulls `~/code/dotfiles` instead.
After both Macs run with the module:

1. Keep `~/.local/share/chezmoi` until both Macs are checked, then put it in
   the Trash (`gio trash ~/.local/share/chezmoi`); it is a clone of this
   repository, with nothing that is not pushed.
2. `~/.config/chezmoi/` and `~/.cache/chezmoi/` can go too.
3. The chezmoi package can stay installed. If it runs by mistake, the
   `.chezmoiignore` here makes it write nothing.
4. `dots.aliabbas.dev` served `bootstrap/start.sh` from `main`. With no
   `bootstrap/` the Worker has no Oasis script to serve (it gives HTTP 503);
   retire the Worker (`~/code/dotfiles-bootstrap`) when convenient.

## Agent safety

On 2026-10-19 an agent ran `rm -rf $T/*` in a new shell where `T` was empty,
and deleted the home directory. These guard every coding agent:

- **`set -u` before every command:** pi's `shellCommandPrefix`
  (`~/.pi/agent/settings.json`, which Pico's agents also use; set by
  `seed/pi-settings.jq`). An unset variable stops the command before it runs.
- **An `rm` guard first on agents' `PATH`** (`~/.local/share/agent-guard/bin/rm`):
  it refuses `/`, top-level directories, `$HOME` and what is directly in it,
  the directories directly in `~/.config`, `~/.local/share`, `~/.local/state`
  and `~/code`, and git repositories. Tests: `tests/test_agent_guard.py`.
  It is a link into this checkout: without the checkout, agents get the plain
  `rm`. The activation stops if the checkout is missing for this reason too.
- **One set of agent rules** in `~/.pi/agent/AGENTS.md`, linked as
  `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`.

## Security boundary

This is a public, allowlisted repository. It excludes browser profiles and
preferences, OAuth-bearing Chromium flags, GitHub CLI auth, password stores,
Pi auth and sessions, Syncthing identities and configuration, SSH keys,
cookies, caches, logs, session state, generated theme files and backups. Do
not bulk-add `$HOME` or `~/.config`. `tools/check-public.py` checks the tree
for credentials and forbidden paths.

This repository is not a backup. Documents, code and app data need their own
backups.

## License

Original work in this repository is available under the [MIT License](LICENSE).
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for code derived from
Omarchy.
