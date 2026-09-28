-- Adapted from Omarchy v3.8.4 (MIT)
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
gz.window(".*", { suppress_event = "maximize" })

-- Tag all windows for default opacity (apps can override with -default-opacity tag).
gz.window(".*", { tag = "+default-opacity" })

-- Fix some dragging issues with XWayland.
gz.window({ class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, { no_focus = true })

-- App-specific tweaks (may remove default-opacity tag).
require("default.hypr.apps")

-- Apply default opacity after apps have had a chance to opt out.
gz.window({ tag = "default-opacity" }, { opacity = "0.97 0.9" })
