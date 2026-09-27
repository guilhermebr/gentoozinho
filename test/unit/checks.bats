#!/usr/bin/env bats

setup() {
  export GZ_ROOT=""
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../../install/lib/all.sh"
}

@test "gz_check_root accepts 0 and rejects others" {
  gz_check_root 0
  run gz_check_root 1000
  [ "$status" -eq 1 ]
  [[ "$output" == *"run as root"* ]]
}

@test "gz_check_arch accepts x86_64 only" {
  gz_check_arch x86_64
  run gz_check_arch aarch64
  [ "$status" -eq 1 ]
  [[ "$output" == *"amd64 only"* ]]
}

@test "gz_check_init requires systemd" {
  gz_check_init systemd
  run gz_check_init init
  [ "$status" -eq 1 ]
  [[ "$output" == *"OpenRC"* ]]
}

@test "gz_check_gcc requires major 15 or newer" {
  gz_check_gcc 15.3.0
  gz_check_gcc 16.1.0
  run gz_check_gcc 14.2.1
  [ "$status" -eq 1 ]
  [[ "$output" == *"gcc 15"* ]]
}

@test "gz_check_cmd finds bash and misses a nonsense command" {
  gz_check_cmd bash
  run gz_check_cmd definitely-not-a-command-xyz
  [ "$status" -eq 1 ]
}
