#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  GZ_ROOT="$(mktemp -d)"; export GZ_ROOT
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../../install/lib/all.sh"
}
teardown() { rm -rf "$GZ_ROOT"; }

@test "gz_ensure_line creates the file and appends the line once" {
  f="$GZ_ROOT/etc/portage/make.conf"
  gz_ensure_line "$f" 'source /etc/portage/gentoozinho.conf'
  gz_ensure_line "$f" 'source /etc/portage/gentoozinho.conf'
  [ "$(grep -c 'gentoozinho.conf' "$f")" -eq 1 ]
}

@test "gz_ensure_line keeps existing content" {
  f="$GZ_ROOT/make.conf"
  printf 'CFLAGS="-O2"\n' > "$f"
  gz_ensure_line "$f" 'FEATURES="getbinpkg"'
  [ "$(sed -n 1p "$f")" = 'CFLAGS="-O2"' ]
  [ "$(sed -n 2p "$f")" = 'FEATURES="getbinpkg"' ]
}

@test "gz_ensure_line first terminates a file that lacks a trailing newline (review I6)" {
  f="$GZ_ROOT/make.conf"
  printf 'USE="foo"' > "$f"
  gz_ensure_line "$f" 'source /etc/portage/gentoozinho.conf'
  [ "$(sed -n 1p "$f")" = 'USE="foo"' ]
  [ "$(sed -n 2p "$f")" = 'source /etc/portage/gentoozinho.conf' ]
}

@test "gz_write_file reports changed, then unchanged, then changed" {
  f="$GZ_ROOT/a/b/file"
  [ "$(printf 'one\n' | gz_write_file "$f")" = changed ]
  [ "$(printf 'one\n' | gz_write_file "$f")" = unchanged ]
  [ "$(printf 'two\n' | gz_write_file "$f")" = changed ]
  [ "$(cat "$f")" = two ]
}

@test "gz_die logs and exits 1" {
  run gz_die "boom"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: boom"* ]]
}
