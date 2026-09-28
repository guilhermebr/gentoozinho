#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  export GZ_ROOT=""
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../../install/lib/all.sh"
}

@test "gz_user_exists" {
  gz_user_exists root
  run gz_user_exists no-such-user-xyz
  [ "$status" -ne 0 ]
}

@test "gz_user_groups lists the desktop groups" {
  [ "$(gz_user_groups)" = "wheel,users,video,audio,input,plugdev" ]
}

@test "gz_sddm_conf renders wayland greeter, session and optional autologin" {
  out="$(gz_sddm_conf alice 0)"
  [[ "$out" == *"DisplayServer=wayland"* ]]
  [[ "$out" == *"CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.conf"* ]]
  [[ "$out" != *"[Autologin]"* ]]
  out="$(gz_sddm_conf alice 1)"
  [[ "$out" == *"[Autologin]"* ]]
  [[ "$out" == *"User=alice"* ]]
  [[ "$out" == *"Session=gentoozinho.desktop"* ]]
}
