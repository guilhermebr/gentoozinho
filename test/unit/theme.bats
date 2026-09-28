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
  grep -q 'rgb(7aa2f7)' "$t/hyprland.conf"
  grep -q 'background-color=#1a1b26' "$t/mako.ini"
  grep -q 'include=/usr/share/gentoozinho/default/mako/core.ini' "$t/mako.ini"
  grep -q '@define-color background #1a1b26;' "$t/waybar.css"
  grep -q 'rgba(26,27,38, 1.0)' "$t/hyprlock.conf"
  grep -q '@define-color selected-text #7aa2f7;' "$t/walker.css"
  grep -q '@define-color progress #7aa2f7;' "$t/swayosd.css"
  grep -q 'background = "#1a1b26"' "$t/alacritty.toml"
  [ "$(cat "$HOME/.config/gentoozinho/current/theme.name")" = tokyo-night ]
  [ -L "$HOME/.config/gentoozinho/current/background" ]
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
  printf 'mine\n' > "$HOME/.config/hypr/hyprland.conf"
  gentoozinho-refresh-config --init
  [ "$(cat "$HOME/.config/hypr/hyprland.conf")" = mine ]
  [ -f "$HOME/.config/hypr/monitors.conf" ]
  [ -f "$HOME/.config/waybar/config.jsonc" ]
}

@test "refresh-config PATH replaces one file and keeps a backup" {
  mkdir -p "$HOME/.config/hypr"
  printf 'mine\n' > "$HOME/.config/hypr/hyprland.conf"
  gentoozinho-refresh-config hypr/hyprland.conf
  grep -q 'source = /usr/share/gentoozinho/default/hypr/autostart.conf' "$HOME/.config/hypr/hyprland.conf"
  ls "$HOME"/.config/hypr/hyprland.conf.bak.* > /dev/null
}

@test "every theme has colors.toml with the keys the templates use and exactly one background" {
  for d in "$REPO"/themes/*/; do
    for k in accent foreground background color0 color15; do
      grep -q "^$k = \"#" "$d/colors.toml"
    done
    [ "$(ls "$d/backgrounds" | wc -l)" -eq 1 ]
  done
}
