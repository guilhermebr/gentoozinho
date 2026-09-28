#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Structural checks on the ebuild repository. Real validation happens in the
# VM smoke test; these catch typos before a VM is ever booted.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "layout.conf declares the repo and formats" {
  grep -qx 'masters = gentoo guru hyproverlay' "$REPO/metadata/layout.conf"
  grep -qx 'repo-name = gentoozinho' "$REPO/metadata/layout.conf"
  grep -qx 'thin-manifests = true' "$REPO/metadata/layout.conf"
  grep -qx 'profile-formats = portage-2' "$REPO/metadata/layout.conf"
}

@test "profiles/repo_name matches layout.conf" {
  [ "$(cat "$REPO/profiles/repo_name")" = gentoozinho ]
}

@test "profiles/eapi is 5" {
  [ "$(cat "$REPO/profiles/eapi")" = 5 ]
}

@test "every category directory holding ebuilds is listed in profiles/categories" {
  cd "$REPO"
  for dir in */*/; do
    compgen -G "${dir}*.ebuild" > /dev/null || continue
    cat="${dir%%/*}"
    grep -qx "$cat" profiles/categories
  done
}
