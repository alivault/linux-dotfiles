# Niri Pi Notifications

Local Herdr plugin, retaining its original `local.omarchy-agent-notify` ID.
Requires Python 3, Bash, jq, flock, ss, notify-send, Niri and Kitty.
No Pi extension changes or Kitty remote control are needed.

Pi `done`/`blocked` transitions produce actionable desktop notifications after
one second. `working` → `idle` also notifies when Kitty is not focused. Duplicate
states and the currently visible agent are suppressed. Click the notification
body to select the original Herdr pane and raise its attached Kitty window.
The helper waits at most 24 hours for a click; older notifications are inert.

Session routing uses HERDR_SOCKET_PATH, live Unix socket peers and process
ancestry, not inherited KITTY_PID. It resolves the attached client again on click,
so reattaching Herdr in a new Kitty process works. Replaced/closed agents are not
focused. If multiple Niri windows share one Kitty PID, routing deliberately fails
rather than guessing. With multiple attached clients, prefer the focused or most
recently focused matching Kitty window. Remote clients are not supported.

Herdr's `[ui.toast] delivery = "off"` avoids duplicate terminal notifications;
this does not disable plugin notifications or change sound settings.

Tests: `python3 test_notifications.py`
Window routing check: `./find-herdr-window.sh` (inside the target Herdr session).
Hook logs: `herdr plugin log list --plugin local.omarchy-agent-notify --limit 10`
Click-worker errors: `desktop-notify.log` under HERDR_PLUGIN_STATE_DIR.

Disable: `herdr plugin disable local.omarchy-agent-notify`, restore toast delivery
to `"terminal"` in `~/.config/herdr/config.toml`, then `herdr server reload-config`.
