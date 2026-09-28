# Hyprland Lua configuration design

Date: 2026-09-28
Status: approved design, pre-plan
Parent spec: `docs/superpowers/specs/2026-09-27-gentoozinho-design.md` (section 7)

## 1. Purpose

Hyprland 0.56 warns in every session that hyprlang `.conf` support is removed
in 0.57. gentoozinho's whole Hyprland layer (defaults, bindings, window rules,
user templates, the theme fragment, the SDDM greeter config) is hyprlang.
This work replaces it with Lua, keeping the user-facing structure and the
theme engine, with no dual-format support.

Success: on the smoke VM, a fresh install and an upgraded phase 2 install
both boot into the session with no `.conf` notification, all bindings and
rules present, theme switching working, and the greeter running.

## 2. Facts (verified 2026-09-28)

- Hyprland 0.56.2 ships `/usr/share/hypr/hyprland.lua` (example) and
  `/usr/share/hypr/stubs/hl.meta.lua` (1777 lines, the full `hl` API).
  `Hyprland --verify-config -c file.lua` prints `config ok` for valid Lua.
- API used here: `hl.config({section = {key = value}})`, `hl.bind(keys,
  dispatcher, opts)` with `hl.dsp.*` dispatchers (`exec_cmd`, `window.close`,
  `focus`, `window.move`, `workspace.toggle_special`, `layout`,
  `window.float`, `window.fullscreen`, `window.pseudo`, `window.swap`,
  `window.resize`, `window.drag`, `send_shortcut`), `hl.unbind`,
  `hl.window_rule({name, match = {...}, ...})`, `hl.layer_rule`, `hl.env`,
  `hl.monitor`, `hl.on("hyprland.start", fn)`, `hl.exec_cmd`, `hl.curve`,
  `hl.animation`. Bind options: `description`, `locked`, `repeating`,
  `release`, `mouse`. Keys are `"SUPER + SHIFT + code:10"` strings.
- Files are loaded with Lua `require` resolved through `package.path`;
  Omarchy v4 (MIT) sets it in a `bootstrap.lua` and exposes helpers on a
  global `o`.
- When only `hyprland.conf` exists Hyprland loads it, so upgrading users must
  have their old files moved aside.
- The host has Lua 5.4, so our Lua modules can be executed in unit tests
  against a fake `hl`.

## 3. Decisions

| Decision | Choice | Why |
|---|---|---|
| Formats | Lua only; delete the `.conf` files | 0.57 removes hyprlang; two formats would rot |
| Helper name | global `gz`, with `o = gz` | ours in docs; Omarchy snippets paste unchanged |
| Helper scope | `bind`, `rebind`, `window`, `exec_on_start`, `launch`, `require_optional` | what the ported bindings need, nothing more |
| hyprlock, hypridle, hyprpaper | unchanged | separate programs with their own formats |
| Existing users | `refresh-config --init` moves `~/.config/hypr/*.conf` to `pre-lua/` and seeds Lua | precedence would silently keep the old config |

## 4. Layout

```
default/hypr/bootstrap.lua          package.path: ~/.local/state, ~/.config, /usr/share/gentoozinho (or GENTOOZINHO_PATH)
default/hypr/gz.lua                 helpers; sets o = gz
default/hypr/gentoozinho.lua        requires gz, defaults in order, then the optional theme module
default/hypr/autostart.lua          hl.on("hyprland.start") launching hypridle, mako, waybar, swaybg, polkit agent; env import
default/hypr/envs.lua               hl.env calls, xwayland force_zero_scaling, ecosystem.no_update_news
default/hypr/input.lua              hl.config({ input = ..., misc = { key_press_enables_dpms ... } })
default/hypr/looknfeel.lua          general, decoration, group, animations (hl.curve + hl.animation), dwindle, master, misc, cursor, binds
default/hypr/windows.lua            suppress maximize, default-opacity tag, xwayland drag fix, require apps, opacity rule
default/hypr/apps.lua               requires apps/{browser,hyprshot,system,terminals,walker}
default/hypr/apps/*.lua             gz.window / hl.layer_rule tables
default/hypr/bindings/{tiling,media,clipboard,utilities}.lua   gz.bind calls with descriptions
default/sddm/hyprland.lua           greeter compositor config
default/themed/hyprland.lua.tpl     hl.config border colors from {{ accent_strip }}
config/hypr/hyprland.lua            dofile bootstrap; require default.hypr.gentoozinho; gz.require_optional the five user modules
config/hypr/{monitors,input,bindings,looknfeel,autostart}.lua  user-owned, commented examples
```

`config/hypr/hyprland.lua`:

```lua
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
```

## 5. Helpers (`default/hypr/gz.lua`)

```lua
gz = gz or {}
o = gz
gz.launch(cmd)                      -> "uwsm-app -- " .. cmd
gz.bind(keys, description, dispatcher, opts)
    -- dispatcher: an hl.dsp value, a command string (wrapped in hl.dsp.exec_cmd),
    -- or { launch = "cmd" } (wrapped in gz.launch then exec_cmd)
gz.rebind(keys, description, dispatcher, opts)   -- hl.unbind(keys) first
gz.window(match, rules)             -- string match = class; table match merged into rules.match
gz.exec_on_start(cmd)               -- hl.on("hyprland.start", function() hl.exec_cmd(cmd) end)
gz.require_optional(module)         -- require only when package.searchpath finds it
```

Every default binding passes a description, so `hyprctl -j binds` keeps
`has_description` for `gentoozinho-menu-keybindings`.

## 6. Theme engine

`default/themed/hyprland.conf.tpl` is replaced by `hyprland.lua.tpl`:

```lua
local active = "rgb({{ accent_strip }})"
hl.config({
  general = { col = { active_border = active } },
  group   = { col = { border_active = active } },
})
```

`gentoozinho-theme-set` is unchanged: it renders into
`~/.config/gentoozinho/current/theme/hyprland.lua`, which `gentoozinho.lua`
loads as module `gentoozinho.current.theme.hyprland` (found through the
`~/.config` entry of `package.path`), then runs `hyprctl reload`.

## 7. Migration

`gentoozinho-refresh-config --init`: when `~/.config/hypr/hyprland.conf`
exists and `~/.config/hypr/hyprland.lua` does not, move `hyprland.conf`,
`monitors.conf`, `input.conf`, `bindings.conf`, `looknfeel.conf`,
`autostart.conf` into `~/.config/hypr/pre-lua/` (creating it), print one line
saying so, then seed as usual. `hyprlock.conf` and `hypridle.conf` stay. The
installer's user stage already calls `--init`, so an upgrade run migrates.

## 8. Scripts and other consumers

- `gentoozinho-theme-set`: unchanged.
- `gentoozinho-menu-keybindings`, `gentoozinho-hyprland-window-close-all`,
  `config/hypr/hypridle.conf` (`hyprctl dispatch dpms …`): unchanged; hyprctl
  runtime syntax is independent of the config format (verified in phase 2).
- `install/lib/user.sh`: `CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.lua`.
- README, learning note 02, spec section 7: updated.

## 9. Testing

- `test/lua.sh` runs `lua5.4 test/lua/run.lua` on the host. `test/lua/fake_hl.lua`
  is a recording stub: `hl.config` merges tables, `hl.bind` records `{keys,
  dispatcher, opts}`, `hl.dsp.*` returns tagged tables, `hl.window_rule`,
  `hl.layer_rule`, `hl.env`, `hl.monitor`, `hl.curve`, `hl.animation`,
  `hl.on`, `hl.exec_cmd`, `hl.unbind` record calls. Tests, with
  `GENTOOZINHO_PATH` set to the repo and `HOME` to a temp dir holding a
  rendered theme module:
  1. `config/hypr/hyprland.lua` loads with no error and no user modules.
  2. Every recorded bind has a non-empty description.
  3. Every `exec_cmd` command's first word is a `bin/gentoozinho-*` script,
     or one of `nautilus`, `makoctl`, `hyprpicker`, `pkill`, `systemctl`,
     `dbus-update-activation-environment`, `uwsm-app`.
  4. The theme module set `general.col.active_border` to the rendered accent.
  5. `gz.rebind` unbinds then binds; `gz.require_optional` of a missing
     module returns nil without error.
  6. `hyprland.start` handlers exec hypridle, mako, waybar, swaybg.
- bats: `hypr.bats` rewritten for the Lua files (structure and no-omarchy
  checks), `theme.bats` asserts `hyprland.lua` is rendered and the migration
  moves `.conf` files aside, `scripts.bats` command scan now covers `.lua`.
- Smoke: unchanged assertions plus `Hyprland --verify-config` on the
  assembled Lua config during development; the session screenshot must show
  no `.conf` notification. The VM is a phase 2 install, so the migration path
  runs for real.

## 10. Out of scope

Omarchy's menu system, `qconsole`, toggles framework, per-device input
detection from vconsole, `hypr_gradient` template helpers, Lua for hyprlock or
hypridle, LSP setup for users (documented pointer to the stub only).
