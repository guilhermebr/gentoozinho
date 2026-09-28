-- Adapted from Omarchy v3.8.4 (MIT)
-- Helpers for gentoozinho's Hyprland config. `o` is an alias so Omarchy
-- snippets work unchanged.
gz = gz or {}
o = gz

function gz.launch(cmd)
  return "uwsm-app -- " .. cmd
end

-- gz.require_optional(module): require only when the module exists on package.path.
function gz.require_optional(module)
  if package.searchpath(module, package.path) then
    return require(module)
  end
end

-- Omarchy's o.bind accepts more table forms than gentoozinho ships handlers for.
local omarchy_only = { "omarchy", "menu", "panel", "webapp", "tui", "audio", "brightness", "ipc", "focus" }

local function to_dispatcher(keys, dispatcher)
  if type(dispatcher) == "table" and dispatcher._dsp == nil then
    if dispatcher.launch then
      return hl.dsp.exec_cmd(gz.launch(dispatcher.launch))
    end
    for _, key in ipairs(omarchy_only) do
      if dispatcher[key] ~= nil then
        error(("gz.bind %q: Omarchy-only dispatcher { %s = ... }; use a command string or { launch = cmd }"):format(keys, key), 3)
      end
    end
  elseif type(dispatcher) == "string" then
    return hl.dsp.exec_cmd(dispatcher)
  end
  return dispatcher
end

-- gz.bind(keys, description, dispatcher, opts)
--   dispatcher: an hl.dsp value, a function, a command string, or { launch = "cmd" }.
function gz.bind(keys, description, dispatcher, opts)
  local o_ = {}
  for k, v in pairs(opts or {}) do o_[k] = v end
  if description then o_.description = description end
  return hl.bind(keys, to_dispatcher(keys, dispatcher), o_)
end

function gz.rebind(keys, description, dispatcher, opts)
  hl.unbind(keys)
  return gz.bind(keys, description, dispatcher, opts)
end

-- gz.window(match, rules): match is a class pattern or a match table.
function gz.window(match, rules)
  rules.match = rules.match or {}
  if type(match) == "string" then
    rules.match.class = match
  else
    for k, v in pairs(match) do rules.match[k] = v end
  end
  return hl.window_rule(rules)
end

function gz.exec_on_start(cmd)
  hl.on("hyprland.start", function() hl.exec_cmd(cmd) end)
end

function gz.launch_on_start(cmd)
  gz.exec_on_start(gz.launch(cmd))
end

return gz
