-- Control your input devices
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
hl.config({
  input = {
    -- Several layouts, switched with Left Alt + Right Alt:
    -- kb_layout = "us,dk,eu",
    -- kb_options = "compose:caps,grp:alts_toggle",
    kb_options = "compose:caps",

    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,

    -- sensitivity = 0.35,
    -- accel_profile = "flat",

    touchpad = {
      -- natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
      -- disable_while_typing = false,
    },
  },
})

-- Scroll nicely in the terminal
gz.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })

-- Touchpad gestures for changing workspaces:
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
