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
