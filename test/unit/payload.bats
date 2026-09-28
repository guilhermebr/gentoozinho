#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "app-misc is a listed category and the live ebuild exists" {
  grep -qx 'app-misc' "$REPO/profiles/categories"
  [ -f "$REPO/app-misc/gentoozinho/gentoozinho-9999.ebuild" ]
  [ -f "$REPO/app-misc/gentoozinho/metadata.xml" ]
}

@test "live ebuild uses git-r3 on the project repo and installs the payload dirs" {
  f="$REPO/app-misc/gentoozinho/gentoozinho-9999.ebuild"
  grep -qx 'EAPI=8' "$f"
  grep -q 'inherit git-r3' "$f"
  grep -q 'EGIT_REPO_URI="https://github.com/guilhermebr/gentoozinho.git"' "$f"
  grep -q 'insinto /usr/share/gentoozinho' "$f"
  grep -q 'doins -r default themes config' "$f"
  grep -q 'dobin bin/\*' "$f"
  grep -q 'wayland-sessions' "$f"
  bash -n "$f"
}

@test "desktop meta pulls the payload" {
  grep -qx $'\tapp-misc/gentoozinho' "$REPO/gentoozinho-meta/desktop/desktop-0.ebuild"
}

@test "session file starts Hyprland through uwsm" {
  f="$REPO/default/wayland-sessions/gentoozinho.desktop"
  grep -q '^Name=gentoozinho' "$f"
  grep -q '^Exec=uwsm start -g -1 -e -D Hyprland hyprland.desktop$' "$f"
  grep -q '^TryExec=uwsm$' "$f"
}

@test "every bin script is executable bash with the expected shebang" {
  ls "$REPO"/bin/gentoozinho-* > /dev/null
  for f in "$REPO"/bin/gentoozinho-*; do
    [ -x "$f" ]
    [ "$(head -1 "$f")" = '#!/usr/bin/env bash' ]
    bash -n "$f"
  done
}

@test "lint covers bin scripts" {
  grep -q "bin/gentoozinho-\*" "$REPO/test/lint.sh"
}

@test "a keyworded snapshot ebuild exists beside the live one so stable profiles can solve the desktop meta" {
  f="$(ls "$REPO"/app-misc/gentoozinho/gentoozinho-0.*.ebuild | head -1)"
  [ -n "$f" ]
  grep -qx 'KEYWORDS="~amd64"' "$f"
  grep -q 'SRC_URI="https://github.com/guilhermebr/gentoozinho/archive/refs/tags/' "$f"
  grep -q 'insinto /usr/share/gentoozinho' "$f"
  bash -n "$f"
}
