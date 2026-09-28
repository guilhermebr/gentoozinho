-- Adapted from Omarchy v3.8.4 (MIT)
-- Define terminal tag to style them uniformly
-- Class matches are full-string, so spell out foot's reverse-DNS app-id too;
-- universal copy/paste (bindings/clipboard.lua) relies on this tag.
gz.window("(Alacritty|kitty|com.mitchellh.ghostty|foot|org\\.codeberg\\.dnkl\\.foot|wezterm|org\\.gentoozinho\\..*|TUI\\..*)", { tag = "+terminal" })
gz.window({ tag = "terminal" }, { tag = "-default-opacity" })
gz.window({ tag = "terminal" }, { opacity = "0.97 0.9" })
