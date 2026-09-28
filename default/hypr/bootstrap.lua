-- Adapted from Omarchy v3.8.4 (MIT)
-- Module path for gentoozinho's Hyprland Lua config: generated state, the
-- user's ~/.config, then the shipped defaults. Reloads drop cached modules so
-- `hyprctl reload` picks up edits.
local home = os.getenv("HOME")
local share = os.getenv("GENTOOZINHO_PATH") or "/usr/share/gentoozinho"

for module in pairs(package.loaded) do
  if module:match("^default%.") or module:match("^hypr%.") or module:match("^gentoozinho%.") then
    package.loaded[module] = nil
  end
end

package.path = home .. "/.local/state/?.lua;" .. home .. "/.config/?.lua;" .. share .. "/?.lua;" .. package.path
