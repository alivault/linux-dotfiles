# Standalone desktop release

The working laptop completed the live Omarchy retirement and reboot tests.
The source tree is now a standalone profile; this document supersedes the old
incremental migration notes, which remain in the local migration archive.

## Candidate changes

- Retired Omarchy/Hyprland/SDDM source and unreachable setup code removed from
  the candidate tree. The pre-existing dirty shell configuration was archived,
  not discarded. No personal application data or credentials were deleted.
- Explicit clean-machine pipeline, greeter build/login configuration,
  Bitwarden, keyd, model, editor and Pi-package setup added.
- Personal wallpaper excluded from publication; existing local JPEG still used.
  Fresh machines get original generated artwork; required third-party notices
  and the Neovim Apache license are retained.
- Worker project: `~/code/dotfiles-bootstrap`, serving `dots.aliabbas.dev`.
  The Worker checks both the immutable commit and bootstrap content checksum.
  Its release guard prevents deployment without a published, checksum-matching pin.

During local CLI-help validation, tool maintenance pruned the old cached Pi
0.85.0 and Codex 0.153.2 installations. The active 0.85.1 / 0.153.4 pins and their
settings/data were unchanged; no pacman removal transaction was run in this phase.

## Validate before commit

```sh
bash bootstrap/check-source.sh
bash bootstrap/doctor.sh
git diff --check
git status --short                # includes new files not shown by git diff
# In the separate Worker checkout:
npm run check                    # includes dry run; no deployment
```

The source check runs offline Python safety tests, public-path/credential
heuristics and a disposable-home chezmoi apply. Niri/Noctalia validators run when
installed. It does not provision the live system or establish a fresh VM boot.
Review the entire candidate tree manually; automated secret checks are not proof
that every possible credential format or old Git history is safe.

Current validation: 22 offline Python tests and five Worker tests pass; isolated
chezmoi rendering, Niri/Noctalia validation, ShellCheck 0.11.0, Neovim Lua parsing,
an isolated tmux server, live doctor and both repositories' whitespace checks
pass. The current 109 distinct manifest packages were checked against the official
ARM repository databases. The Worker dry run passes and its deployment guard
rejects unset release placeholders.

After explicit approval, Docker, Buildx, Compose, lazydocker, containerd and runc
were removed: there were no containers, volumes, Compose projects or build cache,
only two migration-test images. Cached data and QEMU were preserved. Docker's
launcher, daemon override, bridge DNS listener and unused firewall helper were
retired with backups. The default package manifest now contains 109 packages.
Saved Docker-only UFW blocks and two Docker DNS allowances were also backed up
and removed; their replacements passed iptables restore dry-run validation.
The active firewall was not reloaded: reboot to clear dormant Docker chains and
the unused runtime bridge. Other firewall rules, cached images and QEMU remain.

## Publication and remaining checks

Commit, push and deployment were authorized on 2026-09-08. Publish the reviewed
dotfiles commit before pinning its exact ref and bootstrap SHA256 in the Worker.
The Worker's release guard checks the public source before deployment; its
`wrangler.jsonc` records the immutable release being served.

The native iWeather plugin, World Clock, native Tailscale tray and desktop
appearance changes are included. Personal weather settings/cache remain local.

Keep real screen-sharing/printing and a fresh-machine boot smoke test on the
release checklist; the existing laptop's successful migration is not a
substitute for those tests. Do not run the hosted installer on the migrated
laptop merely to test publication: download and inspect it instead.
