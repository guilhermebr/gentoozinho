#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "user hyprland.conf sources defaults, theme, then user files in that order" {
  f="$REPO/config/hypr/hyprland.conf"
  mapfile -t src < <(grep -oE '^source = .*' "$f" | sed 's/^source = //')
  [ "${src[0]}" = "/usr/share/gentoozinho/default/hypr/autostart.conf" ]
  printf '%s\n' "${src[@]}" | grep -q '^/usr/share/gentoozinho/default/hypr/bindings/tiling.conf$'
  printf '%s\n' "${src[@]}" | grep -q '^/usr/share/gentoozinho/default/hypr/looknfeel.conf$'
  theme_idx="$(printf '%s\n' "${src[@]}" | grep -n 'current/theme/hyprland.conf' | cut -d: -f1)"
  user_idx="$(printf '%s\n' "${src[@]}" | grep -n '~/.config/hypr/monitors.conf' | cut -d: -f1)"
  [ "$theme_idx" -lt "$user_idx" ]
}

@test "default configs never point at omarchy paths" {
  cd "$REPO"
  run grep -rE 'omarchy' default/hypr config/hypr
  [ "$status" -ne 0 ]
}

@test "autostart launches the session services through uwsm-app" {
  f="$REPO/default/hypr/autostart.conf"
  for app in hypridle mako waybar; do grep -q "exec-once = uwsm-app -- $app" "$f"; done
  grep -q "exec-once = uwsm-app -- swaybg -i ~/.config/gentoozinho/current/background -m fill" "$f"
  run grep -q hyprpaper "$f"
  [ "$status" -ne 0 ]
  grep -q 'exec-once = systemctl --user import-environment' "$f"
}

@test "bindings keep Omarchy's core keys" {
  grep -q 'bindd = SUPER, W, Close window, killactive,' "$REPO/default/hypr/bindings/tiling.conf"
  u="$REPO/default/hypr/bindings/utilities.conf"
  grep -q 'bindd = SUPER, RETURN, Terminal, exec, gentoozinho-launch-terminal' "$u"
  grep -q 'bindd = SUPER, SPACE, Launch apps, exec, gentoozinho-launch-walker' "$u"
  grep -q 'bindd = SUPER CTRL, L, Lock system, exec, gentoozinho-system-lock' "$u"
  grep -q 'bindd = SUPER SHIFT CTRL, SPACE, Next theme, exec, gentoozinho-theme-next' "$u"
}

@test "hypridle and hyprlock user configs reference gentoozinho, not omarchy" {
  grep -q 'lock_cmd = gentoozinho-system-lock' "$REPO/config/hypr/hypridle.conf"
  grep -q 'source = ~/.config/gentoozinho/current/theme/hyprlock.conf' "$REPO/config/hypr/hyprlock.conf"
}
