#!/usr/bin/env bats

setup() {
  export GZ_ROOT=""
  unset SUDO_USER
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../../install/lib/all.sh"
}

@test "defaults" {
  gz_parse_args
  [ "$GZ_PROFILE" = auto ]
  [ "$GZ_USER" = gentoo ]
  [ "$GZ_METAS" = base,desktop ]
  [ "$GZ_NO_REBOOT" = 0 ]
  [ "$GZ_REPO_URL" = https://github.com/guilhermebr/gentoozinho.git ]
}

@test "SUDO_USER becomes the default user" {
  SUDO_USER=alice gz_parse_args
  [ "$GZ_USER" = alice ]
}

@test "all flags parse" {
  gz_parse_args --profile desktop --user bob --metas base,dev --no-reboot --repo-url /tmp/src
  [ "$GZ_PROFILE" = desktop ]
  [ "$GZ_USER" = bob ]
  [ "$GZ_METAS" = base,dev ]
  [ "$GZ_NO_REBOOT" = 1 ]
  [ "$GZ_REPO_URL" = /tmp/src ]
}

@test "invalid profile, unknown meta and unknown flag die with a message" {
  run gz_parse_args --profile server
  [ "$status" -eq 1 ]; [[ "$output" == *"--profile must be vm or desktop"* ]]
  run gz_parse_args --metas base,games
  [ "$status" -eq 1 ]; [[ "$output" == *"unknown meta: games"* ]]
  run gz_parse_args --bogus
  [ "$status" -eq 1 ]; [[ "$output" == *"unknown argument: --bogus"* ]]
}

@test "a flag without its value dies cleanly" {
  run gz_parse_args --profile
  [ "$status" -eq 1 ]
  [[ "$output" == *"--profile needs a value"* ]]
  [[ "$output" != *"unbound variable"* ]]
}

@test "gz_meta_atoms expands the csv" {
  [ "$(gz_meta_atoms base,desktop)" = "gentoozinho-meta/base gentoozinho-meta/desktop" ]
  [ "$(gz_meta_atoms dev)" = "gentoozinho-meta/dev" ]
}

@test "gz_repo_kind: existing directory is local, anything else is git" {
  d="$(mktemp -d)"
  [ "$(gz_repo_kind "$d")" = local ]
  [ "$(gz_repo_kind "$d/")" = local ]
  [ "$(gz_repo_kind https://github.com/guilhermebr/gentoozinho.git)" = git ]
  rmdir "$d"
}
