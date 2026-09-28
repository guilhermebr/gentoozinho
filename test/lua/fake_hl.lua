-- A recording stand-in for Hyprland's `hl` global. Every call is appended to
-- hl._calls as { fn = "name", args = {...} }; hl._config is the merged config.
local hl = { _calls = {}, _config = {}, _binds = {}, _handlers = {}, _window_rules = {}, _layer_rules = {}, _env = {} }

local function record(fn, ...)
  table.insert(hl._calls, { fn = fn, args = { ... } })
end

local function deep_merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deep_merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

function hl.config(t) record("config", t); deep_merge(hl._config, t) end
function hl.bind(keys, dispatcher, opts)
  record("bind", keys, dispatcher, opts)
  table.insert(hl._binds, { keys = keys, dispatcher = dispatcher, opts = opts or {} })
  return { set_enabled = function() end }
end
function hl.unbind(keys)
  record("unbind", keys)
  for i = #hl._binds, 1, -1 do
    if hl._binds[i].keys == keys then table.remove(hl._binds, i) end
  end
end
function hl.window_rule(spec) record("window_rule", spec); table.insert(hl._window_rules, spec); return {} end
function hl.layer_rule(spec) record("layer_rule", spec); table.insert(hl._layer_rules, spec); return {} end
function hl.env(k, v) record("env", k, v); hl._env[k] = v end
function hl.monitor(spec) record("monitor", spec) end
function hl.on(event, cb) record("on", event); hl._handlers[event] = hl._handlers[event] or {}; table.insert(hl._handlers[event], cb); return {} end
function hl.exec_cmd(cmd) record("exec_cmd", cmd) end
function hl.curve(name, spec) record("curve", name, spec) end
function hl.animation(spec) record("animation", spec) end
function hl.dispatch(d) record("dispatch", d) end
function hl.timer(cb, opts) record("timer", opts); return {} end
function hl.get_active_window() return nil end

-- Dispatchers: tagged tables so tests can inspect them.
local function dsp(name)
  return function(...) return { _dsp = name, args = { ... } } end
end
hl.dsp = {
  exec_cmd = dsp("exec_cmd"), focus = dsp("focus"), layout = dsp("layout"),
  send_key_state = dsp("send_key_state"),
  window = {
    close = dsp("window.close"), float = dsp("window.float"), fullscreen = dsp("window.fullscreen"),
    pseudo = dsp("window.pseudo"), move = dsp("window.move"), swap = dsp("window.swap"),
    resize = dsp("window.resize"), drag = dsp("window.drag"), cycle_next = dsp("window.cycle_next"),
    bring_to_top = dsp("window.bring_to_top"),
  },
  workspace = { toggle_special = dsp("workspace.toggle_special") },
}

-- Run every hyprland.start handler (tests call this to see what autostart execs).
function hl._start()
  for _, cb in ipairs(hl._handlers["hyprland.start"] or {}) do cb() end
end

-- Commands passed to exec_cmd, either directly or through a dispatcher bind.
function hl._exec_commands()
  local out = {}
  for _, c in ipairs(hl._calls) do
    if c.fn == "exec_cmd" then table.insert(out, c.args[1]) end
  end
  for _, b in ipairs(hl._binds) do
    if type(b.dispatcher) == "table" and b.dispatcher._dsp == "exec_cmd" then
      table.insert(out, b.dispatcher.args[1])
    end
  end
  return out
end

return hl
