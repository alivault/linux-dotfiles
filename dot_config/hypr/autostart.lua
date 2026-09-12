-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Load the locally built, ABI-checked plugin, then apply its input.lua settings.
-- Rebuild the plugin against matching headers after incompatible Hyprland updates.
o.exec_on_start('hyprctl plugin load "$HOME/.local/lib/hyprland/hypr-kinetic-scroll-checked.so" && hyprctl reload config-only')
