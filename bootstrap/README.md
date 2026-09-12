# Omarchy + chezmoi setup

Start with a working, updated **Omarchy 4** installation. On Apple Silicon, use
the supported Asahi Omarchy port first. This bootstrap only configures an
existing Omarchy system; it does not partition, install a desktop/login manager,
replace boot files, or reboot.

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
bash bootstrap/doctor.sh
```

Provisioning installs Kitty, mise tools, pinned Vite+, keyd, Bitwarden,
Obsidian, Syncthing, Chromium account support and Tailscale. It may request
`sudo` and start/reload keyd, Syncthing and Tailscale. Fish configuration is
retained but does not change your login shell; install Fish separately if wanted.

Sign into applications and Pi/Codex manually. Pair Syncthing devices/folders,
authenticate Tailscale, and choose the Obsidian vault yourself. No identities,
passwords, browser profiles or authentication stores are imported.

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
iWeather external, so it needs GitHub access. It does not provision the host.
These checks are not a substitute for a fresh-machine test or physical
lock/unlock, suspend, capture and hardware checks.
