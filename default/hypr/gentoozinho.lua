-- gentoozinho Hyprland defaults: helpers, defaults in order, then the theme.
require("default.hypr.gz")

require("default.hypr.autostart")
require("default.hypr.bindings.media")
require("default.hypr.bindings.clipboard")
require("default.hypr.bindings.tiling")
require("default.hypr.bindings.utilities")
require("default.hypr.envs")
require("default.hypr.looknfeel")
require("default.hypr.input")
require("default.hypr.windows")

-- Rendered by gentoozinho-theme-set; absent until a theme is set.
gz.require_optional("gentoozinho.current.theme.hyprland")
