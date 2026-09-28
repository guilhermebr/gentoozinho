#!/usr/bin/env bats

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "profiles.desc registers vm and desktop for amd64" {
  grep -qE '^amd64[[:space:]]+vm[[:space:]]+exp$' "$REPO/profiles/profiles.desc"
  grep -qE '^amd64[[:space:]]+desktop[[:space:]]+exp$' "$REPO/profiles/profiles.desc"
}

@test "each profile directory declares eapi 5" {
  for p in base vm desktop; do
    [ "$(cat "$REPO/profiles/$p/eapi")" = 5 ]
  done
}

@test "vm mirrors gentoo's desktop/systemd chain on a no-multilib base" {
  [ "$(sed -n 1p "$REPO/profiles/vm/parent")" = 'gentoo:default/linux/amd64/23.0/no-multilib' ]
  [ "$(sed -n 2p "$REPO/profiles/vm/parent")" = 'gentoo:targets/desktop' ]
  [ "$(sed -n 3p "$REPO/profiles/vm/parent")" = 'gentoo:targets/systemd' ]
  [ "$(sed -n 4p "$REPO/profiles/vm/parent")" = '../base' ]
}

@test "desktop inherits the desktop systemd profile and base" {
  [ "$(sed -n 1p "$REPO/profiles/desktop/parent")" = 'gentoo:default/linux/amd64/23.0/desktop/systemd' ]
  [ "$(sed -n 2p "$REPO/profiles/desktop/parent")" = '../base' ]
}

@test "base sets the shared USE defaults" {
  grep -q '^USE=".*networkmanager' "$REPO/profiles/base/make.defaults"
  grep -q '^USE=".*dist-kernel' "$REPO/profiles/base/make.defaults"
  # pipewire is a local flag (not in use.desc) and targets/desktop sets it anyway
  run ! grep -q '^USE=".*pipewire' "$REPO/profiles/base/make.defaults"
}

@test "base pins hyprland to systemd and uwsm" {
  grep -qE '^gui-wm/hyprland .*systemd' "$REPO/profiles/base/package.use"
  grep -qE '^gui-wm/hyprland .*uwsm' "$REPO/profiles/base/package.use"
}

@test "base works around the cxxopts ebuild that uses icu without depending on it" {
  grep -qE '^dev-libs/cxxopts -icu' "$REPO/profiles/base/package.use"
}

@test "base builds the distribution kernel without debug info" {
  grep -qE '^sys-kernel/gentoo-kernel -debug' "$REPO/profiles/base/package.use"
}
