-- Minimal Hyprland config for the SDDM Wayland greeter. SDDM starts the greeter
-- itself once the compositor is up; without layer-shell-qt it is a plain window.
hl.config({
  general = { gaps_in = 0, gaps_out = 0, border_size = 0 },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 },
  animations = { enabled = false },
})
hl.window_rule({ name = "sddm-greeter-fullscreen", match = { class = "^(sddm-greeter|sddm-greeter-qt6)$" }, fullscreen = true })
