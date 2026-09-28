#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "the helper scripts the desktop needs all exist" {
  for s in restart-waybar restart-mako launch-walker launch-browser launch-terminal swayosd-client \
           brightness-display capture-screenshot system-lock toggle-waybar toggle-idle \
           toggle-notification-silencing hyprland-window-close-all update menu-keybindings \
           theme-set theme-list theme-current theme-next theme-bg-next theme-set-templates refresh-config version; do
    [ -x "$REPO/bin/gentoozinho-$s" ]
  done
}

@test "every gentoozinho-* command referenced anywhere in default/ or config/ exists in bin/" {
  cd "$REPO"
  missing=""
  for cmd in $(grep -rhoE 'gentoozinho-[a-z0-9-]+(\.css)?' default config 2>/dev/null | grep -v '\.css$' | sort -u); do
    [ -f "bin/$cmd" ] || missing="$missing $cmd"
  done
  [ -z "$missing" ] || { echo "missing:$missing"; false; }
}

@test "no omarchy paths or commands leak into the payload" {
  cd "$REPO"
  run grep -rIlE 'omarchy-[a-z]|\.local/share/omarchy|\.config/omarchy' bin default config themes
  [ "$status" -ne 0 ]
}

@test "update runs the Handbook sequence" {
  f="$REPO/bin/gentoozinho-update"
  grep -q 'emerge --sync' "$f"
  grep -q -- '--update --deep --newuse' "$f"
  grep -q -- '--depclean' "$f"
  grep -q 'dispatch-conf' "$f"
}

@test "gentoozinho-update refreshes the live payload (review I5)" {
  grep -q 'app-misc/gentoozinho-9999' "$REPO/bin/gentoozinho-update"
  grep -q 'emerge --oneshot' "$REPO/bin/gentoozinho-update"
}
