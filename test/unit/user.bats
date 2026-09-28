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
  [[ "$out" == *"CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.lua"* ]]
  [[ "$out" != *"[Autologin]"* ]]
  # QT_WAYLAND_SHELL_INTEGRATION=layer-shell aborts sddm-greeter-qt6 when layer-shell-qt is absent
  [[ "$out" != *"layer-shell"* ]]
  out="$(gz_sddm_conf alice 1)"
  [[ "$out" == *"[Autologin]"* ]]
  [[ "$out" == *"User=alice"* ]]
  [[ "$out" == *"Session=gentoozinho.desktop"* ]]
}

@test "gz_kernel_has_drm looks for DRM modules in any installed kernel or a built-in drm" {
  tmp="$(mktemp -d)"
  run gz_kernel_has_drm "$tmp/lib/modules" "$tmp/sys/module"
  [ "$status" -ne 0 ]
  mkdir -p "$tmp/lib/modules/6.18.50/kernel/drivers/gpu/drm"
  gz_kernel_has_drm "$tmp/lib/modules" "$tmp/sys/module"
  rm -rf "$tmp/lib"
  mkdir -p "$tmp/sys/module/drm"
  gz_kernel_has_drm "$tmp/lib/modules" "$tmp/sys/module"
  rm -rf "$tmp"
}
