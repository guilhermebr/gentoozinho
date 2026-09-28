-- Remove 1px border around hyprshot screenshots
hl.layer_rule({ name = "hyprshot-selection-no-anim", match = { namespace = "selection" }, no_anim = true })
