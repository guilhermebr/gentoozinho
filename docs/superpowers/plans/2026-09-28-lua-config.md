# Hyprland Lua Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every hyprlang `.conf` in gentoozinho's Hyprland layer with Lua, so a session on Hyprland 0.56 shows no deprecation notice and survives 0.57; existing phase 2 installs migrate on the next installer run.

**Architecture:** `default/hypr/bootstrap.lua` sets `package.path`; `default/hypr/gz.lua` defines the `gz` helper table (alias `o`); `default/hypr/gentoozinho.lua` requires the defaults in order and the optional theme module; the user's `~/.config/hypr/hyprland.lua` bootstraps, requires the defaults, then `gz.require_optional`s five user modules. The theme engine renders `hyprland.lua` from a template. Lua unit tests run the real modules on the host against a recording fake `hl`.

**Tech Stack:** Lua 5.4 (host `lua5.4`; Hyprland embeds its own), Hyprland 0.56 `hl` API (`~/.cache/gentoozinho-src/hl.meta.lua` is the stub), bash, bats via docker.

**Spec:** `docs/superpowers/specs/2026-09-28-lua-config-design.md`

## Global Constraints

- Lua only. Every `default/hypr/**/*.conf`, `config/hypr/{hyprland,monitors,input,bindings,looknfeel,autostart}.conf`, `default/sddm/hyprland.conf` and `default/themed/hyprland.conf.tpl` is deleted in this work. `hyprlock.conf`, `hypridle.conf` and `hyprpaper` handling are untouched.
- Helper global is `gz`; `o = gz` is set once in `gz.lua`. Defaults use `gz.`; user templates show `gz.` in examples.
- Every default binding passes a description. Command strings passed to `gz.bind` are wrapped in `hl.dsp.exec_cmd`.
- API surface used (from the 0.56.2 stub): `hl.config`, `hl.bind(keys, dispatcher, opts)`, `hl.unbind`, `hl.window_rule`, `hl.layer_rule`, `hl.env`, `hl.monitor`, `hl.on`, `hl.exec_cmd`, `hl.curve`, `hl.animation`, `hl.dispatch`, `hl.timer`, `hl.get_active_window`, and `hl.dsp.{exec_cmd, focus, layout, send_key_state, window.{close, float, fullscreen, pseudo, move, swap, resize, drag, cycle_next, bring_to_top}, workspace.toggle_special}`. Nothing outside this list.
- Bind options are `{ description=, locked=, repeating=, mouse=, release= }`. Keys are `"SUPER + SHIFT + code:10"` style strings; `mouse_down`, `mouse_up`, `mouse:272`, `mouse:273` for the mouse.
- Ported content comes from the current `.conf` files in this repo (already Omarchy v3.8.4 adapted) and, for dispatcher idioms, Omarchy v4 (`/tmp/claude-…/scratchpad/omarchy` or `git clone --depth 1 https://github.com/basecamp/omarchy`), MIT. Keep the `# Adapted from Omarchy v3.8.4 (MIT)` header as a Lua comment.
- Tests: `test/lua.sh` (host Lua), `test/unit.sh` (bats), `test/lint.sh`; the smoke test is the end-to-end proof. Commit messages single line.
- Smoke VM: `~/.cache/gentoozinho-smoke`, SSH port 40222, boot flags as in the phase 2 plan Task 7 (`-vga virtio`), `GZ_SMOKE_SSH="ssh -p 40222 gentoo@127.0.0.1"`. It currently holds a phase 2 install with `.conf` files, which is the migration case.

## Review Focus

1. An existing user with only the old `.conf` files: the migration must move them aside and seed Lua; otherwise Hyprland keeps loading the `.conf` and the notice never goes away. Test in Task 4 (bats) and Task 5 (real VM).
2. No theme has been set yet (installer's user stage runs `refresh-config --init` before `theme-set`): `gentoozinho.lua` must load without the theme module. Test in Task 1.
3. A user module that does not exist must be skipped silently; one that exists with an error must surface it. Test in Task 1.
4. `code:` and `mouse:` keys and `{ mouse = true }` binds must be accepted by Hyprland, not just by the fake. Test in Task 5 with `--verify-config`.
5. `gentoozinho-menu-keybindings` relies on `has_description`; a bind without a description is a regression. Test in Task 3.

---

## File structure

```
default/hypr/bootstrap.lua, gz.lua, gentoozinho.lua
default/hypr/{autostart,envs,input,looknfeel,windows,apps}.lua
default/hypr/apps/{browser,hyprshot,system,terminals,walker}.lua
default/hypr/bindings/{tiling,media,clipboard,utilities}.lua
default/sddm/hyprland.lua
default/themed/hyprland.lua.tpl
config/hypr/{hyprland,monitors,input,bindings,looknfeel,autostart}.lua
bin/gentoozinho-refresh-config            (+ migration)
install/lib/user.sh                       (CompositorCommand .lua)
test/lua.sh, test/lua/fake_hl.lua, test/lua/run.lua
test/unit/{hypr,theme,scripts,user}.bats  (updated)
docs: README, docs/learning/02-desktop-session.md, spec section 7 pointer
```

---

### Task 1: Lua test harness, bootstrap, helpers and loader

**Files:**
- Create: `test/lua.sh`, `test/lua/fake_hl.lua`, `test/lua/run.lua`, `default/hypr/bootstrap.lua`, `default/hypr/gz.lua`, `default/hypr/gentoozinho.lua`, `config/hypr/hyprland.lua`

**Interfaces:**
- Produces: global `gz` with `bind`, `rebind`, `window`, `exec_on_start`, `launch`, `require_optional`; `hl` fake with `_calls` recording; `test/lua.sh` exit status.

- [ ] **Step 1: Write the fake hl and the test runner (the failing test)**

`test/lua/fake_hl.lua`:

```lua
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
```

`test/lua/run.lua`:

```lua
-- Minimal test runner: each test is a function; failures print and exit 1.
local repo = os.getenv("GENTOOZINHO_PATH")
local home = os.getenv("HOME")
package.path = repo .. "/test/lua/?.lua;" .. package.path

local tests, failures = {}, 0
local function test(name, fn) table.insert(tests, { name = name, fn = fn }) end
local function fresh_hl()
  package.loaded["fake_hl"] = nil
  _G.hl = require("fake_hl")
  -- forget every gentoozinho module so each test loads a clean tree
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
```

`test/lua.sh`:

```bash
#!/usr/bin/env bash
# Run the Lua config modules on the host against a fake `hl` (needs lua5.4).
set -euo pipefail
cd "$(dirname "$0")/.."
export GENTOOZINHO_PATH="$PWD"
HOME="$(mktemp -d)"; export HOME
trap 'rm -rf "$HOME"' EXIT
lua5.4 test/lua/run.lua
```

`chmod +x test/lua.sh`.

- [ ] **Step 2: Run it to verify it fails**

Run: `test/lua.sh`
Expected: every test FAILs (`config/hypr/hyprland.lua` missing or `dofile` error).

- [ ] **Step 3: Write bootstrap, gz and the loader**

`default/hypr/bootstrap.lua`:

```lua
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
```

`default/hypr/gz.lua`:

```lua
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

local function to_dispatcher(dispatcher)
  if type(dispatcher) == "table" and dispatcher.launch then
    return hl.dsp.exec_cmd(gz.launch(dispatcher.launch))
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
  return hl.bind(keys, to_dispatcher(dispatcher), o_)
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
```

`default/hypr/gentoozinho.lua`:

```lua
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
```

`config/hypr/hyprland.lua`: exactly the text in the spec section 4.

Until Tasks 2 and 3 exist, create the required default modules as one-line stubs (`-- filled in Task 2`) so the loader resolves; Tasks 2 and 3 replace them. Record this in the ledger.

- [ ] **Step 4: Run the Lua tests**

Run: `test/lua.sh`
Expected: "user config loads", "theme module", "missing user modules", "gz.bind" PASS; "every default bind has a description" passes vacuously; "core bindings" and "autostart" FAIL until Tasks 2 and 3.

- [ ] **Step 5: Lint and commit**

Run: `test/lint.sh` (covers `test/lua.sh`).

```bash
git add -A
git commit -m "Add Lua test harness, bootstrap, gz helpers and config loader"
```

---

### Task 2: Port defaults: envs, input, looknfeel, windows, apps, autostart

**Files:**
- Create: `default/hypr/{autostart,envs,input,looknfeel,windows,apps}.lua`, `default/hypr/apps/{browser,hyprshot,system,terminals,walker}.lua`
- Delete: the corresponding `.conf` files

- [ ] **Step 1: Confirm the failing tests**

Run: `test/lua.sh`
Expected: "autostart launches the session daemons" FAILs.

- [ ] **Step 2: Write the modules**

`default/hypr/autostart.lua`:

```lua
-- Adapted from Omarchy v3.8.4 (MIT)
hl.on("hyprland.start", function()
  -- Slow app launch fix: hand the session environment to systemd and dbus first.
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")

  hl.exec_cmd(gz.launch("hypridle"))
  hl.exec_cmd(gz.launch("mako"))
  hl.exec_cmd(gz.launch("waybar"))
  hl.exec_cmd(gz.launch("swaybg -i " .. os.getenv("HOME") .. "/.config/gentoozinho/current/background -m fill"))
  hl.exec_cmd(gz.launch("/usr/libexec/polkit-gnome-authentication-agent-1"))
end)
```

`default/hypr/envs.lua`:

```lua
-- Adapted from Omarchy v3.8.4 (MIT)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Force all apps to use Wayland.
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Better screen sharing support.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

hl.env("XCOMPOSEFILE", os.getenv("HOME") .. "/.XCompose")

hl.config({
  xwayland = { force_zero_scaling = true },
  ecosystem = { no_update_news = true },
})
```

`default/hypr/input.lua`: `hl.config({ input = { kb_layout = "us", kb_options = "compose:caps", follow_mouse = 1, sensitivity = 0, touchpad = { natural_scroll = false } }, misc = { key_press_enables_dpms = true, mouse_move_enables_dpms = true } })`.

`default/hypr/looknfeel.lua`: the values of the current `looknfeel.conf` as `hl.config({ general = {...}, decoration = {...}, group = {...}, dwindle = {...}, scrolling = {...}, master = {...}, misc = {...}, cursor = {...}, binds = {...} })` plus `hl.curve` for the five beziers and `hl.animation` for each `animation =` line (`leaf`, `enabled`, `speed`, `bezier`, `style`). Colors: `active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 }`, `inactive_border = "rgba(595959aa)"`, shadow `color = "rgba(1a1a1aee)"`. `animations.enabled = true`. Do not carry the `$variable` lines; use Lua locals.

`default/hypr/windows.lua`:

```lua
-- Adapted from Omarchy v3.8.4 (MIT)
gz.window(".*", { suppress_event = "maximize" })
gz.window(".*", { tag = "+default-opacity" })
gz.window({ class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, { no_focus = true })
require("default.hypr.apps")
gz.window({ tag = "default-opacity" }, { opacity = "0.97 0.9" })
```

`default/hypr/apps.lua`: five `require("default.hypr.apps.<name>")` lines.

`default/hypr/apps/terminals.lua`: `gz.window("(Alacritty|kitty|com.mitchellh.ghostty|foot)", { tag = "+terminal" })`, `gz.window({ tag = "terminal" }, { tag = "-default-opacity" })`, `gz.window({ tag = "terminal" }, { opacity = "0.97 0.9" })`.
`default/hypr/apps/walker.lua`: `hl.layer_rule({ name = "walker-no-anim", match = { namespace = "walker" }, no_anim = true })`.
`default/hypr/apps/hyprshot.lua`: `hl.layer_rule({ name = "hyprshot-selection-no-anim", match = { namespace = "selection" }, no_anim = true })`.
`default/hypr/apps/browser.lua` and `apps/system.lua`: each `windowrule` line of the current `.conf` becomes one `gz.window(match, rules)`; `tag +x` → `{ tag = "+x" }`, `float on` → `{ float = true }`, `center on` → `{ center = true }`, `size 875 600` → `{ size = { 875, 600 } }`, `opacity 1 1` → `{ opacity = "1 1" }`, `tile on` → `{ tile = true }`, `workspace special silent` → `{ workspace = "special silent" }`, `idle_inhibit always` → `{ idle_inhibit = "always" }`, `rounding 8` → `{ rounding = 8 }`; `match:title` → `title =`, `match:tag` → `tag =`.

Delete `default/hypr/*.conf` and `default/hypr/apps/*.conf`.

- [ ] **Step 3: Run tests, lint, bats**

Run: `test/lua.sh && test/lint.sh && test/unit.sh`
Expected: Lua "autostart" passes; bats `hypr.bats` now FAILS on the removed `.conf` files. That is expected; `hypr.bats` is rewritten in Task 4. Record in ledger.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Port Hyprland defaults, window rules and autostart to Lua"
```

---

### Task 3: Port bindings

**Files:**
- Create: `default/hypr/bindings/{tiling,media,clipboard,utilities}.lua`
- Delete: `default/hypr/bindings/*.conf`

- [ ] **Step 1: Confirm the failing test**

Run: `test/lua.sh`
Expected: "core bindings are present" FAILs.

- [ ] **Step 2: Write the bindings**

`default/hypr/bindings/tiling.lua`:

```lua
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
```

`default/hypr/bindings/media.lua`: each line of the current `media.conf` becomes `gz.bind(key, description, "command", { locked = true, repeating = true })` for `bindeld` lines and `{ locked = true }` for `bindld` lines; keys like `XF86AudioRaiseVolume`, `SHIFT + XF86MonBrightnessUp`, `ALT + XF86AudioRaiseVolume`.

`default/hypr/bindings/clipboard.lua` (Omarchy v4's approach, MIT):

```lua
-- Adapted from Omarchy v4 (MIT). Send the shortcut to the focused surface with
-- a down/up split, which avoids stuck synthetic key state.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

local function universal(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if active_window_is_terminal() then
      send_shortcut_once(terminal_mods, terminal_key)()
    else
      send_shortcut_once(default_mods, default_key)()
    end
  end
end

gz.bind("SUPER + C", "Universal copy", universal("CTRL", "C", "CTRL SHIFT", "C"))
gz.bind("SUPER + V", "Universal paste", universal("CTRL", "V", "CTRL SHIFT", "V"))
gz.bind("SUPER + X", "Universal cut", send_shortcut_once("CTRL", "X"))
gz.bind("SUPER + CTRL + V", "Clipboard manager", "gentoozinho-launch-walker -m clipboard")
```

`default/hypr/bindings/utilities.lua`: every `bindd` line of the current `utilities.conf` as `gz.bind(keys, description, "command")`, with `SUPER, COMMA` written as `"SUPER + comma"` (xkbcommon keysym is lowercase), and the color picker as `gz.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")`.

Delete `default/hypr/bindings/*.conf`.

- [ ] **Step 3: Run tests, lint**

Run: `test/lua.sh && test/lint.sh`
Expected: all Lua tests pass (8 tests, 0 failures).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Port Hyprland bindings to Lua"
```

---

### Task 4: User templates, theme template, greeter, migration, bats

**Files:**
- Create: `config/hypr/{monitors,input,bindings,looknfeel,autostart}.lua`, `default/themed/hyprland.lua.tpl`, `default/sddm/hyprland.lua`
- Delete: `config/hypr/{hyprland,monitors,input,bindings,looknfeel,autostart}.conf`, `default/themed/hyprland.conf.tpl`, `default/sddm/hyprland.conf`
- Modify: `bin/gentoozinho-refresh-config`, `install/lib/user.sh`, `test/unit/hypr.bats` (rewrite), `test/unit/theme.bats`, `test/unit/scripts.bats`, `test/unit/user.bats`, `test/unit/install_sh.bats`

- [ ] **Step 1: Write the failing bats tests**

Rewrite `test/unit/hypr.bats`:

```bash
#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "no hyprlang files remain in the Hyprland layer" {
  run find "$REPO/default/hypr" "$REPO/default/sddm" "$REPO/config/hypr" -name '*.conf' ! -name 'hyprlock.conf' ! -name 'hypridle.conf'
  [ -z "$output" ]
  [ ! -e "$REPO/default/themed/hyprland.conf.tpl" ]
}

@test "user hyprland.lua bootstraps, loads defaults, then the five user modules" {
  f="$REPO/config/hypr/hyprland.lua"
  grep -q 'default/hypr/bootstrap.lua' "$f"
  grep -q 'require("default.hypr.gentoozinho")' "$f"
  for m in monitors input bindings looknfeel autostart; do
    grep -q "gz.require_optional(\"hypr.$m\")" "$f"
    [ -f "$REPO/config/hypr/$m.lua" ]
  done
}

@test "greeter compositor config is Lua with no gaps and a fullscreen rule" {
  f="$REPO/default/sddm/hyprland.lua"
  grep -q 'gaps_out = 0' "$f"
  grep -q 'border_size = 0' "$f"
  grep -q 'fullscreen = true' "$f"
  grep -q 'sddm-greeter' "$f"
}

@test "no omarchy paths leak into the Lua layer" {
  run grep -rE '\.local/share/omarchy|\.config/omarchy|omarchy-[a-z]' "$REPO/default/hypr" "$REPO/config/hypr" "$REPO/default/sddm"
  [ "$status" -ne 0 ]
}
```

In `test/unit/theme.bats`, in the "renders every template" test replace `grep -q 'rgb(7aa2f7)' "$t/hyprland.conf"` with `grep -q 'rgb(7aa2f7)' "$t/hyprland.lua"` and add `[ ! -e "$t/hyprland.conf" ]`; in "refresh-config PATH replaces one file" use `hypr/hyprland.lua` and grep `require("default.hypr.gentoozinho")`; in "refresh-config --init seeds missing files only" write `hyprland.lua` instead of `.conf` and check `monitors.lua`. Add:

```bash
@test "refresh-config --init migrates a hyprlang home to Lua (review focus 1)" {
  mkdir -p "$HOME/.config/hypr"
  for f in hyprland monitors input bindings looknfeel autostart hyprlock hypridle; do printf 'old\n' > "$HOME/.config/hypr/$f.conf"; done
  run gentoozinho-refresh-config --init
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre-lua"* ]]
  [ -f "$HOME/.config/hypr/hyprland.lua" ]
  [ ! -e "$HOME/.config/hypr/hyprland.conf" ]
  [ -f "$HOME/.config/hypr/pre-lua/hyprland.conf" ]
  [ -f "$HOME/.config/hypr/pre-lua/bindings.conf" ]
  [ "$(cat "$HOME/.config/hypr/hyprlock.conf")" = old ]
  [ "$(cat "$HOME/.config/hypr/hypridle.conf")" = old ]
}
```

In `test/unit/scripts.bats` change the command scan to `grep -rhoE 'gentoozinho-[a-z0-9-]+(\.css)?' default config bin/gentoozinho-refresh-config` is unchanged; it already scans `default` and `config` recursively so `.lua` files are covered.

In `test/unit/user.bats` change the expected `CompositorCommand=` to `.../default/sddm/hyprland.lua`. In `test/unit/install_sh.bats` the greeter test greps `default/sddm/hyprland.lua` for `gaps_out = 0`, `border_size = 0`, `fullscreen = true`.

- [ ] **Step 2: Run bats to verify failure**

Run: `test/unit.sh`
Expected: hypr.bats, theme.bats migration, user.bats greeter FAIL.

- [ ] **Step 3: Write the files**

`config/hypr/monitors.lua`:

```lua
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List monitors: hyprctl monitors

-- Retina-class 2x displays (13" 2.8K, 27" 5K, 32" 6K)
hl.env("GDK_SCALE", "2")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- 1x for 1080p/1440p or ultrawides:
-- hl.env("GDK_SCALE", "1")
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
```

`config/hypr/input.lua`: `hl.config({ input = { kb_options = "compose:caps", repeat_rate = 40, repeat_delay = 250, numlock_by_default = true, touchpad = { clickfinger_behavior = true, scroll_factor = 0.4 } } })` plus commented examples for layouts and natural scroll, and the terminal scroll rules as `gz.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })`.
`config/hypr/bindings.lua`: comments only, showing `gz.bind("SUPER + SHIFT + R", "SSH", "gentoozinho-launch-terminal -e ssh my-server")`, `gz.rebind(...)`, `hl.unbind("SUPER + B")`.
`config/hypr/looknfeel.lua`: commented `hl.config({ general = { gaps_in = 0 }, decoration = { rounding = 8, dim_inactive = true } })` examples.
`config/hypr/autostart.lua`: `-- gz.launch_on_start("my-service")`.

`default/themed/hyprland.lua.tpl`: spec section 6 text, with the `# Adapted…` header as `--`.

`default/sddm/hyprland.lua`:

```lua
-- Minimal Hyprland config for the SDDM Wayland greeter. SDDM starts the greeter
-- itself once the compositor is up; without layer-shell-qt it is a plain window.
hl.config({
  general = { gaps_in = 0, gaps_out = 0, border_size = 0 },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 },
  animations = { enabled = false },
})
hl.window_rule({ name = "sddm-greeter-fullscreen", match = { class = "^(sddm-greeter|sddm-greeter-qt6)$" }, fullscreen = true })
```

`bin/gentoozinho-refresh-config`, in the `--init` branch before the copy loop:

```bash
    # Phase 2 installs used hyprlang; Hyprland would keep loading the old
    # hyprland.conf, so move the files that now have Lua counterparts aside.
    hypr="$HOME/.config/hypr"
    if [[ -f $hypr/hyprland.conf && ! -f $hypr/hyprland.lua ]]; then
      mkdir -p "$hypr/pre-lua"
      for f in hyprland monitors input bindings looknfeel autostart; do
        [[ -f $hypr/$f.conf ]] && mv "$hypr/$f.conf" "$hypr/pre-lua/$f.conf"
      done
      echo "Moved your hyprlang Hyprland files to $hypr/pre-lua/ (Hyprland 0.57 drops .conf); Lua files seeded"
    fi
```

`install/lib/user.sh`: `CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.lua`.

Delete the listed `.conf` files.

- [ ] **Step 4: Run everything**

Run: `test/lua.sh && test/unit.sh && test/lint.sh`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Move user templates, theme fragment and greeter to Lua; migrate hyprlang homes"
```

---

### Task 5: Verify on the VM, smoke test, docs

**Files:**
- Modify: `README.md`, `docs/learning/02-desktop-session.md`, `docs/superpowers/specs/2026-09-27-gentoozinho-design.md` (section 7 pointer), `test/vm-smoke.sh` (one assertion)

- [ ] **Step 1: verify-config on the VM (review focus 4)**

Boot the VM as in phase 2 Task 7 step 3. Then:

```bash
tar -cz bin default config themes | ssh -p 40222 gentoo@127.0.0.1 'rm -rf ~/gz && mkdir ~/gz && tar xz -C ~/gz'
ssh -p 40222 gentoo@127.0.0.1 'export GENTOOZINHO_PATH=$HOME/gz PATH=$HOME/gz/bin:$PATH HOME=/tmp/gzhome; rm -rf $HOME; mkdir -p $HOME; gentoozinho-refresh-config --init && gentoozinho-theme-set tokyo-night && Hyprland --verify-config -c $HOME/.config/hypr/hyprland.lua 2>&1 | tail -3'
ssh -p 40222 gentoo@127.0.0.1 'GENTOOZINHO_PATH=$HOME/gz Hyprland --verify-config -c $HOME/gz/default/sddm/hyprland.lua 2>&1 | tail -2'
```

Expected: `config ok` twice. `GENTOOZINHO_PATH` must be exported into Hyprland's environment for the bootstrap to find the copy; in production it is unset and the default share path is used. Fix any dispatcher or rule field Hyprland rejects (the stub lists valid fields).

- [ ] **Step 2: Smoke assertion**

In `test/vm-smoke.sh` after the in-session screenshot add:

```bash
vm 'test -f ~/.config/hypr/hyprland.lua && test -d ~/.config/hypr/pre-lua && test ! -e ~/.config/hypr/hyprland.conf'
vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); hyprctl -j binds | grep -q "gentoozinho-launch-terminal"'
```

Commit, then run `GZ_SMOKE_SSH="ssh -p 40222 gentoo@127.0.0.1" test/vm-smoke.sh`. Expected: `SMOKE OK`; view `test/artifacts/smoke.png` and confirm **no** ".conf config format" notification is visible. Note the first-run migration line in the install log (`grep pre-lua /var/log/gentoozinho/install.log` on the VM).

- [ ] **Step 3: Docs**

README: the "Known" paragraph loses the 0.57 warning and gains "Hyprland config is Lua; edit `~/.config/hypr/*.lua`; `gz.bind(keys, description, command)` adds a binding; the API stub is at `/usr/share/hypr/stubs/hl.meta.lua`". Learning note 02: replace the "hyprlang today, Lua tomorrow" section with what the migration taught (package.path bootstrap, `require` caching and reload, dispatcher tables, `send_key_state` split, fake-`hl` testing). Spec section 7: one line pointing at the Lua spec.

- [ ] **Step 4: Tests, commit**

Run: `test/lua.sh && test/unit.sh && test/lint.sh`

```bash
git add -A
git commit -m "Verify the Lua configuration on the VM and update docs"
```

---

## Self-review notes

- Spec coverage: section 4 layout (Tasks 1, 2, 3, 4), section 5 helpers (Task 1), section 6 theme (Task 4), section 7 migration (Task 4 + Task 5 real run), section 8 consumers (Task 4 user.sh; scripts unchanged), section 9 testing (Tasks 1 and 5).
- Names: `gz.bind/rebind/window/exec_on_start/launch/launch_on_start/require_optional`, `hl._calls/_binds/_config/_start/_exec_commands`, module names `default.hypr.gentoozinho`, `gentoozinho.current.theme.hyprland`, `hypr.<user file>`; consistent across tasks.
- Review focus: 1 → Task 4 bats + Task 5; 2 → Task 1 test 1; 3 → Task 1 test 3; 4 → Task 5 step 1; 5 → Task 1 test "every default bind has a description" (meaningful from Task 3 on).
