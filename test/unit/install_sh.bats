#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# install.sh is exercised for real in test/vm-smoke.sh. Here we only check the
# parts that do not need root: help, argument errors, and stage ordering.

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "install.sh --help prints usage and exits 0" {
  run "$REPO/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: install.sh"* ]]
}

@test "install.sh rejects an unknown flag before touching the system" {
  run env GZ_LOG_FILE=/dev/null "$REPO/install.sh" --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument: --bogus"* ]]
}

@test "stages run in the documented order" {
  grep -q 'for stage in preflight portage packages system user finish' "$REPO/install.sh"
}

@test "every stage step is a readable bash file with a numeric prefix" {
  for f in "$REPO"/install/*/[0-9][0-9]-*.sh; do
    [ -r "$f" ]
    bash -n "$f"
  done
}

@test "packages step resolves before it merges and never uses autounmask" {
  f="$REPO/install/packages/10-emerge.sh"
  grep -q 'emerge --pretend' "$f"
  grep -q 'emerge --getbinpkg --keep-going=n' "$f"
  grep -q -- '--update --deep --newuse @world' "$f"
  run ! grep -q 'autounmask' "$f"
}

@test "finish step never reboots without a tty" {
  grep -q '\[\[ -t 0 \]\]' "$REPO/install/finish/10-summary.sh"
}

@test "repos step declares the main gentoo repo in repos.conf (pkgcore and pkgcheck need it)" {
  f="$REPO/install/portage/30-repos.sh"
  grep -q '/usr/share/portage/config/repos.conf' "$f"
  grep -q 'repos.conf/gentoo.conf' "$f"
}

@test "smoke test scans stable profiles only and tolerates our non-category dirs" {
  grep -q 'pkgcheck scan -r gentoozinho -p stable --keywords=-UnknownCategoryDirs' "$REPO/test/vm-smoke.sh"
}

@test "repos step syncs the master overlays before registering gentoozinho" {
  f="$REPO/install/portage/30-repos.sh"
  sync_line="$(grep -n 'emaint sync -r "\$repo"' "$f" | cut -d: -f1)"
  add_line="$(grep -n 'eselect repository add gentoozinho' "$f" | cut -d: -f1)"
  [ -n "$sync_line" ] && [ -n "$add_line" ] && [ "$sync_line" -lt "$add_line" ]
}

@test "install.sh checks for root before it touches the log directory (review I1)" {
  root_line="$(grep -n 'gz_check_root' "$REPO/install.sh" | head -1 | cut -d: -f1)"
  log_line="$(grep -n 'mkdir -p "$(dirname "$GZ_LOG_FILE")"' "$REPO/install.sh" | cut -d: -f1)"
  [ -n "$root_line" ] && [ -n "$log_line" ] && [ "$root_line" -lt "$log_line" ]
}

@test "install.sh enables errtrace so the ERR trap fires inside functions (review I5)" {
  grep -q '^set -Eeuo pipefail' "$REPO/install.sh"
}

@test "smoke test exercises profile auto-detection on the second run (review C1)" {
  [ "$(grep -c 'install.sh --profile vm' "$REPO/test/vm-smoke.sh")" -eq 1 ]
  grep -q "install.sh --no-reboot --repo-url" "$REPO/test/vm-smoke.sh"
}

@test "repos step points git-r3 at a local checkout" {
  grep -q 'EGIT_OVERRIDE_REPO_GUILHERMEBR_GENTOOZINHO' "$REPO/install/portage/30-repos.sh"
}

@test "user stage seeds config, sets the theme and sources the shell rc as the user" {
  grep -q 'gentoozinho-refresh-config --init' "$REPO/install/user/20-config.sh"
  grep -q 'gentoozinho-theme-set' "$REPO/install/user/30-theme.sh"
  grep -q 'source /usr/share/gentoozinho/default/bash/rc' "$REPO/install/user/40-shell.sh"
}

@test "the cloud image's headless kernel config is removed before packages, and a DRM kernel is ensured" {
  grep -q 'dist-amd64-livecd.config' "$REPO/install/portage/45-kernel-config.sh"
  grep -q 'gz_kernel_has_drm' "$REPO/install/system/05-kernel.sh"
  grep -q 'sys-kernel/gentoo-kernel-bin' "$REPO/install/system/05-kernel.sh"
}
