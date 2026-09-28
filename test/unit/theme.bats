#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$(mktemp -d)"; export HOME
  export GENTOOZINHO_PATH="$REPO"
  export PATH="$REPO/bin:$PATH"
}
teardown() { rm -rf "$HOME"; }

@test "theme-list prints the four shipped themes" {
  [ "$(gentoozinho-theme-list | tr '\n' ' ')" = "catppuccin gruvbox nord tokyo-night " ]
}

@test "theme-set renders every template with the theme's colors" {
  gentoozinho-theme-set tokyo-night
  t="$HOME/.config/gentoozinho/current/theme"
  grep -q 'rgb(7aa2f7)' "$t/hyprland.lua"
  [ ! -e "$t/hyprland.conf" ]
  grep -q 'background-color=#1a1b26' "$t/mako.ini"
  grep -q 'include=/usr/share/gentoozinho/default/mako/core.ini' "$t/mako.ini"
  grep -q '@define-color background #1a1b26;' "$t/waybar.css"
  grep -q 'rgba(26,27,38, 1.0)' "$t/hyprlock.conf"
  grep -q '@define-color selected-text #7aa2f7;' "$t/walker.css"
  grep -q '@define-color color1 #7aa2f7;' "$t/walker.css"
  grep -q '@define-color progress #7aa2f7;' "$t/swayosd.css"
  grep -q 'background = "#1a1b26"' "$t/alacritty.toml"
  [ "$(cat "$HOME/.config/gentoozinho/current/theme.name")" = tokyo-night ]
  [ -L "$HOME/.config/gentoozinho/current/background" ]
  [ ! -e "$HOME/.config/hypr/hyprpaper.conf" ]
  grep -q 'swaybg' "$REPO/bin/gentoozinho-theme-bg-next"
}

@test "theme-set works with no compositor running (review focus 1)" {
  run gentoozinho-theme-set nord
  [ "$status" -eq 0 ]
  [ "$(gentoozinho-theme-current)" = nord ]
}

@test "theme-next cycles alphabetically and wraps" {
  gentoozinho-theme-set tokyo-night
  gentoozinho-theme-next
  [ "$(gentoozinho-theme-current)" = catppuccin ]
  gentoozinho-theme-next
  [ "$(gentoozinho-theme-current)" = gruvbox ]
}

@test "theme-set rejects an unknown theme and a theme without colors.toml (review focus 3)" {
  run gentoozinho-theme-set no-such-theme
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
  mkdir -p "$HOME/.config/gentoozinho/themes/broken/backgrounds"
  run gentoozinho-theme-set broken
  [ "$status" -eq 1 ]
  [[ "$output" == *"colors.toml"* ]]
}

@test "user themes under ~/.config/gentoozinho/themes are found" {
  mkdir -p "$HOME/.config/gentoozinho/themes/mine/backgrounds"
  cp "$REPO/themes/nord/colors.toml" "$HOME/.config/gentoozinho/themes/mine/"
  cp "$REPO"/themes/nord/backgrounds/* "$HOME/.config/gentoozinho/themes/mine/backgrounds/"
  gentoozinho-theme-list | grep -qx mine
  gentoozinho-theme-set mine
  [ "$(gentoozinho-theme-current)" = mine ]
}

@test "refresh-config --init seeds missing files only (review focus 2)" {
  mkdir -p "$HOME/.config/hypr"
  printf 'mine\n' > "$HOME/.config/hypr/hyprland.lua"
  gentoozinho-refresh-config --init
  [ "$(cat "$HOME/.config/hypr/hyprland.lua")" = mine ]
  [ -f "$HOME/.config/hypr/monitors.lua" ]
  [ -f "$HOME/.config/waybar/config.jsonc" ]
}

@test "refresh-config PATH replaces one file and keeps a backup" {
  mkdir -p "$HOME/.config/hypr"
  printf 'mine\n' > "$HOME/.config/hypr/hyprland.lua"
  gentoozinho-refresh-config hypr/hyprland.lua
  grep -q 'require("default.hypr.gentoozinho")' "$HOME/.config/hypr/hyprland.lua"
  ls "$HOME"/.config/hypr/hyprland.lua.bak.* > /dev/null
}

@test "every theme has colors.toml with the keys the templates use and exactly one background" {
  for d in "$REPO"/themes/*/; do
    for k in accent foreground background color0 color15; do
      grep -q "^$k = \"#" "$d/colors.toml"
    done
    [ "$(ls "$d/backgrounds" | wc -l)" -eq 1 ]
  done
}

@test "theme-set rejects colors that are not #rrggbb and keys that could corrupt the templates (review I6)" {
  d="$HOME/.config/gentoozinho/themes/bad"
  mkdir -p "$d/backgrounds"
  cp "$REPO"/themes/nord/backgrounds/* "$d/backgrounds/"
  sed -e 's/^accent = .*/accent = "red"/' -e 's/^foreground = .*/foreground = "#fff"/' "$REPO/themes/nord/colors.toml" > "$d/colors.toml"
  run gentoozinho-theme-set bad
  [ "$status" -eq 1 ]
  [[ "$output" == *"accent"* ]]
  [[ "$output" == *"#rrggbb"* ]]
  [ "$(gentoozinho-theme-current)" = none ]
  printf 'accent = "#7aa2f7"\nfore|ground = "#a9b1d6"\n' > "$d/colors.toml"
  run gentoozinho-theme-set bad
  [ "$status" -eq 1 ]
  [[ "$output" == *"key"* ]]
}

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
