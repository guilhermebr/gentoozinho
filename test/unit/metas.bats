#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "all four metas exist with metadata.xml" {
  for m in base desktop dev apps; do
    [ -f "$REPO/gentoozinho-meta/$m/$m-0.ebuild" ]
    [ -f "$REPO/gentoozinho-meta/$m/metadata.xml" ]
  done
}

@test "metas are EAPI 8 metapackages keyworded ~amd64" {
  for f in "$REPO"/gentoozinho-meta/*/*.ebuild; do
    grep -qx 'EAPI=8' "$f"
    grep -qx 'LICENSE="metapackage"' "$f"
    grep -qx 'SLOT="0"' "$f"
    grep -qx 'KEYWORDS="~amd64"' "$f"
    run ! grep -q '^SRC_URI=' "$f"
    bash -n "$f"
  done
}

@test "desktop and dev depend on base; nothing depends on a concrete kernel" {
  grep -q 'gentoozinho-meta/base' "$REPO/gentoozinho-meta/desktop/desktop-0.ebuild"
  grep -q 'gentoozinho-meta/base' "$REPO/gentoozinho-meta/dev/dev-0.ebuild"
  grep -q 'virtual/dist-kernel' "$REPO/gentoozinho-meta/desktop/desktop-0.ebuild"
  run ! grep -rq 'sys-kernel/gentoo-kernel' "$REPO/gentoozinho-meta"
}

@test "RDEPEND atoms are sorted and unique within each ebuild" {
  for f in "$REPO"/gentoozinho-meta/*/*.ebuild; do
    atoms="$(sed -n '/^RDEPEND="/,/^"/p' "$f" | grep -E '^\s+[a-z0-9-]+/' | sed 's/^\s*//')"
    [ "$atoms" = "$(printf '%s\n' "$atoms" | sort -u)" ]
  done
}

@test "apps ships firefox-bin, never chromium (last-rited in ::gentoo on 2026-09-24)" {
  grep -q 'www-client/firefox-bin' "$REPO/gentoozinho-meta/apps/apps-0.ebuild"
  run ! grep -rq 'www-client/chromium' "$REPO/gentoozinho-meta"
}

@test "DESCRIPTION fits pkgcheck's 80 character limit" {
  for f in "$REPO"/gentoozinho-meta/*/*.ebuild "$REPO"/app-misc/*/*.ebuild; do
    d="$(sed -n 's/^DESCRIPTION="\([^"]*\)"/\1/p' "$f")"
    [ "${#d}" -le 80 ]
  done
}

@test "base meta provides sudo for gentoozinho-update (review I4)" {
  grep -qx $'\tapp-admin/sudo' "$REPO/gentoozinho-meta/base/base-0.ebuild"
}
