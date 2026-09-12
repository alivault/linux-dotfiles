-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Unified Launcher root.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Unified Launcher", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Keybindings are searchable from the unified SUPER + SPACE menu.
hl.unbind("SUPER + K")

-- Signal the already-running Unified Launcher without launching an IPC client.
-- Previously ran the stock `omarchy-menu toggle` process chain.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Unified Launcher", hl.dsp.global("ali.unified-launcher:toggle"))

-- Keep clipboard history inside the unified Omarchy menu.
-- Previously opened the standalone omarchy.clipboard overlay.
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "Clipboard manager", "omarchy menu summon clipboard")

-- Open clipboard history globally instead of passing CTRL+SPACE to apps.
o.bind("CTRL + SPACE", "Clipboard manager", "omarchy menu toggle clipboard")

-- Toggle back to the most recently used workspace.
-- Previously switched to the next workspace.
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))

-- Use bracket keys for sequential workspace navigation.
-- SUPER + SHIFT + TAB previously switched to the previous workspace.
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + SHIFT + bracketleft", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + SHIFT + bracketright", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))

-- Use the preloaded emoji grid in Unified Launcher instead of opening a second shell overlay.
hl.unbind("SUPER + CTRL + E")
o.bind("SUPER + CTRL + E", "Emojis", "omarchy menu toggle emoji")

-- Hold SUPER while using the display-brightness keys to adjust the keyboard backlight.
o.bind("SUPER + XF86MonBrightnessUp", "Keyboard brightness up", "omarchy-brightness-keyboard up", { locked = true, repeating = true })
o.bind("SUPER + XF86MonBrightnessDown", "Keyboard brightness down", "omarchy-brightness-keyboard down", { locked = true, repeating = true })

-- App identity shortcuts focus an existing window instead of opening another.
-- Action shortcuts (private browser, file manager at cwd, new email/post) and
-- terminal/TUI shortcuts intentionally retain their open-new-instance behavior.
-- Multiplexer terminals are the exception: focus the terminal already hosting
-- their client process, or launch one when no such window exists.
hl.unbind("SUPER + ALT + RETURN")
o.bind("SUPER + ALT + RETURN", "Tmux", "omarchy-launch-or-focus-process tmux omarchy-launch-terminal-tmux")

hl.unbind("SUPER + CTRL + RETURN")
o.bind("SUPER + CTRL + RETURN", "Herdr", "omarchy-launch-or-focus-process herdr omarchy-launch-terminal-herdr")

hl.unbind("SUPER + SHIFT + RETURN")
o.bind("SUPER + SHIFT + RETURN", "Browser", "omarchy-launch-or-focus 'chromium' 'omarchy-launch-browser'")

hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Browser", "omarchy-launch-or-focus 'chromium' 'omarchy-launch-browser'")

hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + SHIFT + F", "File manager", "omarchy-launch-or-focus 'org\\.gnome\\.Nautilus|nautilus' 'omarchy-launch-nautilus'")

-- The AppImage reports md.obsidian.Obsidian, not the stock ^obsidian$ class.
hl.unbind("SUPER + SHIFT + O")
o.bind("SUPER + SHIFT + O", "Obsidian", { launch = "obsidian", focus = "md\\.obsidian\\.Obsidian" })

hl.unbind("SUPER + SHIFT + SLASH")
o.bind("SUPER + SHIFT + SLASH", "Passwords", "omarchy-launch-or-focus '1Password' 'omarchy-launch-1password'")

-- Ordinary web-app shortcuts represent app identities, so focus them too.
-- Compose/action shortcuts remain untouched and continue opening new windows.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "ChatGPT", { webapp = "https://chatgpt.com", focus = true })

hl.unbind("SUPER + SHIFT + ALT + A")
o.bind("SUPER + SHIFT + ALT + A", "Grok", { webapp = "https://grok.com", focus = true })

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://app.hey.com/calendar/weeks/", focus = true })

hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Email", "omarchy-launch-or-focus-webapp 'HEY|Email' 'https://app.hey.com'")

hl.unbind("SUPER + SHIFT + Y")
o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/", focus = true })

hl.unbind("SUPER + SHIFT + X")
o.bind("SUPER + SHIFT + X", "X", "omarchy-launch-or-focus-webapp 'X$|/ X' 'https://x.com/'")

-- cliamp is a terminal app, so each invocation gets a new terminal window.
hl.unbind("SUPER + SHIFT + ALT + M")
o.bind("SUPER + SHIFT + ALT + M", "Music TUI", { tui = "cliamp" })
