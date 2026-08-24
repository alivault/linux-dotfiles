-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- Use macOS-style natural scrolling on the touchpad.
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
    },
  },
})

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Agent terminals use a dedicated app-id, so match Kitty's terminal speed.
o.window("org\\.omarchy\\.agent", { scroll_touchpad = 1.5 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })

-- Use three-finger vertical swipes to manage tabs in Chromium. Sending
-- explicit key-down/key-up events avoids changing the trackpad or libinput
-- configuration and prevents a synthetic modifier from getting stuck.
local function send_shortcut_once(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

local function chromium_shortcut(mods, key)
  return function()
    local window = hl.get_active_window()
    if window and (window.class or ""):lower() == "chromium" then
      send_shortcut_once(mods, key)
    end
  end
end

hl.gesture({ fingers = 3, direction = "down", action = chromium_shortcut("CTRL", "W") })
hl.gesture({ fingers = 3, direction = "up", action = chromium_shortcut("CTRL", "T") })
hl.gesture({ fingers = 3, direction = "left", action = chromium_shortcut("CTRL SHIFT", "TAB") })
hl.gesture({ fingers = 3, direction = "right", action = chromium_shortcut("CTRL", "TAB") })

-- Swipe between workspaces with four fingers.
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Hyprland does not expose this Apple trackpad's smooth two-finger scrolling
-- as bindable wheel events. Use its native live pinch gesture for cursor zoom.
hl.gesture({
  fingers = 2,
  direction = "pinch",
  mods = "SUPER",
  action = "cursor_zoom",
  zoom_level = 1,
  mode = "live",
})

-- Keep the magnified view centered on the pointer as it moves.
hl.config({
  cursor = {
    zoom_rigid = true,
    zoom_detached_camera = false,
  },
})
