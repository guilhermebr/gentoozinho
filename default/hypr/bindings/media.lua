-- Adapted from Omarchy v3.8.4 (MIT)
-- Laptop multimedia keys for volume and LCD brightness (with OSD)
local held = { locked = true, repeating = true }
local once = { locked = true }

gz.bind("XF86AudioRaiseVolume", "Volume up", "gentoozinho-swayosd-client --output-volume raise", held)
gz.bind("XF86AudioLowerVolume", "Volume down", "gentoozinho-swayosd-client --output-volume lower", held)
gz.bind("XF86AudioMute", "Mute", "gentoozinho-swayosd-client --output-volume mute-toggle", held)
gz.bind("XF86MonBrightnessUp", "Brightness up", "gentoozinho-brightness-display +5%", held)
gz.bind("XF86MonBrightnessDown", "Brightness down", "gentoozinho-brightness-display 5%-", held)
gz.bind("SHIFT + XF86MonBrightnessUp", "Brightness maximum", "gentoozinho-brightness-display 100%", held)
gz.bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", "gentoozinho-brightness-display 1%", held)

-- Precise 1% adjustments with Alt
gz.bind("ALT + XF86AudioRaiseVolume", "Volume up precise", "gentoozinho-swayosd-client --output-volume +1", held)
gz.bind("ALT + XF86AudioLowerVolume", "Volume down precise", "gentoozinho-swayosd-client --output-volume -1", held)
gz.bind("ALT + XF86MonBrightnessUp", "Brightness up precise", "gentoozinho-brightness-display +1%", held)
gz.bind("ALT + XF86MonBrightnessDown", "Brightness down precise", "gentoozinho-brightness-display 1%-", held)

-- Requires playerctl
gz.bind("XF86AudioNext", "Next track", "gentoozinho-swayosd-client --playerctl next", once)
gz.bind("XF86AudioPause", "Pause", "gentoozinho-swayosd-client --playerctl play-pause", once)
gz.bind("XF86AudioPlay", "Play", "gentoozinho-swayosd-client --playerctl play-pause", once)
gz.bind("XF86AudioPrev", "Previous track", "gentoozinho-swayosd-client --playerctl previous", once)
