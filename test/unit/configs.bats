#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "waybar config has the expected modules and no omarchy ones" {
  f="$REPO/config/waybar/config.jsonc"
  grep -q '"modules-left"' "$f"
  grep -q '"hyprland/workspaces"' "$f"
  run grep -E 'custom/(omarchy|update|weather|voxtype|screenrecording|idle-indicator|notification-silencing)|omarchy-' "$f"
  [ "$status" -ne 0 ]
  grep -q '@import "../gentoozinho/current/theme/waybar.css";' "$REPO/config/waybar/style.css"
}

@test "walker config uses the gentoozinho theme and its css imports the themed colors" {
  grep -q '^theme = "gentoozinho"' "$REPO/config/walker/config.toml"
  grep -q '@import url("gentoozinho-colors.css");' "$REPO/config/walker/themes/gentoozinho.css"
  [ -f "$REPO/config/walker/themes/gentoozinho.toml" ]
}

@test "mako user config includes the themed fragment" {
  grep -q '^include=~/.config/gentoozinho/current/theme/mako.ini' "$REPO/config/mako/config"
  grep -q '^default-timeout=' "$REPO/default/mako/core.ini"
  run grep omarchy "$REPO/default/mako/core.ini"
  [ "$status" -ne 0 ]
}

@test "alacritty imports the themed colors and uses JetBrains Mono" {
  grep -q '"~/.config/gentoozinho/current/theme/alacritty.toml"' "$REPO/config/alacritty/alacritty.toml"
  grep -q 'JetBrains Mono' "$REPO/config/alacritty/alacritty.toml"
}

@test "swayosd style imports the themed colors" {
  grep -q '@import url("colors.css");' "$REPO/config/swayosd/style.css"
  grep -q 'style = "~/.config/swayosd/style.css"' "$REPO/config/swayosd/config.toml"
}

@test "uwsm env exports the essentials" {
  grep -q '^export TERMINAL=alacritty' "$REPO/config/uwsm/env"
  grep -q '^export EDITOR=nvim' "$REPO/config/uwsm/env"
}

@test "bash rc initialises starship and zoxide only when present" {
  f="$REPO/default/bash/rc"
  grep -q 'command -v starship' "$f"
  grep -q 'command -v zoxide' "$f"
  bash -n "$f"
}
