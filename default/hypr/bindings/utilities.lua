-- Adapted from Omarchy v3.8.4 (MIT)
-- Launchers
gz.bind("SUPER + RETURN", "Terminal", "gentoozinho-launch-terminal")
gz.bind("SUPER + SPACE", "Launch apps", "gentoozinho-launch-walker")
gz.bind("SUPER + CTRL + E", "Emoji picker", "gentoozinho-launch-walker -m emojis")
gz.bind("SUPER + B", "Browser", "gentoozinho-launch-browser")
gz.bind("SUPER + F", "File manager", "nautilus --new-window")
gz.bind("SUPER + K", "Show key bindings", "gentoozinho-menu-keybindings")

-- Aesthetics
gz.bind("SUPER + SHIFT + SPACE", "Toggle top bar", "gentoozinho-toggle-waybar")
gz.bind("SUPER + CTRL + SPACE", "Next background", "gentoozinho-theme-bg-next")
gz.bind("SUPER + SHIFT + CTRL + SPACE", "Next theme", "gentoozinho-theme-next")

-- Notifications (xkbcommon names the comma keysym "comma")
gz.bind("SUPER + comma", "Dismiss last notification", "makoctl dismiss")
gz.bind("SUPER + SHIFT + comma", "Dismiss all notifications", "makoctl dismiss --all")
gz.bind("SUPER + CTRL + comma", "Toggle silencing notifications", "gentoozinho-toggle-notification-silencing")

-- Toggles
gz.bind("SUPER + CTRL + I", "Toggle locking on idle", "gentoozinho-toggle-idle")

-- Captures
gz.bind("PRINT", "Screenshot region", "gentoozinho-capture-screenshot region")
gz.bind("SHIFT + PRINT", "Screenshot window", "gentoozinho-capture-screenshot window")
gz.bind("CTRL + PRINT", "Screenshot output", "gentoozinho-capture-screenshot output")
gz.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")

-- System
gz.bind("SUPER + CTRL + L", "Lock system", "gentoozinho-system-lock")
gz.bind("SUPER + CTRL + T", "Activity", "gentoozinho-launch-terminal -e btop")
-- A power menu comes in a later phase; until then shut down from a terminal.
