local active_border_color = { colors = { "rgba(f0f2f3ee)", "rgba(d9dcdeee)" }, angle = 45 }
local inactive_border_color = "rgb(1e1e1e)"

hl.config({
  general = {
    border_size = 2,
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },
  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
    groupbar = {
      blur = true,
      rounding = 8,
      rounding_power = 3,
      gradient_rounding = 8,
      gradient_rounding_power = 3,
      col = {
        active = "rgba(101315ff)",
        inactive = "rgba(101315cc)",
        locked_active = "rgba(101315ff)",
        locked_inactive = "rgba(101315cc)",
      },
    },
  },
  decoration = {
    rounding = 6,
    rounding_power = 3,
    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      noise = 0.02,
      contrast = 0.90,
      brightness = 0.82,
      vibrancy = 0.06,
      vibrancy_darkness = 0.72,
      ignore_opacity = true,
    },
  },
})

-- Omarchy's transparency toggle changes a window's `opaque` property. These
-- opacity values become visible when translucency is enabled; toggling it off
-- still forces the focused window fully opaque. Keep active and fullscreen
-- windows opaque while making every inactive window 80% opaque.
o.window(".*", { opacity = "1.0 override 0.80 override 1.0 override" })
