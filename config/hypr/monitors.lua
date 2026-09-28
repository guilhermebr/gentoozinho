-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List monitors and their modes: hyprctl monitors

-- Retina-class 2x displays (13" 2.8K, 27" 5K, 32" 6K)
hl.env("GDK_SCALE", "2")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Straight 1x for 1080p/1440p displays or ultrawides:
-- hl.env("GDK_SCALE", "1")
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- A rotated secondary monitor (transform 1 = 90 degrees):
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
