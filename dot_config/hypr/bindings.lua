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

-- Use the preloaded emoji grid in Unified Launcher instead of opening a second shell overlay.
hl.unbind("SUPER + CTRL + E")
o.bind("SUPER + CTRL + E", "Emojis", "omarchy menu toggle emoji")

-- Hold SUPER while using the display-brightness keys to adjust the keyboard backlight.
o.bind("SUPER + XF86MonBrightnessUp", "Keyboard brightness up", "omarchy-brightness-keyboard up", { locked = true, repeating = true })
o.bind("SUPER + XF86MonBrightnessDown", "Keyboard brightness down", "omarchy-brightness-keyboard down", { locked = true, repeating = true })
