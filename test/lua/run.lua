-- Minimal test runner: each test is a function; failures print and exit 1.
local repo = os.getenv("GENTOOZINHO_PATH")
local home = os.getenv("HOME")
package.path = repo .. "/test/lua/?.lua;" .. package.path

local tests, failures = {}, 0
local function test(name, fn) table.insert(tests, { name = name, fn = fn }) end
local function fresh_hl()
  package.loaded["fake_hl"] = nil
  _G.hl = require("fake_hl")
  for m in pairs(package.loaded) do
    if m:match("^default%.") or m:match("^hypr%.") or m:match("^gentoozinho%.") then package.loaded[m] = nil end
  end
  _G.gz, _G.o = nil, nil
  return _G.hl
end
local function load_user_config()
  dofile(repo .. "/config/hypr/hyprland.lua")
end
local function file_exists(p) local f = io.open(p, "r"); if f then f:close(); return true end; return false end
local function write(p, s) local f = assert(io.open(p, "w")); f:write(s); f:close() end
local function mkdir(p) os.execute("mkdir -p '" .. p .. "'") end

-- ---- tests -----------------------------------------------------------------

test("user config loads with defaults only (no theme, no user modules)", function()
  local hl = fresh_hl()
  os.execute("rm -rf '" .. home .. "/.config/gentoozinho' '" .. home .. "/.config/hypr'")
  load_user_config()
  assert(gz, "gz helper missing"); assert(o == gz, "o alias missing")
  assert(#hl._binds > 0, "no binds recorded")
end)

test("theme module is applied when present", function()
  local hl = fresh_hl()
  mkdir(home .. "/.config/gentoozinho/current/theme")
  write(home .. "/.config/gentoozinho/current/theme/hyprland.lua",
    'hl.config({ general = { col = { active_border = "rgb(7aa2f7)" } } })\n')
  load_user_config()
  assert(hl._config.general.col.active_border == "rgb(7aa2f7)", "theme border not applied")
end)

test("missing user modules are skipped; a broken one raises", function()
  local hl = fresh_hl()
  os.execute("rm -rf '" .. home .. "/.config/hypr'")
  load_user_config()
  mkdir(home .. "/.config/hypr")
  write(home .. "/.config/hypr/bindings.lua", "this is not lua\n")
  fresh_hl()
  local ok, err = pcall(load_user_config)
  assert(not ok and tostring(err):find("bindings"), "broken user module did not raise with its name")
  os.remove(home .. "/.config/hypr/bindings.lua")
end)

test("gz.bind wraps commands, keeps descriptions; gz.rebind replaces", function()
  local hl = fresh_hl()
  load_user_config()
  gz.bind("SUPER + F12", "Test cmd", "echo hi")
  local b = hl._binds[#hl._binds]
  assert(b.dispatcher._dsp == "exec_cmd" and b.dispatcher.args[1] == "echo hi", "command not wrapped")
  assert(b.opts.description == "Test cmd", "description lost")
  gz.bind("SUPER + F11", "Launch", { launch = "foo" })
  assert(hl._binds[#hl._binds].dispatcher.args[1] == "uwsm-app -- foo", "launch not wrapped")
  local before = #hl._binds
  gz.rebind("SUPER + F12", "Replaced", "echo bye")
  assert(#hl._binds == before, "rebind changed the bind count")
  assert(hl._binds[#hl._binds].dispatcher.args[1] == "echo bye", "rebind did not replace")
end)

test("every default bind has a description", function()
  local hl = fresh_hl()
  load_user_config()
  for _, b in ipairs(hl._binds) do
    assert(b.opts.description and #b.opts.description > 0, "bind without description: " .. b.keys)
  end
end)

test("every exec'd command starts with a gentoozinho script or a known program", function()
  local hl = fresh_hl()
  load_user_config()
  hl._start()
  local known = { nautilus = true, makoctl = true, hyprpicker = true, pkill = true, systemctl = true,
                  ["dbus-update-activation-environment"] = true, ["uwsm-app"] = true }
  for _, cmd in ipairs(hl._exec_commands()) do
    local first = cmd:match("^%S+")
    local ok = known[first] or (first:match("^gentoozinho%-") and file_exists(repo .. "/bin/" .. first))
    assert(ok, "unknown command in config: " .. cmd)
  end
end)

test("autostart launches the session daemons through uwsm-app", function()
  local hl = fresh_hl()
  load_user_config()
  hl._start()
  local seen = {}
  for _, cmd in ipairs(hl._exec_commands()) do seen[cmd] = true end
  for _, app in ipairs({ "hypridle", "mako", "waybar" }) do
    assert(seen["uwsm-app -- " .. app], "autostart missing " .. app)
  end
  local swaybg = false
  for cmd in pairs(seen) do if cmd:match("^uwsm%-app %-%- swaybg ") then swaybg = true end end
  assert(swaybg, "autostart missing swaybg")
end)

test("core bindings are present", function()
  local hl = fresh_hl()
  load_user_config()
  local by_keys = {}
  for _, b in ipairs(hl._binds) do by_keys[b.keys] = b end
  assert(by_keys["SUPER + RETURN"].dispatcher.args[1] == "gentoozinho-launch-terminal", "terminal bind")
  assert(by_keys["SUPER + SPACE"].dispatcher.args[1] == "gentoozinho-launch-walker", "launcher bind")
  assert(by_keys["SUPER + W"].dispatcher._dsp == "window.close", "close bind")
  assert(by_keys["SUPER + code:10"].dispatcher._dsp == "focus", "workspace 1 bind")
  assert(by_keys["SUPER + mouse:272"].opts.mouse == true, "drag bind is a mouse bind")
  assert(by_keys["XF86AudioRaiseVolume"].opts.locked and by_keys["XF86AudioRaiseVolume"].opts.repeating, "media bind opts")
end)

-- ---- run --------------------------------------------------------------------
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then print("ok   " .. t.name) else failures = failures + 1; print("FAIL " .. t.name .. "\n     " .. tostring(err)) end
end
print(string.format("%d tests, %d failures", #tests, failures))
os.exit(failures == 0 and 0 or 1)
