-- Adapted from Omarchy v3.8.4 (MIT)
-- Floating windows
gz.window({ tag = "floating-window" }, { float = true })
gz.window({ tag = "floating-window" }, { center = true })
gz.window({ tag = "floating-window" }, { size = { 875, 600 } })
gz.window("(org.gentoozinho.bluetui|org.gentoozinho.impala|org.gentoozinho.wiremix|org.gentoozinho.btop|org.gentoozinho.terminal|org.gentoozinho.bash|org.codeberg.dnkl.foot|org.gnome.NautilusPreviewer|org.gnome.Evince|TUI.float|imv|mpv)", { tag = "+floating-window" })
gz.window({ class = "(xdg-desktop-portal-gtk|sublime_text|DesktopEditors|org.gnome.Nautilus)", title = "^(Open.*Files?|Open [F|f]older.*|Save.*Files?|Save.*As|Save|All Files|.*wants to [open|save].*|[C|c]hoose.*)" }, { tag = "+floating-window" })
gz.window("org.gnome.Calculator", { float = true })

-- No transparency on media windows
gz.window("^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$", { tag = "-default-opacity" })
gz.window("^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv|org.gnome.NautilusPreviewer)$", { opacity = "1 1" })

-- Popped window rounding
gz.window({ tag = "pop" }, { rounding = 8 })

-- Prevent idle while open
gz.window({ tag = "noidle" }, { idle_inhibit = "always" })
