# Niri + Noctalia alongside Omarchy

Vicinae handles the launcher (Super+Space and bar button) and autostarts in Niri.
Vicinae also handles clipboard history and emoji; Noctalia handles the shell.

Installed 2026-09-07. Niri is now the default boot autologin session.
Hyprland/Omarchy remains installed and selectable at login.
Local override: /etc/sddm.conf.d/zzzz-local-default-session.conf.
Remove that override to restore Omarchy boot autologin.
Save your work, log out, choose Niri in SDDM's Session menu, and log in.
The local SDDM theme is Tokyo Minimal: dark background, compact login form,
and session selector. The underlying Maldives override remains as a fallback.
Theme source: ~/.local/share/sddm/themes/tokyo-minimal/
Installed copy: /usr/share/sddm/themes/tokyo-minimal/
Override: /etc/sddm.conf.d/zzz-local-minimal-theme.conf
The theme passed an offscreen SDDM load test; real login still needs testing.

## Shortcuts (Mod = Super / Command key)
- Mod+Return: configured terminal (currently Kitty)
- Mod+Space: Vicinae launcher
- Mod+D: toggle Noctalia dark/light theme (shared app themes unchanged)
- Mod+E: launch Strata (no focus-existing wrapper)
- Mod+B: Helium; Mod+Shift+B: private Chromium browser
- Mod+Shift+O: Obsidian
- Mod+Alt+Return: tmux; Mod+Ctrl+Return: Herdr terminal
- Ctrl+Space: Vicinae clipboard history (reserved globally, not passed to apps)
- Mod+Ctrl+E: Vicinae emoji picker
- Mod+S: Noctalia control center
- Mod+Comma: Noctalia settings
- Mod+Shift+Comma: notifications
- Mod+Ctrl+Comma: toggle Do Not Disturb
- Mod+Q: close window
- Mod+arrows: focus windows
- Mod+Ctrl+arrows: move windows/columns
- Mod+PageUp/PageDown: change workspace
- Mod+Shift+PageUp/PageDown: reorder the entire workspace up/down
- Mod+O: overview
- Mod+R: cycle column width
- Mod+F: maximize column; Mod+Shift+F: fullscreen
- Mod+V: toggle floating
- Mod+Shift+S: screenshot
- Mod+Alt+L: Noctalia lock
- Mod+Ctrl+Alt+L: fallback swaylock if Noctalia is unavailable
- Mod+Shift+/: shortcut help
- Mod+Shift+E: logout confirmation

Noctalia owns the bar, notifications, wallpaper, authentication prompts, and lock.
The Omarchy animated-text screensaver starts after 150 seconds idle on the
focused output, using the same branding and ttfx effects in fullscreen Kitty.
Activity dismisses it; locking stops it. Noctalia owns the idle/resume triggers.
Adaptation: ~/.config/niri/screensaver.sh and the niri-screensaver.service user unit.
Manual preview: `systemctl --user start niri-screensaver.service` (press a key to exit).
Stop manually: `systemctl --user stop niri-screensaver.service`.
Idle locking matches Omarchy at 5 minutes, plus before suspend. While locked,
the display turns off after 5 seconds of inactivity and wakes on input.
Test manual locking,
suspend/resume, display scaling, and screen sharing in the actual Niri session.
Configuration was validated with `niri validate` and `noctalia config validate`;
the new Noctalia session is not live-tested yet.

## Files
- ~/.config/niri/config.kdl: compositor and session startup
- ~/.config/noctalia/config.toml: Tokyo Night shell, rounded shell styling,
  local clock + Bergen clock, system controls; no agent widget
- ~/.config/vicinae/settings.json: Tokyo Night launcher
- ~/.config/niri/waybar.json, waybar.css, mako.conf, bar-status.py and
  power-menu.sh: unused alternate-shell configuration; not started
- ~/.config/systemd/user/omarchy-sleep-lock.service.d/niri.conf:
  skips the Omarchy shell lock monitor in Niri (Noctalia replaces it)
- /etc/sddm.conf.d/zz-local-session-chooser.conf: login theme override

The package supplies Niri's login entry and desktop portal preferences.
Xwayland-satellite is automatically managed by this version of Niri.
No Omarchy package files were modified. Noctalia's application-theme templates
are disabled so it does not rewrite shared terminal/GTK/application settings.
Niri retains its default column-width presets; windows use square
corners with clipping and prefer-no-csd. Chromium gestures were not
ported. App shortcuts launch normally; apps themselves may reuse existing windows.
Weather is not configured yet because no saved Omarchy weather location was found.
Custom Niri settings do not automatically follow Omarchy themes or shortcuts.
Updates can still affect shared components.

## Installation and updates
Noctalia comes from the official repository and updates with system packages.
Vicinae v0.28.1 is the official ARM64 AppImage release installed under ~/.local
using the reviewed upstream installer, after verifying its GitHub SHA256 digest.
Its AUR binary package is x86-only. Vicinae therefore needs separate updates via
the official installer with `--prefix ~/.local` (review before running).
Vicinae input-server privileges are deliberately not granted: history/emoji copy
works, automatic paste/snippet injection is disabled. Telemetry is disabled.
Noctalia and Vicinae launch through Niri startup.
No globally enabled shell services.

## Return to Omarchy
Log out with Mod+Shift+E, select Omarchy, and log in. Reboot autologins
to Niri. To return to Maldives, remove the minimal-theme override:
`sudo rm /etc/sddm.conf.d/zzz-local-minimal-theme.conf`.
To restore Omarchy's original login theme, also remove
`/etc/sddm.conf.d/zz-local-session-chooser.conf`.
Do not restart SDDM with unsaved work: that terminates the desktop session.
