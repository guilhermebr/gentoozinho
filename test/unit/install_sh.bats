#!/usr/bin/env bats
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
  grep -q 'for stage in preflight portage packages finish' "$REPO/install.sh"
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
  ! grep -q 'autounmask' "$f"
}

@test "finish step never reboots without a tty" {
  grep -q '\[\[ -t 0 \]\]' "$REPO/install/finish/10-summary.sh"
}
