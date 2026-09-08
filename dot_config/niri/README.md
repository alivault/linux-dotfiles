# Niri + Noctalia

Niri is the compositor; Noctalia provides the bar, notifications, wallpaper,
authentication prompts, idle handling and session lock. Vicinae provides the
launcher, clipboard history and emoji picker.

## Login and locking

greetd launches Noctalia Greeter. This laptop currently auto-logs into Niri on
boot; logout returns to the greeter. Save work before logging out. Do not
restart greetd while working: doing so can terminate the desktop session.

- Super+Alt+L: lock through Noctalia
- Super+Ctrl+Alt+L: fallback swaylock
- Super+Comma: Noctalia settings
- Super+Space: Vicinae launcher
- Super+S: control center

See `config.kdl` for the complete, authoritative shortcut list.

## Idle behavior

The animated-text screensaver starts after 150 seconds idle. Activity dismisses
it; locking stops it. The session locks after five minutes and before suspend.
While locked, display and keyboard backlight turn off after five seconds idle.
Activity restores them. Automatic suspend is not enabled.

Preview the screensaver with `systemctl --user start niri-screensaver.service`;
stop it with `systemctl --user stop niri-screensaver.service`.

The compact lock screen shows a static name above a password field. Its layout
is in `~/.config/noctalia/95-lockscreen.toml`. Preview without locking using
`noctalia msg lockscreen-widgets-edit`.

## Configuration and updates

- `~/.config/niri/config.kdl`: compositor and session startup
- `~/.config/noctalia/*.toml`: shell, idle and lock-screen configuration
- `~/.config/vicinae/settings.json`: launcher preferences
- `~/.config/niri/screensaver.sh`: screensaver process management
- `~/.config/systemd/user/niri-screensaver.service`: screensaver unit

Noctalia application-theme templates are disabled so shared application
settings are not rewritten. Xwayland-satellite is managed by Niri.

Validate with `niri validate` and `noctalia config validate`. For reviewed
installation and update procedures, see `bootstrap/README.md` in the chezmoi
source tree. Third-party credits are in `THIRD_PARTY_NOTICES.md` there.
