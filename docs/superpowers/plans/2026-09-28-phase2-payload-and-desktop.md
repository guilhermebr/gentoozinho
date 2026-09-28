# gentoozinho Phase 2: Payload, Themes and Desktop Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A gentoozinho VM boots into SDDM, logs into a themed Hyprland session with waybar, walker, mako, hyprlock and hypridle configured, and `gentoozinho-theme-set` switches between four themes; the smoke test proves it with a screenshot taken inside the session.

**Architecture:** `app-misc/gentoozinho` is a git live ebuild that installs the repo's `bin/`, `default/`, `themes/` and `config/` under `/usr/share/gentoozinho` and the helper scripts into `/usr/bin`. Configs follow Omarchy's split: shared defaults sourced from `/usr/share/gentoozinho/default`, user-owned files copied once into `~/.config`, and a theme engine that renders per-app fragments from one `colors.toml` per theme into `~/.config/gentoozinho/current/theme`. The installer gains a `system` stage (services, SDDM) and a `user` stage (account, config seed, theme, shell), plus an `--autologin` flag the smoke test uses to reach a running session without a display.

**Tech Stack:** bash, hyprlang (Hyprland 0.56 verifies `.conf` files with `--verify-config`; `.lua` also exists upstream but is not used), waybar 0.15 (jsonc + css), walker 0.13.26 from GURU (toml config, GTK4 css themes; predates Omarchy's elephant backend), mako, hyprlock 0.9, hypridle 0.1.8, alacritty 0.16, swayosd, uwsm 0.26, sddm, git-r3 eclass, bats via docker, QEMU with `virtio-vga` and VNC for the smoke VM.

**Spec:** `docs/superpowers/specs/2026-09-27-gentoozinho-design.md` sections 7 (payload and configuration model), 8 (stages 4 system and 5 user), 9 (visual check).

## Global Constraints

- Everything from phase 1 still holds: systemd only, amd64 only, EAPI 8 ebuilds, `set -Eeuo pipefail`, shellcheck clean, every library function `gz_`-prefixed, single-line commit messages, no attribution trailers.
- Port source is Omarchy **v3.8.4** (MIT, last release with hyprlang configs), cloned at `~/.cache/gentoozinho-src/omarchy-v3.8.4`. Re-create it with `git clone --depth 1 --branch v3.8.4 https://github.com/basecamp/omarchy ~/.cache/gentoozinho-src/omarchy-v3.8.4` if missing. Ported files keep a one-line header comment `# Adapted from Omarchy v3.8.4 (MIT)`, and README credits Omarchy.
- Every ported path `~/.local/share/omarchy` becomes `/usr/share/gentoozinho`; `~/.config/omarchy` becomes `~/.config/gentoozinho`; every `omarchy-*` command becomes a `gentoozinho-*` command that exists in `bin/`, or the line is dropped. No reference to a script that does not exist.
- Helper scripts in `bin/` have no `.sh` suffix, start with `#!/usr/bin/env bash`, read `GENTOOZINHO_PATH="${GENTOOZINHO_PATH:-/usr/share/gentoozinho}"` when they need the share dir, and never assume a running compositor (guard `hyprctl`, `waybar`, `mako` restarts with `pgrep`/`command -v`).
- Hyprland config stays hyprlang `.conf` (verified 2026-09-28: `Hyprland --verify-config` on 0.56.2 accepts a `.conf` and prints `config ok`).
- One background image per theme in this repo (keeps the clone small); Omarchy's are MIT-licensed and copied as-is.
- `app-misc/gentoozinho` is depended on by `gentoozinho-meta/desktop` (not `base`): its scripts need desktop tools.
- Facts verified in the installed VM on 2026-09-28: `/usr/share/wayland-sessions/hyprland-uwsm.desktop` exists with `Exec=uwsm start -e -D Hyprland hyprland.desktop`; `/etc/pam.d/hyprlock` exists (Gentoo ships it, `auth include login`); `/etc/sddm.conf.d/01gentoo.conf` sets `DisplayServer=x11`; `sddm`, `NetworkManager`, `bluetooth` are all disabled; walker cannot generate its config headless (`walker -C` needs a display); waybar's defaults are at `/etc/xdg/waybar/`; hypridle's sample config uses `hyprctl dispatch 'hl.dsp.dpms({action = "on"})'` (Lua-style dispatcher); fonts JetBrains Mono and Symbols Nerd Font are installed; portals gtk, hyprland, gnome-keyring are present; the login user is `gentoo` (uid 1000, groups users, wheel, sudo).
- The smoke VM is at `~/.cache/gentoozinho-smoke` (disk.qcow2, vars.fd, seed.iso) with everything from phase 1 merged. Boot it with `-device virtio-vga -vnc 127.0.0.1:0` (see Task 7) so Hyprland has a KMS device and a human can watch on VNC port 5900.
- git-r3 clones the *committed* HEAD. The smoke test therefore copies the working tree **including `.git`** and the installer points git-r3 at it via `EGIT_OVERRIDE_REPO_GENTOOZINHO=file://…` when `--repo-url` is a local git checkout. Uncommitted changes are not tested: commit before running the smoke test.

## Review Focus

1. `gentoozinho-theme-set` run with no compositor (installer's user stage, or over SSH) must not fail on missing `hyprctl`, `waybar`, `mako`, `swayosd-server`. Test in Task 2.
2. `gentoozinho-refresh-config --init` on a home that already has `~/.config/hypr/hyprland.conf` must not overwrite it. Test in Task 2.
3. A theme without `colors.toml` (a user-made theme dir) must fail with a clear message, not render empty templates. Test in Task 2.
4. `--user` names an existing account (the cloud image's `gentoo`): the user stage must add groups without touching the password or home, and must not fail on `useradd`. Test in Task 6 (function) and Task 7 (real).
5. The `system` stage on a machine where `systemd-networkd` manages the network (the cloud image): enabling NetworkManager must not leave the VM unreachable after reboot. Test in Task 7 by rebooting and reconnecting over SSH.

---

## File structure

```
app-misc/gentoozinho/gentoozinho-9999.ebuild, metadata.xml   live ebuild installing the payload
gentoozinho-meta/desktop/desktop-0.ebuild                    + app-misc/gentoozinho
profiles/categories                                          + app-misc
bin/gentoozinho-*                                            helper scripts (list in Task 3)
default/hypr/{autostart,envs,input,looknfeel,windows,apps}.conf
default/hypr/apps/{terminals,system,walker,hyprshot,browser}.conf
default/hypr/bindings/{tiling,media,clipboard,utilities}.conf
default/themed/{hyprland.conf,hyprlock.conf,waybar.css,mako.ini,alacritty.toml,walker.css,swayosd.css}.tpl
default/mako/core.ini
default/bash/rc                                              shell init sourced from ~/.bashrc
default/wayland-sessions/gentoozinho.desktop
default/sddm/hyprland.conf                                   compositor config for the SDDM greeter
config/hypr/{hyprland,monitors,input,bindings,looknfeel,autostart,hyprlock,hypridle}.conf
config/waybar/{config.jsonc,style.css}
config/walker/config.toml, config/walker/themes/gentoozinho.{css,toml}
config/mako/config
config/alacritty/alacritty.toml
config/swayosd/{config.toml,style.css}
config/uwsm/env
config/starship.toml
themes/{tokyo-night,catppuccin,gruvbox,nord}/{colors.toml,backgrounds/<one image>,btop.theme,neovim.lua}
install/lib/args.sh                                          + --autologin
install/lib/user.sh                                          gz_user_exists, gz_user_groups, gz_run_as_user
install/system/{10-services,20-sddm}.sh
install/user/{10-account,20-config,30-theme,40-shell}.sh
install.sh                                                   stage list: preflight portage packages system user finish
test/unit/{payload,theme,scripts,hypr,configs,user}.bats
test/lint.sh                                                 also lints bin/*
test/vm-smoke.sh                                             autologin, reboot, session assertions, screenshot
test/artifacts/                                              gitignored screenshot output
docs/learning/02-desktop-session.md
```

---

### Task 1: Payload ebuild, session file, category and lint coverage

**Files:**
- Create: `app-misc/gentoozinho/gentoozinho-9999.ebuild`, `app-misc/gentoozinho/metadata.xml`, `default/wayland-sessions/gentoozinho.desktop`, `bin/.keep` placeholder is NOT allowed: create `bin/gentoozinho-version` as the first real script
- Modify: `profiles/categories`, `gentoozinho-meta/desktop/desktop-0.ebuild`, `test/lint.sh`, `.gitignore`
- Test: `test/unit/payload.bats`, `test/unit/metas.bats`

**Interfaces:**
- Produces: `/usr/share/gentoozinho/{default,themes,config}` and `/usr/bin/gentoozinho-*` installed by the ebuild; `gentoozinho-version` prints the installed git commit or `dev`.

- [ ] **Step 1: Write the failing tests**

`test/unit/payload.bats`:

```bash
#!/usr/bin/env bats

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
  for f in "$REPO"/bin/gentoozinho-*; do
    [ -x "$f" ]
    [ "$(head -1 "$f")" = '#!/usr/bin/env bash' ]
    bash -n "$f"
  done
}

@test "lint covers bin scripts" {
  grep -q "bin/gentoozinho-\*" "$REPO/test/lint.sh"
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test/unit.sh test/unit/payload.bats`
Expected: all 6 FAIL (files missing).

- [ ] **Step 3: Write the ebuild, metadata, session file, first script; update category, meta, lint, gitignore**

`app-misc/gentoozinho/gentoozinho-9999.ebuild`:

```bash
# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

inherit git-r3

DESCRIPTION="gentoozinho desktop payload: helper scripts, defaults, themes and config templates"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"
EGIT_REPO_URI="https://github.com/guilhermebr/gentoozinho.git"

LICENSE="MIT"
SLOT="0"

# Tools the helper scripts call at runtime.
RDEPEND="
	app-misc/jq
	app-shells/bash
	gui-apps/grim
	gui-apps/hypridle
	gui-apps/hyprlock
	gui-apps/hyprpaper
	gui-apps/hyprshot
	gui-apps/mako
	gui-apps/slurp
	gui-apps/swayosd
	gui-apps/walker
	gui-apps/waybar
	gui-apps/wl-clipboard
	gui-wm/hyprland
	x11-libs/libnotify
	x11-terms/alacritty
"

src_install() {
	insinto /usr/share/gentoozinho
	doins -r default themes config
	dobin bin/*

	insinto /usr/share/wayland-sessions
	doins default/wayland-sessions/gentoozinho.desktop

	dodoc README.md
}
```

`app-misc/gentoozinho/metadata.xml`: same content as the meta-packages' metadata.xml (maintainer email, github remote-id).

`default/wayland-sessions/gentoozinho.desktop`:

```
[Desktop Entry]
Name=gentoozinho (Hyprland, uwsm)
Comment=gentoozinho Hyprland session managed by uwsm
Exec=uwsm start -g -1 -e -D Hyprland hyprland.desktop
TryExec=uwsm
Type=Application
DesktopNames=Hyprland
```

`bin/gentoozinho-version` (`chmod +x`):

```bash
#!/usr/bin/env bash
# Print the installed gentoozinho revision (git-r3 records it at merge time).
set -euo pipefail
GENTOOZINHO_PATH="${GENTOOZINHO_PATH:-/usr/share/gentoozinho}"
if [[ -f /var/db/pkg/app-misc/gentoozinho-9999/EGIT_VERSION ]]; then
  cat /var/db/pkg/app-misc/gentoozinho-9999/EGIT_VERSION
elif git -C "$GENTOOZINHO_PATH" rev-parse --short HEAD 2>/dev/null; then
  :
else
  echo dev
fi
```

`profiles/categories`: add a line `app-misc` (keep `gentoozinho-meta`).

`gentoozinho-meta/desktop/desktop-0.ebuild`: add `\tapp-misc/gentoozinho` to RDEPEND in sorted position (before `app-misc/brightnessctl`).

`test/lint.sh`: change the file collection to `git ls-files -co --exclude-standard '*.sh' install.sh 'bin/gentoozinho-*' | sort -u`.

`.gitignore`: add `test/artifacts/`.

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass (the `metas.bats` sorted-RDEPEND test still passes because `app-misc/gentoozinho` sorts before `app-misc/brightnessctl`).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add app-misc/gentoozinho live ebuild, session file and lint coverage for bin"
```

---

### Task 2: Theme engine

**Files:**
- Create: `bin/gentoozinho-theme-set-templates`, `bin/gentoozinho-theme-set`, `bin/gentoozinho-theme-list`, `bin/gentoozinho-theme-current`, `bin/gentoozinho-theme-next`, `bin/gentoozinho-theme-bg-next`, `bin/gentoozinho-refresh-config`
- Create: `default/themed/{hyprland.conf,hyprlock.conf,waybar.css,mako.ini,alacritty.toml,walker.css,swayosd.css}.tpl`
- Create: `themes/{tokyo-night,catppuccin,gruvbox,nord}/colors.toml`, one background each, `btop.theme`, `neovim.lua`
- Test: `test/unit/theme.bats`

**Interfaces:**
- Produces: `~/.config/gentoozinho/current/theme/` (rendered fragments), `~/.config/gentoozinho/current/theme.name`, `~/.config/gentoozinho/current/background` (symlink); commands `gentoozinho-theme-set NAME`, `-list`, `-current`, `-next`, `-bg-next`, `gentoozinho-refresh-config (--init | PATH)`; env `GENTOOZINHO_PATH` for the share dir.

- [ ] **Step 1: Write the failing tests**

`test/unit/theme.bats`:

```bash
#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$(mktemp -d)"; export HOME
  export GENTOOZINHO_PATH="$REPO"
  export PATH="$REPO/bin:$PATH"
}
teardown() { rm -rf "$HOME"; }

@test "theme-list prints the four shipped themes" {
  [ "$(gentoozinho-theme-list | tr '\n' ' ')" = "catppuccin gruvbox nord tokyo-night " ]
}

@test "theme-set renders every template with the theme's colors" {
  gentoozinho-theme-set tokyo-night
  t="$HOME/.config/gentoozinho/current/theme"
  grep -q 'rgb(7aa2f7)' "$t/hyprland.conf"
  grep -q 'background-color=#1a1b26' "$t/mako.ini"
  grep -q 'include=/usr/share/gentoozinho/default/mako/core.ini' "$t/mako.ini"
  grep -q '@define-color background #1a1b26;' "$t/waybar.css"
  grep -q 'rgba(26,27,38, 1.0)' "$t/hyprlock.conf"
  grep -q '@define-color selected-text #7aa2f7;' "$t/walker.css"
  grep -q '@define-color progress #7aa2f7;' "$t/swayosd.css"
  grep -q "background = '#1a1b26'" "$t/alacritty.toml"
  [ "$(cat "$HOME/.config/gentoozinho/current/theme.name")" = tokyo-night ]
  [ -L "$HOME/.config/gentoozinho/current/background" ]
}

@test "theme-set works with no compositor running (review focus 1)" {
  # PATH has no hyprctl/waybar/mako/swayosd-server in the test container; must still exit 0.
  run gentoozinho-theme-set nord
  [ "$status" -eq 0 ]
  [ "$(gentoozinho-theme-current)" = nord ]
}

@test "theme-next cycles alphabetically and wraps" {
  gentoozinho-theme-set tokyo-night
  gentoozinho-theme-next
  [ "$(gentoozinho-theme-current)" = catppuccin ]
  gentoozinho-theme-next
  [ "$(gentoozinho-theme-current)" = gruvbox ]
}

@test "theme-set rejects an unknown theme and a theme without colors.toml (review focus 3)" {
  run gentoozinho-theme-set no-such-theme
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
  mkdir -p "$HOME/.config/gentoozinho/themes/broken/backgrounds"
  run gentoozinho-theme-set broken
  [ "$status" -eq 1 ]
  [[ "$output" == *"colors.toml"* ]]
}

@test "user themes under ~/.config/gentoozinho/themes are found" {
  mkdir -p "$HOME/.config/gentoozinho/themes/mine/backgrounds"
  cp "$REPO/themes/nord/colors.toml" "$HOME/.config/gentoozinho/themes/mine/"
  cp "$REPO"/themes/nord/backgrounds/* "$HOME/.config/gentoozinho/themes/mine/backgrounds/"
  gentoozinho-theme-list | grep -qx mine
  gentoozinho-theme-set mine
  [ "$(gentoozinho-theme-current)" = mine ]
}

@test "refresh-config --init seeds missing files only (review focus 2)" {
  mkdir -p "$HOME/.config/hypr"
  printf 'mine\n' > "$HOME/.config/hypr/hyprland.conf"
  gentoozinho-refresh-config --init
  [ "$(cat "$HOME/.config/hypr/hyprland.conf")" = mine ]
  [ -f "$HOME/.config/hypr/monitors.conf" ]
  [ -f "$HOME/.config/waybar/config.jsonc" ]
}

@test "refresh-config PATH replaces one file and keeps a backup" {
  mkdir -p "$HOME/.config/hypr"
  printf 'mine\n' > "$HOME/.config/hypr/hyprland.conf"
  gentoozinho-refresh-config hypr/hyprland.conf
  grep -q 'source = /usr/share/gentoozinho/default/hypr/autostart.conf' "$HOME/.config/hypr/hyprland.conf"
  ls "$HOME"/.config/hypr/hyprland.conf.bak.* > /dev/null
}

@test "every theme has colors.toml with the keys the templates use and exactly one background" {
  for d in "$REPO"/themes/*/; do
    for k in accent foreground background color0 color15; do
      grep -q "^$k = \"#" "$d/colors.toml"
    done
    [ "$(ls "$d/backgrounds" | wc -l)" -eq 1 ]
  done
}
```

Note: the refresh-config tests need `config/hypr/hyprland.conf` and `config/waybar/config.jsonc`, created in Task 4 and Task 5. Until then those two tests fail; that is expected and recorded in the ledger. Everything else in this file must pass at the end of this task.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test/unit.sh test/unit/theme.bats`
Expected: all FAIL.

- [ ] **Step 3: Write the templates**

Port from `~/.cache/gentoozinho-src/omarchy-v3.8.4/default/themed/`. Rules: `hyprland.conf.tpl`, `hyprlock.conf.tpl`, `waybar.css.tpl`, `walker.css.tpl`, `swayosd.css.tpl`, `alacritty.toml.tpl` are copied verbatim (they only contain `{{ key }}` placeholders). `mako.ini.tpl` changes the include line to `include=/usr/share/gentoozinho/default/mako/core.ini`. Each gets the header `# Adapted from Omarchy v3.8.4 (MIT)` (css files use `/* ... */`).

- [ ] **Step 4: Write the themes**

For each of tokyo-night, catppuccin, gruvbox, nord: copy `colors.toml`, `btop.theme`, `neovim.lua` from the Omarchy theme dir, and exactly one background: tokyo-night `1-sunset-lake.png`, catppuccin `1-totoro.png`, gruvbox `1-the-backwater.jpg`, nord `1-city-view.png`. Verify with `ls themes/*/backgrounds`.

- [ ] **Step 5: Write the scripts**

`bin/gentoozinho-theme-set-templates`:

```bash
#!/usr/bin/env bash
# Adapted from Omarchy v3.8.4 (MIT)
# Render default/themed/*.tpl (and ~/.config/gentoozinho/themed/*.tpl) with the
# colors of the theme staged in ~/.config/gentoozinho/current/next-theme.
set -euo pipefail
GENTOOZINHO_PATH="${GENTOOZINHO_PATH:-/usr/share/gentoozinho}"
TEMPLATES_DIR="$GENTOOZINHO_PATH/default/themed"
USER_TEMPLATES_DIR="$HOME/.config/gentoozinho/themed"
NEXT_THEME_DIR="$HOME/.config/gentoozinho/current/next-theme"
COLORS_FILE="$NEXT_THEME_DIR/colors.toml"

hex_to_rgb() { local hex="${1#\#}"; printf '%d,%d,%d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"; }

[[ -f $COLORS_FILE ]] || { echo "gentoozinho-theme-set-templates: $COLORS_FILE missing" >&2; exit 1; }

sed_script="$(mktemp)"
while IFS='=' read -r key value; do
  key="${key//[\"\' ]/}"
  [[ $key && $key != \#* ]] || continue
  value="${value#*[\"\']}"
  value="${value%%[\"\']*}"
  printf 's|{{ %s }}|%s|g\n' "$key" "$value"
  printf 's|{{ %s_strip }}|%s|g\n' "$key" "${value#\#}"
  if [[ $value =~ ^# ]]; then
    printf 's|{{ %s_rgb }}|%s|g\n' "$key" "$(hex_to_rgb "$value")"
  fi
done < "$COLORS_FILE" > "$sed_script"

shopt -s nullglob
for tpl in "$USER_TEMPLATES_DIR"/*.tpl "$TEMPLATES_DIR"/*.tpl; do
  out="$NEXT_THEME_DIR/$(basename "$tpl" .tpl)"
  [[ -f $out ]] || sed -f "$sed_script" "$tpl" > "$out"
done
rm -f "$sed_script"
```

`bin/gentoozinho-theme-list`:

```bash
#!/usr/bin/env bash
# List shipped and user themes, sorted, one per line.
set -euo pipefail
GENTOOZINHO_PATH="${GENTOOZINHO_PATH:-/usr/share/gentoozinho}"
shopt -s nullglob
for d in "$GENTOOZINHO_PATH"/themes/*/ "$HOME"/.config/gentoozinho/themes/*/; do
  basename "$d"
done | sort -u
```

`bin/gentoozinho-theme-current`:

```bash
#!/usr/bin/env bash
set -euo pipefail
f="$HOME/.config/gentoozinho/current/theme.name"
[[ -f $f ]] && cat "$f" || echo none
```

`bin/gentoozinho-theme-set`:

```bash
#!/usr/bin/env bash
# Adapted from Omarchy v3.8.4 (MIT)
# Apply a theme: stage it, render templates, swap it in, pick a background,
# and reload whatever is running. Safe to run without a compositor.
set -euo pipefail
GENTOOZINHO_PATH="${GENTOOZINHO_PATH:-/usr/share/gentoozinho}"
[[ -n ${1:-} ]] || { echo "usage: gentoozinho-theme-set <theme-name>" >&2; exit 1; }

CURRENT="$HOME/.config/gentoozinho/current"
NEXT="$CURRENT/next-theme"
name="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
src=""
for candidate in "$HOME/.config/gentoozinho/themes/$name" "$GENTOOZINHO_PATH/themes/$name"; do
  [[ -d $candidate ]] && { src="$candidate"; break; }
done
[[ -n $src ]] || { echo "Theme '$name' does not exist" >&2; exit 1; }
[[ -f $src/colors.toml ]] || { echo "Theme '$name' has no colors.toml" >&2; exit 1; }

rm -rf "$NEXT"
mkdir -p "$NEXT"
cp -r "$src"/. "$NEXT"/
gentoozinho-theme-set-templates

rm -rf "$CURRENT/theme"
mv "$NEXT" "$CURRENT/theme"
echo "$name" > "$CURRENT/theme.name"

gentoozinho-theme-bg-next

# Reload running components only.
if command -v hyprctl > /dev/null && pgrep -x Hyprland > /dev/null; then hyprctl reload > /dev/null || true; fi
if pgrep -x waybar > /dev/null; then gentoozinho-restart-waybar || true; fi
if pgrep -x mako > /dev/null; then makoctl reload || true; fi
if pgrep -x swayosd-server > /dev/null; then pkill -x swayosd-server; setsid -f swayosd-server > /dev/null 2>&1 || true; fi
```

`bin/gentoozinho-theme-bg-next`:

```bash
#!/usr/bin/env bash
# Adapted from Omarchy v3.8.4 (MIT)
# Point ~/.config/gentoozinho/current/background at the next background of the
# current theme (wrapping), and tell hyprpaper if it is running.
set -euo pipefail
CURRENT="$HOME/.config/gentoozinho/current"
dir="$CURRENT/theme/backgrounds"
mapfile -t bgs < <(find "$dir" -maxdepth 1 -type f | sort)
(( ${#bgs[@]} )) || { echo "no backgrounds in $dir" >&2; exit 1; }
now="$(readlink -f "$CURRENT/background" 2>/dev/null || true)"
next="${bgs[0]}"
for i in "${!bgs[@]}"; do
  if [[ ${bgs[$i]} == "$now" ]]; then next="${bgs[$(( (i + 1) % ${#bgs[@]} ))]}"; break; fi
done
ln -sfn "$next" "$CURRENT/background"
if command -v hyprctl > /dev/null && pgrep -x hyprpaper > /dev/null; then
  hyprctl hyprpaper reload ",$next" > /dev/null || true
fi
```

`bin/gentoozinho-theme-next`:

```bash
#!/usr/bin/env bash
set -euo pipefail
mapfile -t themes < <(gentoozinho-theme-list)
cur="$(gentoozinho-theme-current)"
next="${themes[0]}"
for i in "${!themes[@]}"; do
  if [[ ${themes[$i]} == "$cur" ]]; then next="${themes[$(( (i + 1) % ${#themes[@]} ))]}"; break; fi
done
gentoozinho-theme-set "$next"
command -v notify-send > /dev/null && notify-send -u low "Theme: $next" || true
```

`bin/gentoozinho-refresh-config`:

```bash
#!/usr/bin/env bash
# Adapted from Omarchy v3.8.4 (MIT)
# --init : copy every file from the config templates into ~/.config that does
#          not exist yet (never overwrites).
# PATH   : replace ~/.config/PATH with the template, keeping a timestamped backup.
set -euo pipefail
GENTOOZINHO_PATH="${GENTOOZINHO_PATH:-/usr/share/gentoozinho}"
src_root="$GENTOOZINHO_PATH/config"

case "${1:-}" in
  --init)
    while IFS= read -r -d '' f; do
      rel="${f#"$src_root"/}"
      dst="$HOME/.config/$rel"
      [[ -e $dst ]] && continue
      mkdir -p "$(dirname "$dst")"
      cp "$f" "$dst"
    done < <(find "$src_root" -type f -print0)
    ;;
  "")
    echo "usage: gentoozinho-refresh-config --init | <path under ~/.config>" >&2; exit 1 ;;
  *)
    src="$src_root/$1"; dst="$HOME/.config/$1"
    [[ -f $src ]] || { echo "no template for $1" >&2; exit 1; }
    mkdir -p "$(dirname "$dst")"
    if [[ -f $dst ]]; then
      bak="$dst.bak.$(date +%s)"
      cp -f "$dst" "$bak"
      cp -f "$src" "$dst"
      if cmp -s "$dst" "$bak"; then rm -f "$bak"; else echo "Replaced $dst (backup: $bak)"; fi
    else
      cp -f "$src" "$dst"
    fi
    ;;
esac
```

`gentoozinho-restart-waybar` is written in Task 3; until then theme-set's `pgrep -x waybar` guard keeps it from being called in tests.

`chmod +x bin/*`.

- [ ] **Step 6: Run tests and lint**

Run: `test/unit.sh test/unit/theme.bats && test/lint.sh`
Expected: 7 of 9 pass; the two `refresh-config` tests fail on missing `config/` templates (created in Tasks 4 and 5). Record in ledger.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add theme engine, templates and four themes"
```

---

### Task 3: Helper scripts referenced by bindings and configs

**Files:**
- Create in `bin/`: `gentoozinho-restart-waybar`, `gentoozinho-restart-mako`, `gentoozinho-launch-walker`, `gentoozinho-launch-browser`, `gentoozinho-launch-terminal`, `gentoozinho-swayosd-client`, `gentoozinho-brightness-display`, `gentoozinho-capture-screenshot`, `gentoozinho-system-lock`, `gentoozinho-toggle-waybar`, `gentoozinho-toggle-idle`, `gentoozinho-toggle-notification-silencing`, `gentoozinho-hyprland-window-close-all`, `gentoozinho-update`, `gentoozinho-menu-keybindings`
- Test: `test/unit/scripts.bats`

**Interfaces:**
- Produces: exactly these command names, used by Task 4's bindings and Task 5's configs.

- [ ] **Step 1: Write the failing test**

`test/unit/scripts.bats`:

```bash
#!/usr/bin/env bats

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "the helper scripts the desktop needs all exist" {
  for s in restart-waybar restart-mako launch-walker launch-browser launch-terminal swayosd-client \
           brightness-display capture-screenshot system-lock toggle-waybar toggle-idle \
           toggle-notification-silencing hyprland-window-close-all update menu-keybindings \
           theme-set theme-list theme-current theme-next theme-bg-next theme-set-templates refresh-config version; do
    [ -x "$REPO/bin/gentoozinho-$s" ]
  done
}

@test "every gentoozinho-* command referenced anywhere in default/ or config/ exists in bin/" {
  cd "$REPO"
  missing=""
  for cmd in $(grep -rhoE 'gentoozinho-[a-z0-9-]+' default config | sort -u); do
    [ -f "bin/$cmd" ] || missing="$missing $cmd"
  done
  [ -z "$missing" ] || { echo "missing:$missing"; false; }
}

@test "no omarchy paths or commands leak into the payload" {
  cd "$REPO"
  run grep -rIlE 'omarchy-[a-z]|\.local/share/omarchy|\.config/omarchy' bin default config themes
  [ "$status" -ne 0 ]
}

@test "update runs the Handbook sequence" {
  f="$REPO/bin/gentoozinho-update"
  grep -q 'emerge --sync' "$f"
  grep -q -- '--update --deep --newuse @world' "$f"
  grep -q -- '--depclean' "$f"
  grep -q 'dispatch-conf' "$f"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/scripts.bats`
Expected: first and fourth FAIL (scripts missing); the second passes vacuously until Task 4 adds configs; the third passes.

- [ ] **Step 3: Write the scripts** (all `#!/usr/bin/env bash`, `set -euo pipefail`, `chmod +x`)

`gentoozinho-restart-waybar`: `pkill -x waybar || true; setsid -f uwsm-app -- waybar > /dev/null 2>&1`.
`gentoozinho-restart-mako`: `pkill -x mako || true; setsid -f uwsm-app -- mako > /dev/null 2>&1`.
`gentoozinho-launch-walker`: `exec walker "$@"` (walker 0.13 toggles itself when already running).
`gentoozinho-launch-browser`: `exec xdg-open "${1:-about:blank}"`.
`gentoozinho-launch-terminal`: `exec alacritty "$@"`.
`gentoozinho-swayosd-client`: start `swayosd-server` with `setsid -f` if `! pgrep -x swayosd-server`, sleep 0.2, then `exec swayosd-client "$@"`.
`gentoozinho-brightness-display`: `brightnessctl -q set "${1:-+5%}"; gentoozinho-swayosd-client --brightness "$(brightnessctl -m | cut -d, -f4 | tr -d %)" || true`.
`gentoozinho-capture-screenshot`: `dir="${GENTOOZINHO_SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"; mkdir -p "$dir"; hyprshot -m "${1:-region}" -o "$dir" --silent && notify-send -u low "Screenshot saved" "$dir"`.
`gentoozinho-system-lock`: `pidof hyprlock > /dev/null || exec hyprlock`.
`gentoozinho-toggle-waybar`: `if pgrep -x waybar > /dev/null; then pkill -x waybar; else gentoozinho-restart-waybar; fi`.
`gentoozinho-toggle-idle`: `if pgrep -x hypridle > /dev/null; then pkill -x hypridle; notify-send -u low "Idle locking off"; else setsid -f uwsm-app -- hypridle > /dev/null 2>&1; notify-send -u low "Idle locking on"; fi`.
`gentoozinho-toggle-notification-silencing`: `makoctl mode -t do-not-disturb`.
`gentoozinho-hyprland-window-close-all`: `hyprctl -j clients | jq -r '.[].address' | while read -r a; do hyprctl dispatch closewindow "address:$a" > /dev/null; done`.
`gentoozinho-menu-keybindings`: `hyprctl -j binds | jq -r '.[] | select(.has_description) | "\(.modmask) \(.key)\t\(.description)"' | walker --dmenu -p "Keybindings"` (walker 0.13 has `--dmenu`).
`gentoozinho-update`:

```bash
#!/usr/bin/env bash
# Update the whole system the Gentoo way. Wraps the Handbook sequence.
set -euo pipefail
(( EUID == 0 )) || exec sudo "$0" "$@"
emerge --sync
emerge --update --deep --newuse --getbinpkg --keep-going=n @world
emerge --depclean --pretend
echo
echo "Review the --depclean list above; run 'emerge --depclean --ask' to remove."
echo "Run 'dispatch-conf' if config files need merging."
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: `scripts.bats` passes; theme.bats still has the two expected refresh-config failures; lint clean.

- [ ] **Step 5: Commit**

```bash
git add bin test/unit/scripts.bats
git commit -m "Add desktop helper scripts"
```

---

### Task 4: Hyprland defaults and user config templates

**Files:**
- Create: `default/hypr/{autostart,envs,input,looknfeel,windows,apps}.conf`, `default/hypr/apps/{terminals,system,walker,hyprshot,browser}.conf`, `default/hypr/bindings/{tiling,media,clipboard,utilities}.conf`
- Create: `config/hypr/{hyprland,monitors,input,bindings,looknfeel,autostart,hyprlock,hypridle}.conf`
- Test: `test/unit/hypr.bats`, plus `Hyprland --verify-config` in the VM

**Interfaces:**
- Consumes: Task 3 script names.
- Produces: the user's `~/.config/hypr/hyprland.conf` structure that the theme engine and the session rely on.

- [ ] **Step 1: Write the failing test**

`test/unit/hypr.bats`:

```bash
#!/usr/bin/env bats

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "user hyprland.conf sources defaults, theme, then user files in that order" {
  f="$REPO/config/hypr/hyprland.conf"
  mapfile -t src < <(grep -oE '^source = .*' "$f" | sed 's/^source = //')
  [ "${src[0]}" = "/usr/share/gentoozinho/default/hypr/autostart.conf" ]
  printf '%s\n' "${src[@]}" | grep -q '^/usr/share/gentoozinho/default/hypr/bindings/tiling.conf$'
  printf '%s\n' "${src[@]}" | grep -q '^/usr/share/gentoozinho/default/hypr/looknfeel.conf$'
  theme_idx="$(printf '%s\n' "${src[@]}" | grep -n 'current/theme/hyprland.conf' | cut -d: -f1)"
  user_idx="$(printf '%s\n' "${src[@]}" | grep -n '~/.config/hypr/monitors.conf' | cut -d: -f1)"
  [ "$theme_idx" -lt "$user_idx" ]
}

@test "default configs never point at omarchy paths and only exec gentoozinho or system commands" {
  cd "$REPO"
  run grep -rE 'omarchy' default/hypr config/hypr
  [ "$status" -ne 0 ]
}

@test "autostart launches the session services through uwsm-app" {
  f="$REPO/default/hypr/autostart.conf"
  for app in hypridle mako waybar hyprpaper; do grep -q "exec-once = uwsm-app -- $app" "$f"; done
  grep -q 'exec-once = systemctl --user import-environment' "$f"
}

@test "bindings keep Omarchy's core keys" {
  f="$REPO/default/hypr/bindings/tiling.conf"
  grep -q 'bindd = SUPER, W, Close window, killactive,' "$f"
  grep -q 'bindd = SUPER, RETURN, Terminal, exec, gentoozinho-launch-terminal' "$REPO/default/hypr/bindings/utilities.conf"
  grep -q 'bindd = SUPER, SPACE, Launch apps, exec, gentoozinho-launch-walker' "$REPO/default/hypr/bindings/utilities.conf"
  grep -q 'bindd = SUPER CTRL, L, Lock system, exec, gentoozinho-system-lock' "$REPO/default/hypr/bindings/utilities.conf"
  grep -q 'bindd = SUPER SHIFT CTRL, SPACE, Next theme, exec, gentoozinho-theme-next' "$REPO/default/hypr/bindings/utilities.conf"
}

@test "hypridle and hyprlock user configs reference gentoozinho, not omarchy" {
  grep -q 'lock_cmd = gentoozinho-system-lock' "$REPO/config/hypr/hypridle.conf"
  grep -q 'source = ~/.config/gentoozinho/current/theme/hyprlock.conf' "$REPO/config/hypr/hyprlock.conf"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/hypr.bats`
Expected: FAIL (files missing).

- [ ] **Step 3: Port the defaults**

From `~/.cache/gentoozinho-src/omarchy-v3.8.4/default/hypr/`:

- `autostart.conf`: keep `hypridle`, `mako`, `waybar` (unconditional: `exec-once = uwsm-app -- waybar`), add `exec-once = uwsm-app -- hyprpaper`, drop fcitx5, swaybg, polkit-gnome (use `exec-once = uwsm-app -- /usr/libexec/polkit-gnome-authentication-agent-1` only if that path exists in the VM; check with `ls /usr/libexec/polkit-gnome*`; otherwise drop), drop `omarchy-first-run`, `omarchy-powerprofiles-init`, `omarchy-hyprland-monitor-watch`, `omarchy-hook`. Keep the `systemctl --user import-environment` and `dbus-update-activation-environment` lines.
- `envs.conf`: drop the gum `source` block and `QT_STYLE_OVERRIDE`; keep the rest.
- `input.conf`, `windows.conf`, `looknfeel.conf`: copy; in `windows.conf` change the `source` path to `/usr/share/gentoozinho/default/hypr/apps.conf`.
- `apps.conf`: only source `apps/terminals.conf`, `apps/system.conf`, `apps/walker.conf`, `apps/hyprshot.conf`, `apps/browser.conf`. In `apps/system.conf` replace `org.omarchy.*` classes with `org.gentoozinho.*` and drop the screensaver block. In `apps/browser.conf` keep the rules that reference `chromium|firefox` classes only.
- `bindings/tiling.conf`: copy, drop the two "deprecated" header lines, `omarchy-hyprland-window-close-all` → `gentoozinho-hyprland-window-close-all`.
- `bindings/media.conf`: `omarchy-swayosd-client` → `gentoozinho-swayosd-client`; `omarchy-brightness-display` → `gentoozinho-brightness-display`; drop keyboard-brightness, touchpad-toggle, audio-input-mute and audio-output-switch lines (no scripts for them in v1).
- `bindings/clipboard.conf`: `omarchy-launch-walker -m clipboard` → `gentoozinho-launch-walker -m clipboard`.
- `bindings/utilities.conf`: rewrite to these bindings only:
  ```
  bindd = SUPER, RETURN, Terminal, exec, gentoozinho-launch-terminal
  bindd = SUPER, SPACE, Launch apps, exec, gentoozinho-launch-walker
  bindd = SUPER CTRL, E, Emoji picker, exec, gentoozinho-launch-walker -m emojis
  bindd = SUPER, B, Browser, exec, gentoozinho-launch-browser
  bindd = SUPER, F, File manager, exec, nautilus --new-window
  bindd = SUPER, K, Show key bindings, exec, gentoozinho-menu-keybindings
  bindd = SUPER SHIFT, SPACE, Toggle top bar, exec, gentoozinho-toggle-waybar
  bindd = SUPER CTRL, SPACE, Next background, exec, gentoozinho-theme-bg-next
  bindd = SUPER SHIFT CTRL, SPACE, Next theme, exec, gentoozinho-theme-next
  bindd = SUPER, COMMA, Dismiss last notification, exec, makoctl dismiss
  bindd = SUPER SHIFT, COMMA, Dismiss all notifications, exec, makoctl dismiss --all
  bindd = SUPER CTRL, COMMA, Toggle silencing notifications, exec, gentoozinho-toggle-notification-silencing
  bindd = SUPER CTRL, I, Toggle locking on idle, exec, gentoozinho-toggle-idle
  bindd = , PRINT, Screenshot region, exec, gentoozinho-capture-screenshot region
  bindd = SHIFT, PRINT, Screenshot window, exec, gentoozinho-capture-screenshot window
  bindd = CTRL, PRINT, Screenshot output, exec, gentoozinho-capture-screenshot output
  bindd = SUPER, PRINT, Color picker, exec, pkill hyprpicker || hyprpicker -a
  bindd = SUPER CTRL, L, Lock system, exec, gentoozinho-system-lock
  bindd = SUPER CTRL, T, Activity, exec, gentoozinho-launch-terminal -e btop
  bindd = SUPER, ESCAPE, Power off menu, exec, systemctl poweroff -i
  ```
  (SUPER+ESCAPE is a placeholder for a real power menu in a later phase; `systemctl poweroff -i` is honest and documented in the file header.)

- [ ] **Step 4: Write the user templates**

`config/hypr/hyprland.conf`:

```
# Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/

# gentoozinho defaults (do not edit; they update with the package)
source = /usr/share/gentoozinho/default/hypr/autostart.conf
source = /usr/share/gentoozinho/default/hypr/bindings/media.conf
source = /usr/share/gentoozinho/default/hypr/bindings/clipboard.conf
source = /usr/share/gentoozinho/default/hypr/bindings/tiling.conf
source = /usr/share/gentoozinho/default/hypr/bindings/utilities.conf
source = /usr/share/gentoozinho/default/hypr/envs.conf
source = /usr/share/gentoozinho/default/hypr/looknfeel.conf
source = /usr/share/gentoozinho/default/hypr/input.conf
source = /usr/share/gentoozinho/default/hypr/windows.conf
source = ~/.config/gentoozinho/current/theme/hyprland.conf

# Your overrides (loaded last, so they win)
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/bindings.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/autostart.conf
```

`config/hypr/{monitors,input,bindings,looknfeel,autostart}.conf`: copy Omarchy's `config/hypr/*.conf` counterparts, replacing `omarchy` command references with the gentoozinho ones from Task 3 or deleting the line, and `~/.local/share/omarchy` paths with `/usr/share/gentoozinho`.
`config/hypr/hyprlock.conf`: copy Omarchy's, change the theme `source` to `~/.config/gentoozinho/current/theme/hyprlock.conf` and the background `path` to `~/.config/gentoozinho/current/background`.
`config/hypr/hypridle.conf`:

```
general {
    lock_cmd = gentoozinho-system-lock
    before_sleep_cmd = gentoozinho-system-lock
    after_sleep_cmd = hyprctl dispatch dpms on
    inhibit_sleep = 3
}

listener {
    timeout = 300
    on-timeout = gentoozinho-system-lock
}

listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
```

- [ ] **Step 5: Verify the assembled config with Hyprland itself**

Commit first (git-r3 needs it, but this step uses a plain copy). Copy the tree to the VM and run:

```bash
tar -cz bin default config themes | ssh -p 40222 gentoo@127.0.0.1 'rm -rf ~/gz && mkdir ~/gz && tar xz -C ~/gz'
ssh -p 40222 gentoo@127.0.0.1 'export GENTOOZINHO_PATH=$HOME/gz PATH=$HOME/gz/bin:$PATH HOME=/tmp/gzhome; rm -rf $HOME; mkdir -p $HOME; gentoozinho-refresh-config --init && gentoozinho-theme-set tokyo-night && sed -i "s#/usr/share/gentoozinho#$GENTOOZINHO_PATH#g" $HOME/.config/hypr/hyprland.conf && Hyprland --verify-config -c $HOME/.config/hypr/hyprland.conf'
```

Expected: `config ok`. Also verify the dispatcher spelling: `ssh ... 'Hyprland --verify-config -c /dev/stdin <<< "bind = SUPER, X, exec, hyprctl dispatch dpms off"'` prints `config ok`. Fix any error Hyprland reports (0.56 renamed some window-rule syntax; Omarchy 3.8.4 already uses the `match:` form).

- [ ] **Step 6: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: hypr.bats passes; the theme.bats refresh-config test for `hypr/hyprland.conf` now passes; the one needing `waybar/config.jsonc` still fails until Task 5.

- [ ] **Step 7: Commit**

```bash
git add default config test/unit/hypr.bats
git commit -m "Add Hyprland defaults and user config templates ported from Omarchy 3.8.4"
```

---

### Task 5: Waybar, walker, mako, alacritty, swayosd, uwsm and shell configs

**Files:**
- Create: `config/waybar/{config.jsonc,style.css}`, `config/walker/config.toml`, `config/walker/themes/gentoozinho.{css,toml}`, `config/mako/config`, `config/alacritty/alacritty.toml`, `config/swayosd/{config.toml,style.css}`, `config/uwsm/env`, `config/starship.toml`, `default/mako/core.ini`, `default/bash/rc`
- Test: `test/unit/configs.bats`

- [ ] **Step 1: Write the failing test**

`test/unit/configs.bats`:

```bash
#!/usr/bin/env bats

setup() { REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"; }

@test "waybar config is valid JSON once comments are stripped and has no omarchy modules" {
  f="$REPO/config/waybar/config.jsonc"
  sed -E 's#^\s*//.*##; s#([^:])//.*#\1#' "$f" | tr -d '\n' | grep -q '"modules-left"'
  run grep -E 'custom/(omarchy|update|weather|voxtype|screenrecording)' "$f"
  [ "$status" -ne 0 ]
  grep -q '@import "../gentoozinho/current/theme/waybar.css";' "$REPO/config/waybar/style.css"
}

@test "walker config uses the gentoozinho theme and its css imports the themed colors" {
  grep -q '^theme = "gentoozinho"' "$REPO/config/walker/config.toml"
  grep -q '@import url("file://' "$REPO/config/walker/themes/gentoozinho.css"
  [ -f "$REPO/config/walker/themes/gentoozinho.toml" ]
}

@test "mako user config includes the themed fragment" {
  grep -q '^include=~/.config/gentoozinho/current/theme/mako.ini' "$REPO/config/mako/config"
  grep -q '^default-timeout=' "$REPO/default/mako/core.ini"
}

@test "alacritty imports the themed colors and uses JetBrains Mono" {
  grep -q '"~/.config/gentoozinho/current/theme/alacritty.toml"' "$REPO/config/alacritty/alacritty.toml"
  grep -q 'JetBrainsMono Nerd Font\|JetBrains Mono' "$REPO/config/alacritty/alacritty.toml"
}

@test "swayosd style imports the themed colors" {
  grep -q '@import url("file://' "$REPO/config/swayosd/style.css"
}

@test "uwsm env exports the essentials" {
  grep -q '^export TERMINAL=alacritty' "$REPO/config/uwsm/env"
  grep -q '^export EDITOR=nvim' "$REPO/config/uwsm/env"
}

@test "bash rc initialises starship and zoxide only when present" {
  f="$REPO/default/bash/rc"
  grep -q 'command -v starship' "$f"
  grep -q 'command -v zoxide' "$f"
  bash -n "$f"
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `test/unit.sh test/unit/configs.bats`
Expected: FAIL.

- [ ] **Step 3: Write the configs**

- `config/waybar/config.jsonc`: start from Omarchy's `config/waybar/config.jsonc`; remove `custom/omarchy`, `custom/weather`, `custom/update`, `custom/voxtype`, `custom/screenrecording-indicator`, `custom/idle-indicator`, `custom/notification-silencing-indicator` and the `group/tray-expander` if it references omarchy scripts (keep `tray`); keep `hyprland/workspaces`, `clock`, `bluetooth`, `network`, `pulseaudio`, `cpu`, `battery`, `tray`. Replace any `on-click` that calls an `omarchy-*` command with a `gentoozinho-*` one or delete the key.
- `config/waybar/style.css`: Omarchy's, with the first line `@import "../gentoozinho/current/theme/waybar.css";`.
- `config/walker/config.toml`: fetch walker's default with `gh api 'repos/abenz1267/walker/contents/internal/config/config.default.toml?ref=v0.13.26' --jq .content | base64 -d`; set `theme = "gentoozinho"`; keep the rest.
- `config/walker/themes/gentoozinho.toml`: walker's `internal/config/themes/default.toml` at v0.13.26, fetched the same way.
- `config/walker/themes/gentoozinho.css`: walker's `internal/config/themes/default.css` with its color definitions replaced by `@import url("file:///home/USER/.config/gentoozinho/current/theme/walker.css");` is not possible (no `~` expansion in GTK css), so the theme engine's `walker.css` is installed by `gentoozinho-theme-set` with a symlink: add to `gentoozinho-theme-set` (Task 2 script) the line `mkdir -p "$HOME/.config/walker/themes" && ln -sfn "$CURRENT/theme/walker.css" "$HOME/.config/walker/themes/gentoozinho-colors.css"`, and have `gentoozinho.css` start with `@import url("file://gentoozinho-colors.css");` relative import. If walker rejects the relative import at runtime (Task 7), fall back to `gentoozinho-theme-set` writing the merged css directly into `~/.config/walker/themes/gentoozinho.css`; adjust the test accordingly and ledger it.
- `config/mako/config`: `include=~/.config/gentoozinho/current/theme/mako.ini`.
- `default/mako/core.ini`: Omarchy's `default/mako/core.ini` minus the four `[summary~=...]` blocks that call omarchy scripts; keep the Spotify, do-not-disturb, critical and screenshot blocks.
- `config/alacritty/alacritty.toml`: Omarchy's `config/alacritty/alacritty.toml` with `import = ["~/.config/gentoozinho/current/theme/alacritty.toml"]` and font family `JetBrainsMono Nerd Font` (the Gentoo package `media-fonts/jetbrains-mono` plus `symbols-nerd-font` do not provide a patched family; use `JetBrains Mono` as the family and rely on fontconfig fallback for symbols; the test accepts either).
- `config/swayosd/config.toml` and `style.css`: Omarchy's, with the css importing `file:///` is again not expandable; make `gentoozinho-theme-set` symlink `$CURRENT/theme/swayosd.css` to `~/.config/swayosd/colors.css` and `style.css` begin with `@import url("colors.css");`. Same fallback rule as walker.
- `config/uwsm/env`: `export TERMINAL=alacritty`, `export EDITOR=nvim`, `export PATH="$PATH:$HOME/.local/bin"`.
- `config/starship.toml`: Omarchy's.
- `default/bash/rc`:

```bash
# shellcheck shell=bash
# Sourced from ~/.bashrc by the gentoozinho installer. Keep it light.
export PATH="$PATH:$HOME/.local/bin"
alias ls='eza -lh --group-directories-first --icons=auto'
alias cat='bat --paging=never --style=plain'
alias ff='fastfetch'
command -v starship > /dev/null && eval "$(starship init bash)"
command -v zoxide > /dev/null && eval "$(zoxide init bash)"
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: everything passes, including both refresh-config tests from Task 2.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add waybar, walker, mako, alacritty, swayosd, uwsm and shell configs"
```

---

### Task 6: Installer system and user stages

**Files:**
- Create: `install/lib/user.sh`, `install/system/10-services.sh`, `install/system/20-sddm.sh`, `install/user/10-account.sh`, `install/user/20-config.sh`, `install/user/30-theme.sh`, `install/user/40-shell.sh`, `default/sddm/hyprland.conf`
- Modify: `install/lib/args.sh` (`--autologin`), `install/lib/all.sh`, `install.sh` (stage list), `install/portage/30-repos.sh` (git-r3 override for local checkouts)
- Test: `test/unit/user.bats`, `test/unit/args.bats`, `test/unit/install_sh.bats`

**Interfaces:**
- Produces: `GZ_AUTOLOGIN` (0/1); `gz_user_exists NAME`, `gz_user_groups` (prints the group list), `gz_run_as_user NAME CMD...`; `gz_sddm_conf USER AUTOLOGIN` prints the sddm config text.

- [ ] **Step 1: Write the failing tests**

`test/unit/user.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export GZ_ROOT=""
  # shellcheck source=/dev/null
  source "$BATS_TEST_DIRNAME/../../install/lib/all.sh"
}

@test "gz_user_exists" {
  gz_user_exists root
  run gz_user_exists no-such-user-xyz
  [ "$status" -ne 0 ]
}

@test "gz_user_groups lists the desktop groups" {
  [ "$(gz_user_groups)" = "wheel,users,video,audio,input,plugdev" ]
}

@test "gz_sddm_conf renders wayland greeter, session and optional autologin" {
  out="$(gz_sddm_conf alice 0)"
  [[ "$out" == *"DisplayServer=wayland"* ]]
  [[ "$out" == *"CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.conf"* ]]
  [[ "$out" != *"[Autologin]"* ]]
  out="$(gz_sddm_conf alice 1)"
  [[ "$out" == *"[Autologin]"* ]]
  [[ "$out" == *"User=alice"* ]]
  [[ "$out" == *"Session=gentoozinho.desktop"* ]]
}
```

Append to `test/unit/args.bats`:

```bash
@test "--autologin flag" {
  gz_parse_args
  [ "$GZ_AUTOLOGIN" = 0 ]
  gz_parse_args --autologin
  [ "$GZ_AUTOLOGIN" = 1 ]
}
```

Modify `test/unit/install_sh.bats` "stages run in the documented order" to expect `for stage in preflight portage packages system user finish`, and append:

```bash
@test "repos step points git-r3 at a local checkout" {
  grep -q 'EGIT_OVERRIDE_REPO_GENTOOZINHO' "$REPO/install/portage/30-repos.sh"
}

@test "user stage seeds config, sets the theme and sources the shell rc as the user" {
  grep -q 'gentoozinho-refresh-config --init' "$REPO/install/user/20-config.sh"
  grep -q 'gentoozinho-theme-set' "$REPO/install/user/30-theme.sh"
  grep -q 'source /usr/share/gentoozinho/default/bash/rc' "$REPO/install/user/40-shell.sh"
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `test/unit.sh test/unit/user.bats test/unit/args.bats test/unit/install_sh.bats`
Expected: new tests FAIL.

- [ ] **Step 3: Write the library and steps**

`install/lib/user.sh`:

```bash
# shellcheck shell=bash
# User account helpers and the SDDM configuration text.

gz_user_exists() { getent passwd "$1" > /dev/null; }

gz_user_groups() { echo "wheel,users,video,audio,input,plugdev"; }

# gz_run_as_user NAME CMD...: run CMD as NAME with a proper HOME and PATH.
gz_run_as_user() {
  local user="$1"; shift
  local home; home="$(getent passwd "$user" | cut -d: -f6)"
  sudo -u "$user" env HOME="$home" PATH="/usr/bin:/bin:/usr/local/bin" "$@"
}

# gz_sddm_conf USER AUTOLOGIN(0|1): print /etc/sddm.conf.d/10-gentoozinho.conf
gz_sddm_conf() {
  local user="$1" autologin="$2"
  cat <<EOF
# Managed by gentoozinho.
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.conf
EOF
  if (( autologin )); then
    cat <<EOF

[Autologin]
User=${user}
Session=gentoozinho.desktop
EOF
  fi
}
```

`install/lib/args.sh`: add `GZ_AUTOLOGIN=0` default, a `--autologin) GZ_AUTOLOGIN=1; shift ;;` case, `GZ_AUTOLOGIN` to the export line, and a usage line `--autologin  log the user straight into the gentoozinho session (SDDM autologin)`.

`install/lib/all.sh`: append the `user.sh` source lines.

`install.sh`: stage list becomes `preflight portage packages system user finish`.

`install/portage/30-repos.sh`, inside the `local)` branch after the rsync: 

```bash
    if git -C "$GZ_REPO_URL" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
      export EGIT_OVERRIDE_REPO_GENTOOZINHO="file://${GZ_REPO_URL%/}"
      export EGIT_OVERRIDE_BRANCH_GENTOOZINHO
      EGIT_OVERRIDE_BRANCH_GENTOOZINHO="$(git -C "$GZ_REPO_URL" rev-parse --abbrev-ref HEAD)"
      gz_log "git-r3 will clone app-misc/gentoozinho from ${EGIT_OVERRIDE_REPO_GENTOOZINHO} (${EGIT_OVERRIDE_BRANCH_GENTOOZINHO})"
    fi
```

`default/sddm/hyprland.conf` (greeter compositor, from Omarchy's `default/sddm/hyprland.conf`, paths adjusted):

```
# Minimal Hyprland config for the SDDM greeter
monitor = , preferred, auto, 1
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}
exec-once = sddm-greeter-qt6 --theme /usr/share/sddm/themes/breeze; hyprctl dispatch exit
```

Check the theme dir in the VM with `ls /usr/share/sddm/themes/`; use the first available theme if `breeze` is absent.

`install/system/10-services.sh`:

```bash
# shellcheck shell=bash
# Desktop services. NetworkManager takes over from systemd-networkd.
systemctl enable NetworkManager.service bluetooth.service sddm.service
systemctl mask NetworkManager-wait-online.service
if systemctl is-enabled systemd-networkd.service > /dev/null 2>&1; then
  gz_log "disabling systemd-networkd in favour of NetworkManager"
  systemctl disable systemd-networkd.service systemd-networkd-wait-online.service || true
fi
```

`install/system/20-sddm.sh`:

```bash
# shellcheck shell=bash
# Wayland greeter driven by Hyprland, our session as default, autologin on request.
gz_sddm_conf "$GZ_USER" "$GZ_AUTOLOGIN" | gz_write_file "${GZ_ROOT}/etc/sddm.conf.d/10-gentoozinho.conf" > /dev/null
```

`install/user/10-account.sh`:

```bash
# shellcheck shell=bash
if gz_user_exists "$GZ_USER"; then
  gz_log "user ${GZ_USER} exists; ensuring desktop groups"
else
  gz_log "creating user ${GZ_USER}"
  useradd -m -s /bin/bash "$GZ_USER"
  gz_log "set a password with: passwd ${GZ_USER}"
fi
usermod -a -G "$(gz_user_groups)" "$GZ_USER"
```

`install/user/20-config.sh`: `gz_run_as_user "$GZ_USER" gentoozinho-refresh-config --init`
`install/user/30-theme.sh`: `gz_run_as_user "$GZ_USER" gentoozinho-theme-set tokyo-night`
`install/user/40-shell.sh`:

```bash
# shellcheck shell=bash
home="$(getent passwd "$GZ_USER" | cut -d: -f6)"
gz_ensure_line "$home/.bashrc" 'source /usr/share/gentoozinho/default/bash/rc'
chown "$GZ_USER" "$home/.bashrc"
```

- [ ] **Step 4: Run tests and lint**

Run: `test/unit.sh && test/lint.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add installer system and user stages with SDDM configuration and autologin flag"
```

---

### Task 7: Smoke test with a real session and a screenshot

**Files:**
- Modify: `test/vm-smoke.sh`
- Create: `test/artifacts/.gitkeep` is not needed (dir is gitignored); the script creates it.

- [ ] **Step 1: Extend the smoke test**

Changes to `test/vm-smoke.sh`:
1. Copy the tree **with** `.git`: `tar -cz . | vm '...'` (drop `--exclude=.git`). Before that, refuse to run if `git status --porcelain` is non-empty: `echo "commit first: git-r3 installs committed HEAD"; exit 1`.
2. First install adds `--autologin`.
3. After the first install's assertions, add:

```bash
step "reboot into the desktop session"
vm 'sudo systemctl reboot' || true
sleep 20
for i in $(seq 1 30); do vm true 2> /dev/null && break; sleep 5; done
vm 'systemctl is-active sddm'
vm 'systemctl is-active NetworkManager'
vm 'for i in $(seq 1 30); do pgrep -x Hyprland > /dev/null && break; sleep 2; done; pgrep -x Hyprland'
vm 'loginctl list-sessions --no-legend | grep -q "$(id -un)"'
vm 'pgrep -x waybar && pgrep -x mako && pgrep -x hypridle && pgrep -x hyprpaper'

step "screenshot from inside the session"
mkdir -p test/artifacts
vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -m1 "^wayland-[0-9]$"); sleep 3; grim /tmp/shot.png && hyprctl -j clients > /tmp/clients.json'
vm 'cat /tmp/shot.png' > test/artifacts/smoke.png
[[ -s test/artifacts/smoke.png ]]

step "theme switching inside the session"
vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); gentoozinho-theme-set catppuccin && test "$(gentoozinho-theme-current)" = catppuccin && hyprctl getoption general:col.active_border | grep -qi 89b4fa'
```

Keep the second-run idempotency check, dev/apps resolve and pkgcheck after these.

- [ ] **Step 2: Lint**

Run: `test/lint.sh`
Expected: clean.

- [ ] **Step 3: Boot the VM with a display device**

Power off any running instance (`ssh ... sudo systemctl poweroff`), then:

```bash
D="$HOME/.cache/gentoozinho-smoke"
qemu-system-x86_64 -machine q35,accel=kvm -cpu host -m 8192 -smp 8 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file="$D/vars.fd" \
  -drive if=virtio,format=qcow2,file="$D/disk.qcow2" \
  -drive if=virtio,format=raw,media=cdrom,file="$D/seed.iso" \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:40222-:22 -device virtio-net-pci,netdev=net0 \
  -device virtio-vga -vnc 127.0.0.1:0 -serial file:"$D/console.log" -pidfile "$D/qemu.pid" -daemonize
```

The user can watch on VNC `127.0.0.1:5900`.

- [ ] **Step 4: Run the smoke test**

Commit, then `GZ_SMOKE_SSH="ssh -p 40222 gentoo@127.0.0.1" test/vm-smoke.sh 2>&1 | tee test/artifacts/smoke.log`.
Expected first-attempt failures and how to handle them:
- `app-misc/gentoozinho` fails to fetch: check `EGIT_OVERRIDE_REPO_GENTOOZINHO` is exported into the emerge environment (it is set in the same shell; `emerge` inherits it). If Portage sandbox blocks `file://`, add `FEATURES="-network-sandbox"` is NOT the fix; git-r3 handles file URLs; check the path.
- Hyprland does not start under SDDM autologin: read `journalctl -u sddm -b` and `~/.local/share/uwsm/` or `journalctl --user -b` via ssh; likely causes are the greeter compositor config, a missing `hyprland.desktop` for uwsm's `-D Hyprland hyprland.desktop` (check `/usr/share/wayland-sessions/hyprland.desktop` exists), or no KMS device (check `ls /dev/dri`).
- Screenshot is black: `hyprpaper` failed to load the background; check `~/.config/hypr/hyprpaper.conf` is not required by 0.56's hyprpaper (if it is, generate it in `gentoozinho-theme-bg-next`).
Re-run until `SMOKE OK`. **View `test/artifacts/smoke.png`** (the Read tool renders images) and confirm a bar at the top and a wallpaper are visible; describe what is seen in the ledger.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Extend smoke test to boot the desktop session and capture a screenshot; fix what the first real session revealed"
```

---

### Task 8: Learning note, README and spec sync

**Files:**
- Create: `docs/learning/02-desktop-session.md`
- Modify: `README.md`, `docs/superpowers/specs/2026-09-27-gentoozinho-design.md`

- [ ] **Step 1: Write the learning note**

`docs/learning/02-desktop-session.md` covers, each with what was done and what broke: git live ebuilds and `git-r3` (`EGIT_OVERRIDE_REPO_*`, EGIT_VERSION, why commits matter); how a Wayland session starts on systemd Gentoo (sddm → wayland-sessions .desktop → uwsm → Hyprland as a systemd user scope, `uwsm-app`, `import-environment`); SDDM on Wayland with Hyprland as the greeter compositor; PAM for hyprlock; xdg-desktop-portal selection; hyprlang `.conf` versus the new Lua config in Hyprland 0.56; the theme engine (one `colors.toml`, sed templates, `_rgb`/`_strip` suffixes, atomic swap); GTK css `@import` limits and the symlink workaround; what the screenshot proved and how it was taken (grim over ssh with `HYPRLAND_INSTANCE_SIGNATURE`).

- [ ] **Step 2: README**

Status paragraph: phase 2 done, what the session contains, `--autologin`, theme commands, the VNC hint for the VM, Omarchy credit line: "Configs and themes are adapted from Omarchy v3.8.4 (MIT) by Basecamp."

- [ ] **Step 3: Spec sync**

Section 7: replace the theme description with the colors.toml + templates engine; `app-misc/gentoozinho` moves from base to desktop meta; add `--autologin` to section 8's flags; note sddm runs a Wayland greeter using Hyprland.

- [ ] **Step 4: Tests and lint, commit**

Run: `test/unit.sh && test/lint.sh`

```bash
git add -A
git commit -m "Add phase 2 learning note, update README and sync spec"
```

---

## Self-review notes

- Spec coverage: section 7 payload (Tasks 1 to 5), configuration model and theme switching (Tasks 2, 4), helper scripts limited to what bindings need (Task 3), section 8 stages 4 and 5 (Task 6), section 9 visual boot (Task 7), phase-2 doc (Task 8). Deviations recorded for the spec sync: theme engine uses templates; payload belongs to the desktop meta; `--autologin` flag added; SDDM Wayland greeter.
- Placeholder scan: clean. Task 5's walker/swayosd css import approach has an explicit fallback rule.
- Names: `gentoozinho-theme-set`, `-theme-set-templates`, `-theme-list`, `-theme-current`, `-theme-next`, `-theme-bg-next`, `-refresh-config`, `-restart-waybar`, `-restart-mako`, `-launch-walker`, `-launch-browser`, `-launch-terminal`, `-swayosd-client`, `-brightness-display`, `-capture-screenshot`, `-system-lock`, `-toggle-waybar`, `-toggle-idle`, `-toggle-notification-silencing`, `-hyprland-window-close-all`, `-update`, `-menu-keybindings`, `-version`; `gz_user_exists`, `gz_user_groups`, `gz_run_as_user`, `gz_sddm_conf`, `GZ_AUTOLOGIN`, `GENTOOZINHO_PATH` used consistently.
- Review Focus coverage: 1 and 3 in theme.bats (Task 2), 2 in theme.bats (Task 2), 4 in user.bats plus Task 7's real run on the existing `gentoo` user, 5 in Task 7's reboot.
