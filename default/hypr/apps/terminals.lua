-- Adapted from Omarchy v3.8.4 (MIT)
-- Define terminal tag to style them uniformly
gz.window("(Alacritty|kitty|com.mitchellh.ghostty|foot)", { tag = "+terminal" })
gz.window({ tag = "terminal" }, { tag = "-default-opacity" })
gz.window({ tag = "terminal" }, { opacity = "0.97 0.9" })
