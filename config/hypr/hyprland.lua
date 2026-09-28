-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/
dofile((os.getenv("GENTOOZINHO_PATH") or "/usr/share/gentoozinho") .. "/default/hypr/bootstrap.lua")

-- gentoozinho defaults (do not edit; they update with the package)
require("default.hypr.gentoozinho")

-- Your overrides, loaded last so they win
gz.require_optional("hypr.monitors")
gz.require_optional("hypr.input")
gz.require_optional("hypr.bindings")
gz.require_optional("hypr.looknfeel")
gz.require_optional("hypr.autostart")
