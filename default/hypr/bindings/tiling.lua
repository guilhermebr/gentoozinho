-- Adapted from Omarchy v3.8.4 (MIT)
gz.bind("SUPER + W", "Close window", hl.dsp.window.close())
gz.bind("CTRL + ALT + DELETE", "Close all windows", "gentoozinho-hyprland-window-close-all")

gz.bind("SUPER + J", "Toggle window split", hl.dsp.layout("togglesplit"))
gz.bind("SUPER + P", "Pseudo window", hl.dsp.window.pseudo())
gz.bind("SUPER + SHIFT + V", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))
gz.bind("SHIFT + F11", "Force full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
gz.bind("ALT + F11", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))

gz.bind("SUPER + LEFT", "Move focus left", hl.dsp.focus({ direction = "l" }))
gz.bind("SUPER + RIGHT", "Move focus right", hl.dsp.focus({ direction = "r" }))
gz.bind("SUPER + UP", "Move focus up", hl.dsp.focus({ direction = "u" }))
gz.bind("SUPER + DOWN", "Move focus down", hl.dsp.focus({ direction = "d" }))

for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  gz.bind("SUPER + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  gz.bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

gz.bind("SUPER + TAB", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
gz.bind("SUPER + SHIFT + TAB", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
gz.bind("SUPER + CTRL + TAB", "Former workspace", hl.dsp.focus({ workspace = "previous" }))

gz.bind("SUPER + SHIFT + LEFT", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
gz.bind("SUPER + SHIFT + RIGHT", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
gz.bind("SUPER + SHIFT + UP", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
gz.bind("SUPER + SHIFT + DOWN", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

gz.bind("ALT + TAB", "Cycle to next window", hl.dsp.window.cycle_next())
gz.bind("ALT + SHIFT + TAB", "Cycle to previous window", hl.dsp.window.cycle_next({ next = false }))
gz.bind("ALT + TAB", "Reveal active window on top", hl.dsp.window.bring_to_top())
gz.bind("ALT + SHIFT + TAB", "Reveal active window on top", hl.dsp.window.bring_to_top())

gz.bind("SUPER + code:20", "Expand window left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
gz.bind("SUPER + code:21", "Shrink window left", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
gz.bind("SUPER + SHIFT + code:20", "Shrink window up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
gz.bind("SUPER + SHIFT + code:21", "Expand window down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

gz.bind("SUPER + mouse_down", "Scroll active workspace forward", hl.dsp.focus({ workspace = "e+1" }))
gz.bind("SUPER + mouse_up", "Scroll active workspace backward", hl.dsp.focus({ workspace = "e-1" }))

gz.bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
gz.bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })
