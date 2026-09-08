# Ali's Linux dotfiles

Personal **Arch Linux / Arch Linux ARM** desktop configuration and explicit setup
scripts, managed by [chezmoi](https://www.chezmoi.io/). The desktop uses **Niri**,
**Noctalia** and **Vicinae**, with **Kitty + Herdr + Pi** for coding.

Requires an **existing Arch installation**. Fresh-machine testing is incomplete.

## Install

Start with an updated Arch Linux or Arch Linux ARM system, networking, a normal
login user, and `git`, `curl` and `polkit` installed. Review the
[setup requirements](bootstrap/README.md) and [release notes](bootstrap/RELEASE.md).

```sh
curl -fsSL https://dots.aliabbas.dev -o /tmp/dotfiles-bootstrap.sh
less /tmp/dotfiles-bootstrap.sh
sh /tmp/dotfiles-bootstrap.sh
```

## Highlights

- Niri desktop with Noctalia, Tokyo Night, Vicinae launcher and a native
  [iWeather widget](dot_local/share/noctalia-local-plugins/iweather/README.md).
- Kitty, Herdr, Pi, LazyVim/Neovim, tmux and mise-managed development tools.
- Clickable agent notifications that return to the right Herdr pane and Kitty window.
- F9 toggle dictation.

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

## Configuration updates

Preview and apply your current chezmoi checkout without provisioning:

```sh
chezmoi diff
chezmoi apply --exclude scripts
```

## Further docs

- [Setup and recovery](bootstrap/README.md)
- [Release review](bootstrap/RELEASE.md) and [validation](.github/workflows/validate.yml)
- [License](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md)
