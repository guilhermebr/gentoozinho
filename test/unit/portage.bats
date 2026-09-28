#!/usr/bin/env bats

setup() {
  GZ_ROOT="$(mktemp -d)"; export GZ_ROOT
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../../install/lib/all.sh"
  ETC="$GZ_ROOT/etc/portage"
}
teardown() { rm -rf "$GZ_ROOT"; }

fingerprint() { (cd "$GZ_ROOT" && find etc -type f | sort | xargs md5sum); }

@test "gz_profile_family: no-multilib is vm, anything else is desktop" {
  [ "$(gz_profile_family ../../var/db/repos/gentoo/profiles/default/linux/amd64/23.0/no-multilib/systemd)" = vm ]
  [ "$(gz_profile_family ../../var/db/repos/gentoo/profiles/default/linux/amd64/23.0/desktop/systemd)" = desktop ]
  [ "$(gz_profile_family ../../var/db/repos/gentoo/profiles/default/linux/amd64/23.0/systemd)" = desktop ]
}

@test "gz_profile_family recognises our own profiles after the first run (review C1)" {
  [ "$(gz_profile_family ../../var/db/repos/gentoozinho/profiles/vm)" = vm ]
  [ "$(gz_profile_family ../../var/db/repos/gentoozinho/profiles/desktop)" = desktop ]
}

@test "gz_write_portage_config dies clearly when package.accept_keywords is a file (review I2)" {
  mkdir -p "$ETC"
  printf 'sys-apps/foo ~amd64\n' > "$ETC/package.accept_keywords"
  run gz_write_portage_config 4 8192
  [ "$status" -eq 1 ]
  [[ "$output" == *"package.accept_keywords is a file"* ]]
}

@test "gz_write_portage_config leaves an existing MAKEOPTS alone (review I3)" {
  mkdir -p "$ETC"
  printf 'MAKEOPTS="-j16"\n' > "$ETC/make.conf"
  gz_write_portage_config 4 8192 > /dev/null
  run ! grep -q '^MAKEOPTS=' "$ETC/gentoozinho.conf"
  rm "$ETC/make.conf" "$ETC/gentoozinho.conf"
  gz_write_portage_config 4 8192 > /dev/null
  grep -q '^MAKEOPTS="-j4 -l4"' "$ETC/gentoozinho.conf"
}

@test "gz_current_profile reads the make.profile symlink" {
  mkdir -p "$ETC"
  ln -s ../../var/db/repos/gentoo/profiles/default/linux/amd64/23.0/no-multilib/systemd "$ETC/make.profile"
  [ "$(gz_current_profile)" = ../../var/db/repos/gentoo/profiles/default/linux/amd64/23.0/no-multilib/systemd ]
}

@test "gz_makeopts uses min(ncpu, mem/2GB), at least 1" {
  [ "$(gz_makeopts 16 8192)" = "-j4 -l4" ]
  [ "$(gz_makeopts 2 30000)" = "-j2 -l2" ]
  [ "$(gz_makeopts 4 1024)" = "-j1 -l1" ]
}

@test "gz_write_portage_config writes owned files and is idempotent" {
  gz_write_portage_config 4 8192 > /dev/null
  a="$(fingerprint)"
  gz_write_portage_config 4 8192 > /dev/null
  [ "$a" = "$(fingerprint)" ]
  grep -qx '\*/\*::hyproverlay ~amd64' "$ETC/package.accept_keywords/gentoozinho"
  grep -qx '\*/\*::gentoozinho ~amd64' "$ETC/package.accept_keywords/gentoozinho"
  grep -qx 'gui-apps/uwsm ~amd64' "$ETC/package.accept_keywords/gentoozinho"
  grep -qx 'dev-cpp/sdbus-c++ ~amd64' "$ETC/package.accept_keywords/gentoozinho"
  grep -qx 'app-shells/zoxide ~amd64' "$ETC/package.accept_keywords/gentoozinho"
  grep -q 'linux-firmware @BINARY-REDISTRIBUTABLE' "$ETC/package.license/gentoozinho"
  grep -q 'getbinpkg' "$ETC/gentoozinho.conf"
  grep -q 'MAKEOPTS="-j4 -l4"' "$ETC/gentoozinho.conf"
  [ "$(grep -c 'source /etc/portage/gentoozinho.conf' "$ETC/make.conf")" -eq 1 ]
}

@test "gz_write_portage_config adds a binhost only when none is configured" {
  gz_write_portage_config 4 8192 > /dev/null
  grep -q "sync-uri = $GZ_BINHOST_URI" "$ETC/binrepos.conf/gentoozinho.conf"
}

@test "gz_write_portage_config keeps an existing binhost (cloud image ships one)" {
  mkdir -p "$ETC/binrepos.conf"
  printf '[gentoo]\npriority = 1\nsync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64\n' > "$ETC/binrepos.conf/gentoo.conf"
  gz_write_portage_config 4 8192 > /dev/null
  [ ! -e "$ETC/binrepos.conf/gentoozinho.conf" ]
}

@test "gz_write_portage_config handles make.conf as a directory" {
  mkdir -p "$ETC/make.conf"
  printf 'CFLAGS="-O2"\n' > "$ETC/make.conf/00-flags"
  gz_write_portage_config 4 8192 > /dev/null
  grep -qx 'source /etc/portage/gentoozinho.conf' "$ETC/make.conf/zz-gentoozinho"
}

@test "gz_tree_needs_sync: webrsync when no tree, sync when stale, fresh when recent" {
  [ "$(gz_tree_needs_sync)" = webrsync ]
  mkdir -p "$GZ_ROOT/var/db/repos/gentoo/metadata"
  touch -t 202001010000 "$GZ_ROOT/var/db/repos/gentoo/metadata/timestamp.chk"
  [ "$(gz_tree_needs_sync)" = sync ]
  touch "$GZ_ROOT/var/db/repos/gentoo/metadata/timestamp.chk"
  [ "$(gz_tree_needs_sync)" = fresh ]
}
