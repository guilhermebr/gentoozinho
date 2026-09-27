# gentoozinho Phase 1: Overlay and Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fresh Gentoo systemd system becomes a machine with the whole Hyprland stack merged, the gentoozinho profile selected, and services enabled, by running `install.sh` once; proven end to end in a govm VM.

**Architecture:** The repo root is a Gentoo ebuild repository (overlay) holding custom profiles and four meta-packages. A bash installer with a small function library writes the `/etc/portage` files the profiles cannot carry, adds the `guru`, `hyproverlay` and `gentoozinho` repos, selects the profile and emerges the metas. Library functions take every path under `${GZ_ROOT}` so unit tests run against a temp dir on the host; the real thing is verified by a govm smoke test.

**Tech Stack:** bash 5, Portage (EAPI 8 ebuilds, EAPI 5 profiles, `profile-formats = portage-2`), eselect-repository, Gentoo official binhost, bats (via `bats/bats` docker image), shellcheck (via `koalaman/shellcheck` docker image), govm + QEMU/KVM + OVMF.

**Spec:** `docs/superpowers/specs/2026-09-27-gentoozinho-design.md` (sections 4 to 10; phase 1 covers installer stages preflight, portage, packages, finish).

## Global Constraints

- systemd only; the installer must refuse to run when PID 1 is not `systemd`.
- amd64 only; refuse on any other `uname -m`.
- Ebuilds are `EAPI=8`. Profile directories declare `eapi` `5`. `metadata/layout.conf` sets `masters = gentoo`, `thin-manifests = true`, `profile-formats = portage-2`.
- Meta-packages have `LICENSE="metapackage"`, `SLOT="0"`, `KEYWORDS="~amd64"`, no `SRC_URI`, so they need no `Manifest`.
- Profiles are `gentoozinho:base` (shared), `gentoozinho:vm` (parent `gentoo:default/linux/amd64/23.0/no-multilib/systemd`) and `gentoozinho:desktop` (parent `gentoo:default/linux/amd64/23.0/desktop/systemd`).
- Every file the installer writes under `/etc/portage` is named `gentoozinho` or `gentoozinho.conf`, and writing it twice changes nothing.
- All shell is `bash` with `set -euo pipefail`, passes `shellcheck -x -s bash` with zero findings, and every library function is prefixed `gz_`.
- All library paths are prefixed with `${GZ_ROOT:-}` so tests can run unprivileged.
- `gui-wm/hyprland` needs gcc 15 or newer; preflight checks it.
- Binhost URI (verified in the cloud image): `https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64`.
- Kernel dependency is `virtual/dist-kernel`, never a concrete kernel package (the cloud image ships `sys-kernel/gentoo-kernel`; metal will use `gentoo-kernel-bin`).
- Commit messages are a single line, no body, no attribution trailer.
- Facts about the Gentoo cloud image verified 2026-09-27 by booting it: no ebuild tree present (`/var/db/repos/gentoo` missing), no `git`, no `eselect-repository`, gcc 15.3.0, user `gentoo` with passwordless sudo and home `/home/gentoo`, `/etc/portage/package.*` are directories, `/etc/portage/make.conf` is a file, `/etc/portage/binrepos.conf/gentoo.conf` already defines section `[gentoo]` with the binhost above and `verify-signature = true`, `FEATURES="binpkg-request-signature"` already set, root fs xfs 20G with 17G free, kernel `sys-kernel/gentoo-kernel-6.18.50`, bootloader grub on a vfat `/boot`. The image is EFI-only: it does not boot under SeaBIOS, govm must use OVMF for it.

## Review Focus

1. `/etc/portage/make.conf` is a directory on some systems; the installer must write `make.conf/zz-gentoozinho` instead of failing. Test in Task 5.
2. A binhost is already configured (the cloud image ships `[gentoo]`); the installer must not add a second one. Test in Task 5.
3. `--repo-url` points at a local directory with or without trailing slash; the repo must land at `/var/db/repos/gentoozinho` with a working `repos.conf` and no `sync-uri`. Test in Task 6 (kind detection) and Task 9 (real use).
4. A flag given without its value (`--profile` at end of argv) must produce a clear error, not an unbound-variable trace. Test in Task 6.
5. No ebuild tree present at all (fresh cloud image): the sync step must use `emerge-webrsync` rather than fail on a missing `timestamp.chk`. Test in Task 7 (function) and Task 9 (real).

---

## File structure

```
metadata/layout.conf                     overlay identity and formats
profiles/repo_name                       "gentoozinho"
profiles/categories                      "gentoozinho-meta"
profiles/eapi                            "5"
profiles/profiles.desc                   registers vm and desktop
profiles/base/{eapi,make.defaults,package.use}
profiles/vm/{eapi,parent}
profiles/desktop/{eapi,parent}
gentoozinho-meta/{base,desktop,dev,apps}/{<name>-0.ebuild,metadata.xml}
install.sh                               entry point: args, logging, runs stage steps in order
install/lib/all.sh                       sources the other lib files
install/lib/log.sh                       gz_log, gz_die
install/lib/fs.sh                        gz_ensure_line, gz_write_file
install/lib/checks.sh                    gz_check_* preflight predicates
install/lib/args.sh                      gz_parse_args, gz_meta_atoms, gz_repo_kind, gz_usage
install/lib/portage.sh                   gz_profile_family, gz_current_profile, gz_target_profile,
                                         gz_makeopts, gz_write_portage_config, gz_tree_needs_sync
install/preflight/10-checks.sh
install/portage/10-sync.sh
install/portage/20-tools.sh
install/portage/30-repos.sh
install/portage/40-config.sh
install/portage/50-profile.sh
install/packages/10-emerge.sh
install/finish/10-summary.sh
test/unit.sh                             runs bats in docker
test/lint.sh                             runs shellcheck in docker
test/unit/*.bats                         unit tests per lib file plus overlay structure
test/vm-smoke.sh                         govm end-to-end
docs/learning/01-portage-profiles-overlays.md
README.md, LICENSE, .gitignore
```

Steps are sourced, not executed, by `install.sh`, so they share the environment and library functions; `install.sh` redirects all output to the log with `exec > >(tee -a "$GZ_LOG_FILE") 2>&1`.

---

### Task 1: Overlay skeleton, README, lint and unit test runners

**Files:**
- Create: `metadata/layout.conf`, `profiles/repo_name`, `profiles/categories`, `profiles/eapi`
- Create: `README.md`, `LICENSE`, `.gitignore`
- Create: `test/unit.sh`, `test/lint.sh`, `test/unit/overlay.bats`

**Interfaces:**
- Produces: `test/unit.sh` (runs all `test/unit/*.bats`), `test/lint.sh` (shellcheck over all shell). Every later task ends by running both.

- [ ] **Step 1: Write the failing overlay structure test**

`test/unit/overlay.bats`:

```bash
#!/usr/bin/env bats
# Structural checks on the ebuild repository. Real validation happens in the
# VM smoke test; these catch typos before a VM is ever booted.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
}

@test "layout.conf declares the repo and formats" {
  grep -qx 'masters = gentoo' "$REPO/metadata/layout.conf"
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
```

- [ ] **Step 2: Write the runners**

`test/unit.sh`:

```bash
#!/usr/bin/env bash
# Run the bats unit tests inside the official bats image (bats is not on the host).
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm -v "$PWD:/code" -w /code bats/bats:1.14.0 "${@:-test/unit}"
```

`test/lint.sh`:

```bash
#!/usr/bin/env bash
# shellcheck every shell file in the repo using the official image.
set -euo pipefail
cd "$(dirname "$0")/.."
# -co: tracked and untracked (not ignored), so new files are linted before they are added.
mapfile -t files < <(git ls-files -co --exclude-standard '*.sh' install.sh | sort -u)
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable -x -s bash "${files[@]}"
```

`chmod +x test/unit.sh test/lint.sh`.

- [ ] **Step 3: Run the test to verify it fails**

Run: `test/unit.sh`
Expected: FAIL, `layout.conf declares the repo and formats` cannot find the file.

- [ ] **Step 4: Write the overlay files**

`metadata/layout.conf`:

```
masters = gentoo
repo-name = gentoozinho
thin-manifests = true
sign-manifests = false
sign-commits = false
profile-formats = portage-2
cache-formats = md5-dict
manifest-hashes = BLAKE2B SHA512
manifest-required-hashes = BLAKE2B
```

`profiles/repo_name`: `gentoozinho`
`profiles/categories`: `gentoozinho-meta`
`profiles/eapi`: `5`

`.gitignore`:

```
metadata/md5-cache/
*.log
```

`LICENSE`: the MIT license text with `Copyright (c) 2026 Guilherme` on the copyright line.

`README.md`:

```markdown
# gentoozinho

An opinionated Hyprland desktop for Gentoo, installed the Gentoo way: a real
ebuild repository with its own profiles and meta-packages, plus one bootstrap
script. Inspired by [Omarchy](https://omarchy.org).

gentoozinho is an unofficial community project. It is not affiliated with or
endorsed by Gentoo Linux or the Gentoo Foundation. Gentoo is a trademark of
the Gentoo Foundation, Inc. See <https://www.gentoo.org>.

## Status

Phase 1: overlay, profiles, meta-packages and installer. Tested against the
official Gentoo cloud-init image in a govm VM. See
`docs/superpowers/specs/2026-09-27-gentoozinho-design.md` for the design.

## Install

On a systemd Gentoo (amd64) with network, as root:

    git clone https://github.com/guilhermebr/gentoozinho.git
    cd gentoozinho
    ./install.sh

Flags: `--profile vm|desktop`, `--user NAME`, `--metas base,desktop,dev,apps`,
`--no-reboot`, `--repo-url URL_OR_DIR`.

## Develop

    test/unit.sh        # bats unit tests (docker)
    test/lint.sh        # shellcheck (docker)
    test/vm-smoke.sh    # full install in a govm VM (needs govm, KVM, OVMF)

## License

MIT.
```

- [ ] **Step 5: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: 4 tests pass; shellcheck prints nothing and exits 0.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add overlay skeleton, README and test runners"
```

---

### Task 2: Profiles

**Files:**
- Create: `profiles/profiles.desc`, `profiles/base/eapi`, `profiles/base/make.defaults`, `profiles/base/package.use`, `profiles/vm/eapi`, `profiles/vm/parent`, `profiles/desktop/eapi`, `profiles/desktop/parent`
- Test: `test/unit/profiles.bats`

**Interfaces:**
- Produces: profile names `vm` and `desktop`, selected as `gentoozinho:vm` / `gentoozinho:desktop` by Task 7.

- [ ] **Step 1: Write the failing test**

`test/unit/profiles.bats`:

```bash
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

@test "vm inherits the no-multilib systemd profile and base" {
  [ "$(sed -n 1p "$REPO/profiles/vm/parent")" = 'gentoo:default/linux/amd64/23.0/no-multilib/systemd' ]
  [ "$(sed -n 2p "$REPO/profiles/vm/parent")" = '../base' ]
}

@test "desktop inherits the desktop systemd profile and base" {
  [ "$(sed -n 1p "$REPO/profiles/desktop/parent")" = 'gentoo:default/linux/amd64/23.0/desktop/systemd' ]
  [ "$(sed -n 2p "$REPO/profiles/desktop/parent")" = '../base' ]
}

@test "base sets the shared USE defaults" {
  grep -q '^USE=".*wayland' "$REPO/profiles/base/make.defaults"
  grep -q '^USE=".*pipewire' "$REPO/profiles/base/make.defaults"
  grep -q '^USE=".*dist-kernel' "$REPO/profiles/base/make.defaults"
}

@test "base pins hyprland to systemd and uwsm" {
  grep -qE '^gui-wm/hyprland .*systemd' "$REPO/profiles/base/package.use"
  grep -qE '^gui-wm/hyprland .*uwsm' "$REPO/profiles/base/package.use"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/profiles.bats`
Expected: FAIL on the first test, file missing.

- [ ] **Step 3: Write the profile files**

`profiles/profiles.desc` (tab separated, like `::gentoo`):

```
amd64	vm	exp
amd64	desktop	exp
```

`profiles/base/eapi`, `profiles/vm/eapi`, `profiles/desktop/eapi`: each contains `5`.

`profiles/base/make.defaults`:

```
# Shared USE defaults for every gentoozinho profile. Per-package flags live in
# package.use; anything the profile cannot carry is written to /etc/portage by
# install.sh.
USE="wayland pipewire vulkan bluetooth networkmanager dist-kernel"
```

`profiles/base/package.use`:

```
# Hyprland: systemd integration and the uwsm session wrapper; hyprpm needs a
# compiler toolchain at runtime and is not used by gentoozinho.
gui-wm/hyprland systemd uwsm -hyprpm
# PipeWire replaces PulseAudio.
media-video/pipewire sound-server
# Portals on Wayland.
sys-apps/xdg-desktop-portal-gtk wayland
```

`profiles/vm/parent`:

```
gentoo:default/linux/amd64/23.0/no-multilib/systemd
../base
```

`profiles/desktop/parent`:

```
gentoo:default/linux/amd64/23.0/desktop/systemd
../base
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add profiles test/unit/profiles.bats
git commit -m "Add base, vm and desktop profiles"
```

---

### Task 3: Meta-packages

**Files:**
- Create: `gentoozinho-meta/base/base-0.ebuild`, `gentoozinho-meta/base/metadata.xml`
- Create: `gentoozinho-meta/desktop/desktop-0.ebuild`, `gentoozinho-meta/desktop/metadata.xml`
- Create: `gentoozinho-meta/dev/dev-0.ebuild`, `gentoozinho-meta/dev/metadata.xml`
- Create: `gentoozinho-meta/apps/apps-0.ebuild`, `gentoozinho-meta/apps/metadata.xml`
- Test: `test/unit/metas.bats`

**Interfaces:**
- Produces: atoms `gentoozinho-meta/base`, `gentoozinho-meta/desktop`, `gentoozinho-meta/dev`, `gentoozinho-meta/apps`, consumed by `gz_meta_atoms` (Task 6) and `install/packages/10-emerge.sh` (Task 8).

Phase 1 deliberately leaves `app-misc/gum` and `app-misc/gentoozinho` out of `base`, and `dev-util/mise`, `app-containers/lazydocker`, `net-misc/localsend` out of `dev`/`apps`: those ebuilds are phase 2 work.

- [ ] **Step 1: Write the failing test**

`test/unit/metas.bats`:

```bash
#!/usr/bin/env bats

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
    ! grep -q '^SRC_URI=' "$f"
    bash -n "$f"
  done
}

@test "desktop and dev depend on base; nothing depends on a concrete kernel" {
  grep -q 'gentoozinho-meta/base' "$REPO/gentoozinho-meta/desktop/desktop-0.ebuild"
  grep -q 'gentoozinho-meta/base' "$REPO/gentoozinho-meta/dev/dev-0.ebuild"
  grep -q 'virtual/dist-kernel' "$REPO/gentoozinho-meta/desktop/desktop-0.ebuild"
  ! grep -rq 'sys-kernel/gentoo-kernel' "$REPO/gentoozinho-meta"
}

@test "RDEPEND atoms are sorted and unique within each ebuild" {
  for f in "$REPO"/gentoozinho-meta/*/*.ebuild; do
    atoms="$(sed -n '/^RDEPEND="/,/^"/p' "$f" | grep -E '^\s+[a-z0-9-]+/' | sed 's/^\s*//')"
    [ "$atoms" = "$(printf '%s\n' "$atoms" | sort -u)" ]
  done
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/metas.bats`
Expected: FAIL, ebuilds missing.

- [ ] **Step 3: Write the ebuilds**

Every `metadata.xml` is:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE pkgmetadata SYSTEM "https://www.gentoo.org/dtd/metadata.dtd">
<pkgmetadata>
	<maintainer type="person">
		<email>guilhermebr@gmail.com</email>
	</maintainer>
	<upstream>
		<remote-id type="github">guilhermebr/gentoozinho</remote-id>
	</upstream>
</pkgmetadata>
```

`gentoozinho-meta/base/base-0.ebuild`:

```bash
# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho base: shell and command-line tools"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-editors/neovim
	app-misc/fastfetch
	app-misc/jq
	app-misc/tmux
	app-shells/fzf
	app-shells/starship
	app-shells/zoxide
	dev-vcs/git
	dev-vcs/lazygit
	sys-apps/bat
	sys-apps/eza
	sys-apps/fd
	sys-apps/ripgrep
	sys-process/btop
"
```

`gentoozinho-meta/desktop/desktop-0.ebuild`:

```bash
# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho desktop: Hyprland session, bar, launcher, portals, audio, network, fonts"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-misc/brightnessctl
	gentoozinho-meta/base
	gnome-base/nautilus
	gui-apps/grim
	gui-apps/hypridle
	gui-apps/hyprlock
	gui-apps/hyprpaper
	gui-apps/hyprpicker
	gui-apps/hyprshot
	gui-apps/mako
	gui-apps/slurp
	gui-apps/swayosd
	gui-apps/uwsm
	gui-apps/walker
	gui-apps/waybar
	gui-apps/wl-clipboard
	gui-libs/xdg-desktop-portal-hyprland
	gui-wm/hyprland
	media-fonts/jetbrains-mono
	media-fonts/noto
	media-fonts/noto-cjk
	media-fonts/noto-emoji
	media-fonts/symbols-nerd-font
	media-sound/pamixer
	media-video/pipewire
	media-video/wireplumber
	net-misc/networkmanager
	net-wireless/bluez
	sys-apps/xdg-desktop-portal-gtk
	sys-kernel/installkernel
	virtual/dist-kernel
	x11-misc/sddm
	x11-terms/alacritty
"
```

`gentoozinho-meta/dev/dev-0.ebuild`:

```bash
# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho dev: containers and developer tooling"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-containers/docker
	app-containers/docker-buildx
	app-containers/docker-compose
	gentoozinho-meta/base
"
```

`gentoozinho-meta/apps/apps-0.ebuild`:

```bash
# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho apps: browser, office, media viewers"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-office/libreoffice-bin
	app-text/evince
	media-gfx/imv
	media-video/mpv
	www-client/chromium
"
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add gentoozinho-meta test/unit/metas.bats
git commit -m "Add base, desktop, dev and apps meta-packages"
```

---

### Task 4: Installer library: logging and idempotent file helpers

**Files:**
- Create: `install/lib/all.sh`, `install/lib/log.sh`, `install/lib/fs.sh`
- Test: `test/unit/fs.bats`

**Interfaces:**
- Produces: `gz_log MSG...` (stderr), `gz_die MSG...` (logs, exit 1), `gz_ensure_line FILE LINE` (append once), `gz_write_file FILE < content` (prints `changed` or `unchanged`).
- `install/lib/all.sh` is the single file every script sources; later tasks add lines to it.

- [ ] **Step 1: Write the failing test**

`test/unit/fs.bats`:

```bash
#!/usr/bin/env bats

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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/fs.bats`
Expected: FAIL, `all.sh` not found.

- [ ] **Step 3: Write the library**

`install/lib/log.sh`:

```bash
# shellcheck shell=bash
# Logging. install.sh already tees all output to the log file, so these only
# need to write to stderr with a recognisable prefix.

GZ_LOG_FILE="${GZ_LOG_FILE:-${GZ_ROOT:-}/var/log/gentoozinho/install.log}"

gz_log() {
  printf '%s [gentoozinho] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

gz_die() {
  gz_log "ERROR: $*"
  exit 1
}
```

`install/lib/fs.sh`:

```bash
# shellcheck shell=bash
# Idempotent file helpers. Callers pass full paths, already prefixed with
# "${GZ_ROOT}" so unit tests can run against a scratch directory.

# gz_ensure_line FILE LINE: append LINE unless an identical line exists.
gz_ensure_line() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : > "$file"
  grep -qxF -- "$line" "$file" && return 0
  printf '%s\n' "$line" >> "$file"
}

# gz_write_file FILE < content: write stdin to FILE only if it differs.
# Prints "changed" or "unchanged" so callers and tests can tell.
gz_write_file() {
  local file="$1" tmp
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  cat > "$tmp"
  if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    echo unchanged
    return 0
  fi
  install -m 0644 "$tmp" "$file"
  rm -f "$tmp"
  echo changed
}
```

`install/lib/all.sh`:

```bash
# shellcheck shell=bash
# Source every library file. GZ_LIB is the directory of this file.
GZ_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib/log.sh
source "${GZ_LIB}/log.sh"
# shellcheck source=install/lib/fs.sh
source "${GZ_LIB}/fs.sh"
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass, shellcheck clean.

- [ ] **Step 5: Commit**

```bash
git add install/lib test/unit/fs.bats
git commit -m "Add installer logging and idempotent file helpers"
```

---

### Task 5: Installer library: portage configuration

**Files:**
- Create: `install/lib/portage.sh`
- Modify: `install/lib/all.sh` (add a source line)
- Test: `test/unit/portage.bats`

**Interfaces:**
- Consumes: `gz_write_file`, `gz_ensure_line` (Task 4).
- Produces: `gz_profile_family PROFILE_PATH` → `vm|desktop`; `gz_current_profile` → readlink of `${GZ_ROOT}/etc/portage/make.profile`; `gz_makeopts NCPU MEM_MB` → `-jN -lN`; `gz_write_portage_config NCPU MEM_MB` (writes all owned files); `gz_tree_needs_sync` → prints `webrsync`, `sync` or `fresh`; constant `GZ_BINHOST_URI`.

- [ ] **Step 1: Write the failing test**

`test/unit/portage.bats`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/portage.bats`
Expected: FAIL, `gz_profile_family: command not found`.

- [ ] **Step 3: Write the library**

`install/lib/portage.sh`:

```bash
# shellcheck shell=bash
# Portage configuration owned by gentoozinho. Everything lands under
# "${GZ_ROOT}/etc/portage"; unit tests point GZ_ROOT at a temp dir.

GZ_BINHOST_URI="https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64"

# gz_profile_family PROFILE_PATH -> vm | desktop
# The cloud image is no-multilib; everything else is treated as a multilib desktop.
gz_profile_family() {
  case "$1" in
    *no-multilib*) echo vm ;;
    *) echo desktop ;;
  esac
}

# gz_current_profile -> target of the make.profile symlink
gz_current_profile() {
  readlink "${GZ_ROOT:-}/etc/portage/make.profile"
}

# gz_target_profile -> vm | desktop, honouring an explicit --profile
gz_target_profile() {
  if [[ "${GZ_PROFILE:-auto}" == auto ]]; then
    gz_profile_family "$(gz_current_profile)"
  else
    echo "$GZ_PROFILE"
  fi
}

# gz_makeopts NCPU MEM_MB -> "-jN -lN", N = min(ncpu, mem_mb/2048), at least 1.
# Gentoo's rule of thumb is about 2 GB of RAM per compile job.
gz_makeopts() {
  local ncpu="$1" mem_mb="$2" jobs
  jobs=$(( mem_mb / 2048 ))
  (( jobs > ncpu )) && jobs=$ncpu
  (( jobs < 1 )) && jobs=1
  echo "-j${jobs} -l${jobs}"
}

# gz_tree_needs_sync -> webrsync (no tree), sync (older than a day), fresh
gz_tree_needs_sync() {
  local ts="${GZ_ROOT:-}/var/db/repos/gentoo/metadata/timestamp.chk"
  if [[ ! -f "$ts" ]]; then
    echo webrsync
  elif (( $(date +%s) - $(stat -c %Y "$ts") > 86400 )); then
    echo sync
  else
    echo fresh
  fi
}

# gz_write_portage_config NCPU MEM_MB: write every /etc/portage file we own.
gz_write_portage_config() {
  local ncpu="$1" mem_mb="$2" etc="${GZ_ROOT:-}/etc/portage"

  gz_write_file "$etc/package.accept_keywords/gentoozinho" <<'EOF'
# Managed by gentoozinho. The Hypr stack, GURU and our own overlay are ~amd64 only.
*/*::hyproverlay ~amd64
*/*::gentoozinho ~amd64
*/*::guru ~amd64
EOF

  gz_write_file "$etc/package.license/gentoozinho" <<'EOF'
# Managed by gentoozinho. Firmware and microcode needed by the distribution kernel.
sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE
sys-firmware/intel-microcode intel-ucode
EOF

  gz_write_file "$etc/gentoozinho.conf" <<EOF
# Managed by gentoozinho and sourced from make.conf. Put local overrides in
# make.conf after the source line.
FEATURES="\${FEATURES} getbinpkg binpkg-request-signature"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --binpkg-respect-use=y --jobs=2 --load-average=${ncpu}"
MAKEOPTS="$(gz_makeopts "$ncpu" "$mem_mb")"
ACCEPT_LICENSE="\${ACCEPT_LICENSE} @FREE"
EOF

  if [[ -d "$etc/make.conf" ]]; then
    gz_write_file "$etc/make.conf/zz-gentoozinho" <<'EOF'
source /etc/portage/gentoozinho.conf
EOF
  else
    gz_ensure_line "$etc/make.conf" 'source /etc/portage/gentoozinho.conf'
  fi

  if ! grep -rqs 'binpackages/' "$etc/binrepos.conf"; then
    gz_write_file "$etc/binrepos.conf/gentoozinho.conf" <<EOF
# Managed by gentoozinho. Official Gentoo binary package host for amd64 23.0.
[gentoobinhost]
priority = 1
sync-uri = ${GZ_BINHOST_URI}
EOF
  fi
}
```

Append to `install/lib/all.sh`:

```bash
# shellcheck source=install/lib/portage.sh
source "${GZ_LIB}/portage.sh"
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add install/lib test/unit/portage.bats
git commit -m "Add portage configuration library"
```

---

### Task 6: Installer library: preflight checks and argument parsing

**Files:**
- Create: `install/lib/checks.sh`, `install/lib/args.sh`
- Modify: `install/lib/all.sh`
- Test: `test/unit/checks.bats`, `test/unit/args.bats`

**Interfaces:**
- Consumes: `gz_die` (Task 4).
- Produces: `gz_check_root UID`, `gz_check_arch ARCH`, `gz_check_init COMM`, `gz_check_gcc VERSION`, `gz_check_cmd NAME`, `gz_check_network`; `gz_parse_args "$@"` exporting `GZ_PROFILE GZ_USER GZ_METAS GZ_NO_REBOOT GZ_REPO_URL`; `gz_meta_atoms CSV` → space-separated atoms; `gz_repo_kind URL_OR_DIR` → `local|git`; `gz_usage`.

- [ ] **Step 1: Write the failing tests**

`test/unit/checks.bats`:

```bash
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
```

`test/unit/args.bats`:

```bash
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test/unit.sh test/unit/checks.bats test/unit/args.bats`
Expected: FAIL, functions not found.

- [ ] **Step 3: Write the library**

`install/lib/checks.sh`:

```bash
# shellcheck shell=bash
# Preflight predicates. Each takes its input as an argument so tests can
# exercise them without root, systemd or a real compiler.

gz_check_root() {
  [[ "$1" == 0 ]] || gz_die "run as root (sudo ./install.sh)"
}

gz_check_arch() {
  [[ "$1" == x86_64 ]] || gz_die "gentoozinho supports amd64 only (got $1)"
}

gz_check_init() {
  [[ "$1" == systemd ]] || gz_die "PID 1 is '$1'; gentoozinho requires systemd (OpenRC is not supported)"
}

# gz_check_gcc VERSION (e.g. 15.3.0): gui-wm/hyprland needs gcc 15 or newer.
gz_check_gcc() {
  local major="${1%%.*}"
  (( major >= 15 )) || gz_die "gcc $1 is too old; gui-wm/hyprland needs gcc 15 or newer"
}

gz_check_cmd() {
  command -v "$1" > /dev/null 2>&1 || gz_die "required command not found: $1"
}

gz_check_network() {
  getent hosts distfiles.gentoo.org > /dev/null || gz_die "cannot resolve distfiles.gentoo.org; network is required"
}
```

`install/lib/args.sh`:

```bash
# shellcheck shell=bash
# Command-line parsing. Results are exported as GZ_* so sourced steps see them.

GZ_DEFAULT_REPO_URL="https://github.com/guilhermebr/gentoozinho.git"

gz_usage() {
  cat >&2 <<'EOF'
usage: install.sh [--profile vm|desktop] [--user NAME] [--metas LIST]
                  [--no-reboot] [--repo-url URL_OR_DIR]

  --profile    gentoozinho profile to select (default: detected from the
               current profile; no-multilib -> vm, otherwise desktop)
  --user       login user to create/configure (default: $SUDO_USER or gentoo)
  --metas      comma-separated subset of base,desktop,dev,apps
               (default: base,desktop)
  --no-reboot  do not offer to reboot at the end
  --repo-url   git URL or local directory of the gentoozinho repository
EOF
}

# gz_need_value FLAG COUNT: die if the flag has no value after it.
gz_need_value() {
  (( $2 >= 2 )) || gz_die "$1 needs a value"
}

gz_parse_args() {
  GZ_PROFILE="auto"
  GZ_USER="${SUDO_USER:-gentoo}"
  GZ_METAS="base,desktop"
  GZ_NO_REBOOT=0
  GZ_REPO_URL="$GZ_DEFAULT_REPO_URL"

  while (( $# )); do
    case "$1" in
      --profile)   gz_need_value "$1" $#; GZ_PROFILE="$2"; shift 2 ;;
      --user)      gz_need_value "$1" $#; GZ_USER="$2"; shift 2 ;;
      --metas)     gz_need_value "$1" $#; GZ_METAS="$2"; shift 2 ;;
      --repo-url)  gz_need_value "$1" $#; GZ_REPO_URL="$2"; shift 2 ;;
      --no-reboot) GZ_NO_REBOOT=1; shift ;;
      -h|--help)   gz_usage; exit 0 ;;
      *)           gz_usage; gz_die "unknown argument: $1" ;;
    esac
  done

  case "$GZ_PROFILE" in
    auto|vm|desktop) ;;
    *) gz_die "--profile must be vm or desktop (got $GZ_PROFILE)" ;;
  esac

  local m
  for m in ${GZ_METAS//,/ }; do
    case "$m" in
      base|desktop|dev|apps) ;;
      *) gz_die "unknown meta: $m (choose from base,desktop,dev,apps)" ;;
    esac
  done

  export GZ_PROFILE GZ_USER GZ_METAS GZ_NO_REBOOT GZ_REPO_URL
}

# gz_meta_atoms "base,desktop" -> "gentoozinho-meta/base gentoozinho-meta/desktop"
gz_meta_atoms() {
  local out=() m
  for m in ${1//,/ }; do
    out+=("gentoozinho-meta/$m")
  done
  echo "${out[*]}"
}

# gz_repo_kind URL_OR_DIR -> local if it is an existing directory, else git
gz_repo_kind() {
  if [[ -d "$1" ]]; then echo local; else echo git; fi
}
```

Append to `install/lib/all.sh`:

```bash
# shellcheck source=install/lib/checks.sh
source "${GZ_LIB}/checks.sh"
# shellcheck source=install/lib/args.sh
source "${GZ_LIB}/args.sh"
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add install/lib test/unit/checks.bats test/unit/args.bats
git commit -m "Add preflight checks and argument parsing"
```

---

### Task 7: install.sh and the preflight and portage stages

**Files:**
- Create: `install.sh`, `install/preflight/10-checks.sh`, `install/portage/10-sync.sh`, `install/portage/20-tools.sh`, `install/portage/30-repos.sh`, `install/portage/40-config.sh`, `install/portage/50-profile.sh`
- Test: `test/unit/install_sh.bats`

**Interfaces:**
- Consumes: everything from Tasks 4 to 6.
- Produces: `install.sh` runnable end to end once Task 8 adds the remaining stages; sets `GZ_SRC` (repo dir), `GZ_TARGET_PROFILE`, `GZ_VIRT` for later steps.

- [ ] **Step 1: Write the failing test**

`test/unit/install_sh.bats`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/install_sh.bats`
Expected: FAIL, `install.sh` missing.

- [ ] **Step 3: Write install.sh**

`install.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# gentoozinho installer: turns a systemd Gentoo into a Hyprland desktop.
# Idempotent: re-running converges. Everything is logged to
# /var/log/gentoozinho/install.log.
set -euo pipefail

GZ_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GZ_SRC
export GZ_ROOT="${GZ_ROOT:-}"

# shellcheck source=install/lib/all.sh
source "${GZ_SRC}/install/lib/all.sh"

gz_parse_args "$@"

if [[ "$GZ_LOG_FILE" != /dev/null ]]; then
  mkdir -p "$(dirname "$GZ_LOG_FILE")"
  exec > >(tee -a "$GZ_LOG_FILE") 2>&1
fi

GZ_CURRENT_STEP=""
trap 'gz_log "FAILED in ${GZ_CURRENT_STEP:-startup}; see ${GZ_LOG_FILE}"' ERR

gz_log "gentoozinho install starting (profile=${GZ_PROFILE} metas=${GZ_METAS} user=${GZ_USER})"

for stage in preflight portage packages finish; do
  for step in "${GZ_SRC}/install/${stage}/"[0-9][0-9]-*.sh; do
    GZ_CURRENT_STEP="${step#"${GZ_SRC}/"}"
    gz_log "==> ${GZ_CURRENT_STEP}"
    # shellcheck disable=SC1090
    source "$step"
  done
done

gz_log "done."
```

- [ ] **Step 4: Write the preflight step**

`install/preflight/10-checks.sh`:

```bash
# shellcheck shell=bash
# Refuse early and clearly rather than fail halfway through an emerge.

gz_check_root "$(id -u)"
gz_check_arch "$(uname -m)"
gz_check_init "$(ps -p 1 -o comm=)"
for cmd in emerge eselect gcc rsync; do
  gz_check_cmd "$cmd"
done
gz_check_gcc "$(gcc -dumpfullversion)"
gz_check_network

GZ_TARGET_PROFILE="$(gz_target_profile)"
GZ_VIRT="$(systemd-detect-virt || true)"
export GZ_TARGET_PROFILE GZ_VIRT
gz_log "target profile gentoozinho:${GZ_TARGET_PROFILE}, virtualization: ${GZ_VIRT:-none}"
```

- [ ] **Step 5: Write the portage steps**

`install/portage/10-sync.sh`:

```bash
# shellcheck shell=bash
# The cloud image ships without an ebuild tree at all, so the first run must
# fetch a snapshot (emerge-webrsync); later runs rsync only when stale.

case "$(gz_tree_needs_sync)" in
  webrsync) gz_log "no ebuild tree found, fetching a snapshot"; emerge-webrsync ;;
  sync)     gz_log "ebuild tree older than a day, syncing"; emerge --sync --quiet ;;
  fresh)    gz_log "ebuild tree is fresh, skipping sync" ;;
esac
```

`install/portage/20-tools.sh`:

```bash
# shellcheck shell=bash
# eselect-repository manages repos.conf; git is needed for git-synced overlays.
emerge --noreplace --quiet app-eselect/eselect-repository dev-vcs/git
```

`install/portage/30-repos.sh`:

```bash
# shellcheck shell=bash
# Enable the overlays we depend on and register gentoozinho itself, either as a
# git repo (normal install) or as a copy of a local checkout (tests).

etc="${GZ_ROOT}/etc/portage"

for repo in guru hyproverlay; do
  if grep -qs "^\[${repo}\]" "$etc"/repos.conf/*; then
    gz_log "repo ${repo} already enabled"
  else
    eselect repository enable "$repo"
  fi
done

case "$(gz_repo_kind "$GZ_REPO_URL")" in
  local)
    gz_write_file "$etc/repos.conf/gentoozinho.conf" <<'EOF'
# Managed by gentoozinho (local checkout, not synced).
[gentoozinho]
location = /var/db/repos/gentoozinho
auto-sync = no
EOF
    rsync -a --delete --exclude .git "${GZ_REPO_URL%/}/" "${GZ_ROOT}/var/db/repos/gentoozinho/"
    ;;
  git)
    if grep -qs '^\[gentoozinho\]' "$etc"/repos.conf/*; then
      gz_log "repo gentoozinho already registered"
    else
      eselect repository add gentoozinho git "$GZ_REPO_URL"
    fi
    ;;
esac

emaint sync -r guru
emaint sync -r hyproverlay
if [[ "$(gz_repo_kind "$GZ_REPO_URL")" == git ]]; then
  emaint sync -r gentoozinho
fi
```

`install/portage/40-config.sh`:

```bash
# shellcheck shell=bash
# Keywords, licenses, binhost, FEATURES and MAKEOPTS that profiles cannot carry.
mem_mb="$(awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo)"
gz_write_portage_config "$(nproc)" "$mem_mb"
```

`install/portage/50-profile.sh`:

```bash
# shellcheck shell=bash
# Select gentoozinho:vm or gentoozinho:desktop (see gz_target_profile).
want="gentoozinho:${GZ_TARGET_PROFILE}"
current="$(eselect profile show | sed -n 2p | tr -d '[:space:]')"
if [[ "$current" == "$want" ]]; then
  gz_log "profile already ${want}"
else
  eselect profile set "$want"
fi
```

- [ ] **Step 6: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass. If shellcheck complains about `source "$step"` add `# shellcheck disable=SC1090` above it (already present).

- [ ] **Step 7: Commit**

```bash
git add install.sh install/preflight install/portage test/unit/install_sh.bats
git commit -m "Add install.sh with preflight and portage stages"
```

---

### Task 8: Packages and finish stages

**Files:**
- Create: `install/packages/10-emerge.sh`, `install/finish/10-summary.sh`
- Modify: `test/unit/install_sh.bats` (one more test)

**Interfaces:**
- Consumes: `gz_meta_atoms`, `GZ_METAS`, `GZ_NO_REBOOT`, `GZ_TARGET_PROFILE`.

- [ ] **Step 1: Add the failing test**

Append to `test/unit/install_sh.bats`:

```bash
@test "packages step resolves before it merges and never uses autounmask" {
  f="$REPO/install/packages/10-emerge.sh"
  grep -q 'emerge --pretend' "$f"
  grep -q 'emerge --getbinpkg --keep-going=n' "$f"
  ! grep -q 'autounmask' "$f"
}

@test "finish step never reboots without a tty" {
  grep -q '\[\[ -t 0 \]\]' "$REPO/install/finish/10-summary.sh"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/install_sh.bats`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the steps**

`install/packages/10-emerge.sh`:

```bash
# shellcheck shell=bash
# Resolve first so an unresolvable atom or a missing USE flag fails with
# Portage's own explanation instead of halfway through a build. We do not
# autounmask: a needed flag belongs in profiles/base/package.use, not in a
# machine-local file.

read -ra atoms <<< "$(gz_meta_atoms "$GZ_METAS")"
gz_log "resolving ${atoms[*]}"
emerge --pretend --quiet "${atoms[@]}" || gz_die "dependency resolution failed for ${atoms[*]}"

gz_log "merging ${atoms[*]} (binary packages where available)"
emerge --getbinpkg --keep-going=n --verbose "${atoms[@]}"
```

`install/finish/10-summary.sh`:

```bash
# shellcheck shell=bash
gz_log "gentoozinho installed:"
gz_log "  profile : gentoozinho:${GZ_TARGET_PROFILE}"
gz_log "  metas   : ${GZ_METAS}"
gz_log "  log     : ${GZ_LOG_FILE}"

if (( GZ_NO_REBOOT )); then
  gz_log "reboot skipped (--no-reboot)"
elif [[ -t 0 ]]; then
  read -r -p "Reboot now? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    systemctl reboot
  fi
else
  gz_log "no tty; reboot when convenient"
fi
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add install/packages install/finish test/unit/install_sh.bats
git commit -m "Add packages and finish stages"
```

---

### Task 9: govm smoke test, run for real, fix what breaks

**Files:**
- Create: `test/vm-smoke.sh`
- Modify: whatever the real run reveals (profiles/base/package.use is the most likely).

**Interfaces:**
- Consumes: govm with the `gentoo` catalog entry booting under OVMF (the parallel govm session owns that fix; until it lands, set `GZ_SMOKE_SSH` to reuse a hand-booted VM, see step 3).

Sizing: hyprland and its libraries compile from source. Run the VM with 8 vCPUs and 8 GB so the build takes tens of minutes, not hours. The cloud image has 17 GB free, enough for base and desktop.

- [ ] **Step 1: Write the smoke test**

`test/vm-smoke.sh` (`chmod +x`):

```bash
#!/usr/bin/env bash
# End-to-end: fresh Gentoo VM -> install.sh -> assertions -> second run is a no-op.
# Requires govm, KVM and a govm gentoo entry that boots (OVMF). Set GZ_KEEP_VM=1
# to keep the VM after success. Set GZ_SMOKE_SSH="ssh -p PORT user@host" to run
# against a VM you booted by hand instead of creating one with govm.
set -euo pipefail
cd "$(dirname "$0")/.."

VM="${GZ_SMOKE_VM:-gz-smoke}"
export GOVM_CPUS="${GOVM_CPUS:-8}" GOVM_MEM_MB="${GOVM_MEM_MB:-8192}"

if [[ -n "${GZ_SMOKE_SSH:-}" ]]; then
  vm() { ${GZ_SMOKE_SSH} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"; }
else
  govm status "$VM" > /dev/null 2>&1 || govm create gentoo "$VM"
  vm() { govm ssh "$VM" -- "$@"; }
fi

step() { printf '\n### %s\n' "$*"; }

step "copy working tree into the VM"
tar --exclude=.git -cz . | vm 'rm -rf ~/src && mkdir ~/src && tar xz -C ~/src'

step "first install"
vm 'sudo ~/src/install.sh --profile vm --no-reboot --repo-url "$HOME/src"'

step "assertions"
vm 'eselect profile show | grep -q "gentoozinho:vm"'
vm 'grep -qx gentoozinho-meta/base /var/lib/portage/world'
vm 'grep -qx gentoozinho-meta/desktop /var/lib/portage/world'
vm 'Hyprland --version'
vm 'test -x /usr/bin/sddm && test -x /usr/bin/waybar && test -x /usr/bin/walker'
vm 'grep -qx "source /etc/portage/gentoozinho.conf" /etc/portage/make.conf'
vm 'test "$(ls /etc/portage/binrepos.conf | wc -l)" -eq 1'   # cloud image already had one

step "second run changes nothing under /etc/portage"
before="$(vm 'sudo find /etc/portage -type f -exec md5sum {} + | sort | md5sum')"
vm 'sudo ~/src/install.sh --profile vm --no-reboot --repo-url "$HOME/src"'
after="$(vm 'sudo find /etc/portage -type f -exec md5sum {} + | sort | md5sum')"
[[ "$before" == "$after" ]] || { echo "FAIL: second run modified /etc/portage"; exit 1; }

step "dev and apps metas resolve"
vm 'sudo emerge --pretend --quiet gentoozinho-meta/dev gentoozinho-meta/apps'

step "pkgcheck on the overlay"
vm 'sudo emerge --noreplace --quiet dev-util/pkgcheck && pkgcheck scan -r gentoozinho'

echo
echo "SMOKE OK"
if [[ -z "${GZ_SMOKE_SSH:-}" && -z "${GZ_KEEP_VM:-}" ]]; then
  yes | govm delete "$VM"
fi
```

- [ ] **Step 2: Lint**

Run: `test/lint.sh`
Expected: clean.

- [ ] **Step 3: Boot a VM**

If `govm create gentoo` boots to SSH, use it. Otherwise boot the cached image by hand with OVMF (this is exactly what was done to inspect the image):

```bash
S=/tmp/gz-smoke; mkdir -p "$S"
qemu-img create -q -f qcow2 -b ~/.govm/images/gentoo.qcow2 -F qcow2 "$S/disk.qcow2"
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$S/vars.fd"
# reuse any govm seed.iso (ssh key + user gentoo), e.g. from a previous VM dir
qemu-system-x86_64 -machine q35,accel=kvm -cpu host -m 8192 -smp 8 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file="$S/vars.fd" \
  -drive if=virtio,format=qcow2,file="$S/disk.qcow2" \
  -drive if=virtio,format=raw,media=cdrom,file="$S/seed.iso" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:40222-:22 -device virtio-net-pci,netdev=net0 \
  -display none -serial file:"$S/console.log" -daemonize
export GZ_SMOKE_SSH="ssh -p 40222 gentoo@127.0.0.1"
```

- [ ] **Step 4: Run the smoke test**

Run: `test/vm-smoke.sh 2>&1 | tee /tmp/gz-smoke.log`
Expected on first attempt: it will most likely stop at `emerge --pretend` with Portage asking for USE changes or a masked package. For each:
  - a USE change request: add the line to `profiles/base/package.use`, re-copy, re-run;
  - a keyword mask on a `::gentoo` package: add `category/pkg ~amd64` to the accept_keywords heredoc in `install/lib/portage.sh` and to `test/unit/portage.bats`;
  - a license: add it to the package.license heredoc and its test.
Re-run until `SMOKE OK`. Note the elapsed time of the emerge step and which packages compiled from source; Task 10 records them in the learning note.

- [ ] **Step 5: Re-run unit tests and lint after any fix**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Add govm smoke test and fix issues found by the first real install"
```

---

### Task 10: Learning note and README status

**Files:**
- Create: `docs/learning/01-portage-profiles-overlays.md`
- Modify: `README.md` (Status section: what the smoke test proved, how long the emerge took)

- [ ] **Step 1: Write the learning note**

`docs/learning/01-portage-profiles-overlays.md`, filled with what phase 1 actually exercised. Required sections and the facts each must contain:

```markdown
# 01. Portage, profiles and overlays (what phase 1 taught)

## The tree and how it gets there
- /var/db/repos/gentoo is the ::gentoo ebuild repository; the cloud image
  ships without it. emerge-webrsync fetches a daily snapshot tarball (fast
  first fetch); emerge --sync does an rsync delta afterwards.
- metadata/timestamp.chk is how you know how old the tree is.

## Repositories (overlays)
- /etc/portage/repos.conf/*.conf: one [name] section per repo with location,
  sync-type, sync-uri. eselect repository writes eselect-repo.conf for repos
  listed in Gentoo's repositories.xml (guru, hyproverlay) and for ad-hoc git
  URLs (gentoozinho).
- A repo is a directory with metadata/layout.conf (masters, thin-manifests,
  profile-formats) and profiles/repo_name. Only categories listed in
  profiles/categories are scanned; other top-level directories are ignored.
- Why hyproverlay: Hyprland is not in ::gentoo in 2026; the whole Hypr stack
  lives in hyproverlay and is ~amd64.

## Profiles
- make.profile is a symlink; eselect profile lists profiles.desc entries of
  every repo as repo:path.
- parent chains: gentoozinho:vm -> gentoo:default/linux/amd64/23.0/no-multilib/systemd
  and ../base. portage-2 profile format allows the repo:path syntax.
- make.defaults sets global USE defaults; package.use sets per-package flags;
  profiles cannot carry package.accept_keywords, that is why the installer
  writes /etc/portage/package.accept_keywords/gentoozinho.
- no-multilib vs multilib is decided at install time and cannot be switched.

## Keywords, licenses, masks
- amd64 is stable, ~amd64 is testing. */*::hyproverlay ~amd64 accepts testing
  for a whole repo. ACCEPT_LICENSE="@FREE" plus per-package exceptions.

## Binary packages
- binrepos.conf points at distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64.
  FEATURES getbinpkg uses them; binpkg-request-signature enforces GPG
  (getuto sets up the keyring on first use). --binpkg-respect-use=y refuses a
  binary whose USE flags differ from ours; those packages compile instead.
- What compiled from source in the smoke test and how long the emerge took
  (fill in from the run).

## Meta-packages
- An ebuild with only RDEPEND and LICENSE="metapackage". Merging it adds one
  line to /var/lib/portage/world; --depclean then keeps everything it pulls.

## Commands worth remembering
    emerge --info | grep -E '^(USE|FEATURES|MAKEOPTS)='
    eselect profile list
    emerge -pv gentoozinho-meta/desktop
    equery uses gui-wm/hyprland
    pkgcheck scan -r gentoozinho
```

Replace the two "fill in" sentences with the actual numbers and package list from the Task 9 run.

- [ ] **Step 2: Update README status**

Replace the Status paragraph with what the smoke test proved: profile, number of packages merged, how many came as binaries vs source, wall time on 8 vCPUs.

- [ ] **Step 3: Lint and tests one last time**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add docs/learning README.md
git commit -m "Add phase 1 learning note and update README status"
```

---

## Self-review notes

- Spec coverage: section 4 (layout) Tasks 1 to 3; section 5 (profiles, /etc/portage files) Tasks 2 and 5; section 6 (metas) Task 3; section 8 stages 1, 2, 3, 7 Tasks 7 and 8; section 9 (smoke, pkgcheck, lint, idempotency) Tasks 1 and 9; section 10 phase 1 doc Task 10. Sections 7 (payload), 8 stages 4 to 6, are phase 2 and 3 by design.
- Deviations from the spec, to be reflected back into it: profile names are `gentoozinho:vm` / `gentoozinho:desktop` (not `gentoozinho:gentoozinho/vm`); the kernel dependency is `virtual/dist-kernel`; base omits gum and app-misc/gentoozinho until phase 2; first sync uses emerge-webrsync.
- Names used consistently: `gz_write_file`, `gz_ensure_line`, `gz_write_portage_config`, `gz_tree_needs_sync`, `gz_target_profile`, `gz_meta_atoms`, `gz_repo_kind`, `GZ_TARGET_PROFILE`, `GZ_LOG_FILE`.
