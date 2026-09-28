# gentoozinho design

Date: 2026-09-27
Status: approved design, pre-plan

## 1. Purpose

gentoozinho turns a stock systemd Gentoo into an opinionated Hyprland desktop, the
way Omarchy does for Arch. It is built the Gentoo way: a real ebuild repository
with custom profiles and meta-packages, plus a thin bootstrap script. It doubles
as the author's path to Gentoo expertise: every phase produces working code and
a written note on the Gentoo mechanism it exercised.

Two targets must work from the same repo:

- **VM**: the official Gentoo weekly cloud-init image booted by
  [govm](https://github.com/guilhermebr/govm). Used for iteration and tests.
- **Metal**: a new physical machine (laptop or desktop, GPU not yet known),
  installed from a stage3 and then finished by gentoozinho.

Success for v1: on a fresh govm Gentoo VM, one command installs the desktop
stack, enables the services, seeds a user, and the VM boots into SDDM and then
Hyprland. The same command on a stage3 desktop/systemd install does the same on
metal.

## 2. Facts that constrain the design

Verified 2026-09-27.

- The Gentoo cloud-init image (`current-di-amd64-cloudinit`) is built by catalyst
  from profile `default/linux/amd64/23.0/no-multilib/systemd`. It is systemd
  already. It is no-multilib, and Gentoo does not support switching a
  no-multilib install to multilib. Booted and inspected 2026-09-27: it ships
  no ebuild tree, no git, no eselect-repository, gcc 15.3.0,
  `sys-kernel/gentoo-kernel` 6.18.50 with grub on a vfat `/boot`, a
  preconfigured `[gentoo]` binhost in `binrepos.conf`, and a `gentoo` user
  with passwordless sudo. It is EFI-only and does not boot under SeaBIOS, so
  govm needs OVMF for it.
- Hyprland is **not** in the `::gentoo` tree. `gui-wm/` there holds dwl,
  gamescope, labwc, sway, tinywl, wayfire. The Hypr ecosystem lives in
  `hyproverlay` (Codeberg, listed in Gentoo's overlay registry, active):
  hyprland, hypridle, hyprlock, hyprpaper, hyprpicker, hyprshot, hyprsunset,
  xdg-desktop-portal-hyprland, aquamarine, hyprutils, hyprlang, waybar.
- `::guru` has walker, quickshell, swayosd, lazygit. `::gentoo` has waybar,
  mako, wofi, alacritty, ghostty, foot, uwsm, sddm, wl-clipboard, swaybg,
  fastfetch, starship.
- `::guru` also has brightnessctl, pamixer, nerdfonts.
- Not packaged anywhere found: mise, lazydocker, localsend, gum, and all
  Basecamp-only Omarchy tools (owe, hype, aether, herdr, omarchy-nvim, ttfx,
  tobi-try, cliamp, monologue, omacalc, omacut, omawrite, omasnap).
- Gentoo's official binhost covers the stable tree for the amd64 23.0 profiles
  (plain, desktop/plasma/systemd, desktop/gnome/systemd). Since 2026-05 Portage
  requires OpenPGP signatures for remote binhosts by default. Hypr stack
  packages will compile from source; most of the rest can be binary.
- Omarchy 4.0.0.alpha is large: 463 helper scripts, 132 migrations, 22 themes,
  a Lua Hyprland config layer with its own bootstrap, a quickshell bar. A 1:1
  port is out of scope. An Omarchy-shaped desktop that reuses its config layout,
  themes and the useful scripts is the target.

## 3. Decisions already made

| Decision | Choice | Why |
|---|---|---|
| Init system | systemd only | Matches the cloud image; Omarchy assumes systemd; halves the test matrix |
| Package source | binhost first, source fallback | Fast VM iteration, still real Gentoo |
| GPU | pluggable hardware module, open-driver default | Metal GPU unknown yet |
| Kernel | `sys-kernel/gentoo-kernel-bin` (dist-kernel) in v1 | Custom kernels are a docs chapter later, not an installer feature |
| Bar / launcher / config format | waybar, walker, plain hyprlang | All packaged today; Omarchy 4's quickshell + Lua layer depend on unpackaged Basecamp tools |
| Repo model | single repo that is both overlay and payload | No extra hosting; `eselect repository add` works directly |

## 4. Repository layout

```
gentoozinho/
  metadata/layout.conf            masters = gentoo guru hyproverlay; repo-name = gentoozinho; thin-manifests
  profiles/repo_name              gentoozinho
  profiles/categories             gentoozinho-meta (plus any category we add ebuilds to)
  profiles/{base,vm,desktop}/     custom profiles (section 5)
  gentoozinho-meta/base/           meta ebuilds (section 6)
  gentoozinho-meta/desktop/
  gentoozinho-meta/dev/
  gentoozinho-meta/apps/
  app-misc/gentoozinho/            live ebuild installing the payload (section 7)
  <cat>/<pkg>/                    ebuilds for tools nobody packages (mise, lazydocker, localsend, gum)
  install.sh                      bootstrap entry point (section 8)
  install/                        step scripts grouped by stage
  bin/                            gentoozinho-* helper scripts (payload)
  default/                        shared defaults sourced by user configs (payload)
  config/                         per-user config templates copied on first install (payload)
  themes/<name>/                  theme directories (payload)
  docs/                           learning notes and the metal install guide
  test/                           govm smoke test, pkgcheck wrapper
```

Portage only treats directories listed in `profiles/categories` as categories,
so `bin/`, `default/`, `config/`, `themes/`, `docs/`, `test/`, `install/` are
ignored by the package manager. `pkgcheck` is run with those paths excluded.

Ebuilds for unpackaged tools start here and are upstreamed to GURU once they
have been merged and used for a while. Upstreaming is a deliberate learning
goal, not a v1 deliverable.

## 5. Profiles

Profiles carry USE defaults and package.use; the installer picks one per
target. This is how the VM (no-multilib) and metal (multilib) split is handled
without branching in scripts.

```
profiles/base/
  eapi                 5 (profile EAPI; matches what current ::gentoo profiles use)
  make.defaults        USE="networkmanager dist-kernel" (targets/desktop provides the rest)
  package.use          per-package USE for the Hypr stack, pipewire, portals, etc.
  package.use.force / package.use.mask   only if a package needs it
profiles/vm/
  parent               gentoo:default/linux/amd64/23.0/no-multilib
                       gentoo:targets/desktop
                       gentoo:targets/systemd
                       ../base       (mirrors gentoo's own desktop/systemd chain)
profiles/desktop/
  parent               gentoo:default/linux/amd64/23.0/desktop/systemd
                       ../base
profiles/profiles.desc
  amd64  vm       exp
  amd64  desktop  exp
```

Selected with `eselect profile set gentoozinho:vm` or `gentoozinho:desktop`
(`layout.conf` sets `profile-formats = portage-2`, which allows the
`repo:path` parent syntax). The installer chooses `vm` when the current
profile path contains `no-multilib`, otherwise `desktop`, and accepts
`--profile vm|desktop` to override.

Things profiles cannot or should not carry are written by the installer into
`/etc/portage/` (all named `gentoozinho` so they are easy to find and remove):

- `package.accept_keywords/gentoozinho`: `*/*::hyproverlay ~amd64`,
  `*/*::gentoozinho ~amd64`, `*/*::guru ~amd64` (whole repo: GURU is
  testing-only by policy and Portage still prefers `::gentoo` unless GURU has
  a higher version, a shadowing risk accepted for now), plus the few
  `::gentoo` packages that are still `~amd64` (uwsm, sdbus-c++, zoxide).
- `package.license/gentoozinho`: licenses needed by the apps meta (fonts,
  chromium codecs, and so on), never `*`.
- `binrepos.conf/gentoozinho.conf`: the official binhost for the matching
  profile, with signature verification on.
- `make.conf`: a `source /etc/portage/gentoozinho.conf` line added once, and
  `/etc/portage/gentoozinho.conf` holding `FEATURES="getbinpkg binpkg-request-signature"`,
  `EMERGE_DEFAULT_OPTS="--binpkg-respect-use=y --jobs --load-average"`,
  `MAKEOPTS` derived from `nproc`, `ACCEPT_LICENSE="@FREE"` as the baseline.
- `repos.conf/`: managed by `eselect repository`, not written by hand.

## 6. Meta-packages

Four ebuilds in `gentoozinho-meta/`, EAPI 8, no sources, only `RDEPEND`.
Version `0` with revision bumps as the list changes. USE flags on a meta are
allowed only to make a group optional (for example `nvidia`, `docker`).

- **base**: app-shells/starship, sys-apps/eza, sys-apps/bat, sys-apps/fd,
  sys-apps/ripgrep, app-shells/fzf, app-shells/zoxide, sys-process/btop,
  app-misc/tmux, app-editors/neovim, dev-vcs/git, dev-vcs/lazygit (guru),
  app-misc/jq, app-misc/gum (ours), app-misc/fastfetch, app-misc/gentoozinho.
- **desktop**: gui-wm/hyprland, gui-apps/hyprlock, gui-apps/hypridle,
  gui-apps/hyprpaper, gui-apps/hyprpicker, gui-apps/hyprshot,
  gui-libs/xdg-desktop-portal-hyprland, sys-apps/xdg-desktop-portal-gtk,
  gui-apps/waybar, gui-apps/walker (guru), gui-apps/mako, gui-apps/swayosd
  (guru), x11-terms/alacritty, x11-misc/sddm, gui-apps/uwsm,
  media-video/pipewire, media-video/wireplumber, net-misc/networkmanager,
  net-wireless/bluez, gnome-base/nautilus, gui-apps/wl-clipboard,
  gui-apps/grim, gui-apps/slurp, app-misc/brightnessctl (guru), media-sound/pamixer (guru),
  media-fonts/noto, media-fonts/noto-emoji, media-fonts/noto-cjk,
  media-fonts/jetbrains-mono, media-fonts/symbols-nerd-font, virtual/dist-kernel
  (satisfied by the cloud image's gentoo-kernel or by gentoo-kernel-bin on
  metal), sys-kernel/installkernel, gentoozinho-meta/base.
- **dev**: app-containers/docker, app-containers/docker-compose,
  app-containers/docker-buildx, dev-util/mise (ours), app-containers/lazydocker
  (ours), gentoozinho-meta/base.
- **apps**: www-client/firefox-bin (chromium was masked for removal from
  ::gentoo on 2026-09-24; the remaining chromium-based browsers are
  proprietary and left to the user), app-office/libreoffice-bin,
  media-video/mpv, media-gfx/imv, app-text/evince, net-misc/localsend (ours).

Exact atoms were confirmed against the tree during planning. Phase 1 ships
the metas without the ebuilds we have to write ourselves (gum, the payload
package, mise, lazydocker, localsend); those join in phase 2.

## 7. Payload package and configuration model

`app-misc/gentoozinho-9999.ebuild` uses `git-r3` with `EGIT_REPO_URI` pointing
at this repo. It installs:

- `bin/gentoozinho-*` to `/usr/bin/`
- `default/` and `themes/` to `/usr/share/gentoozinho/`
- `config/` to `/usr/share/gentoozinho/config/` as templates only; nothing is
  written into a home directory by the ebuild.

A versioned ebuild is added once the first tag exists. Updating the desktop is
`gentoozinho-update`, which runs `emerge --sync`, `emerge -uDN @world`,
`emerge --depclean --ask`, and `dispatch-conf` reminders.

User configuration follows Omarchy's split. On first install (or with
`gentoozinho-refresh-config`), files from `config/` are copied into
`~/.config/`. The user's `~/.config/hypr/hyprland.conf` looks like:

```
source = /usr/share/gentoozinho/default/hypr/*.conf
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/bindings.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/autostart.conf
source = ~/.config/gentoozinho/current/theme/hyprland.conf
```

Defaults improve with package updates; the user-owned files are never
overwritten by an update.

Themes are directories under `themes/<name>/` containing per-application
fragments (`hyprland.conf`, `hyprlock.conf`, `waybar.css`, `alacritty.toml`,
`mako.ini`, `walker.css`, `neovim.lua`, `backgrounds/`). `gentoozinho-theme-set
<name>` repoints `~/.config/gentoozinho/current/theme` and reloads hyprland,
waybar, mako. v1 ships tokyo-night, catppuccin, gruvbox, nord, ported from
Omarchy's theme files where licensing allows (Omarchy is MIT).

Helper scripts in `bin/` are ported from Omarchy only when a v1 feature needs
them: theme set/next, refresh-config, update, and the audio, brightness,
screenshot, and lock helpers bound to keys. Everything else waits.

## 8. Installer

`install.sh` is the single entry point. It runs as root on any Gentoo systemd
system with network, is idempotent (re-running converges, never duplicates
config lines), logs to `/var/log/gentoozinho/install.log`, and stops on the
first failed step with a pointer to the log.

Flags: `--profile vm|desktop`, `--user <name>` (default: the invoking sudo user,
or `gentoo` on the cloud image), `--metas base,desktop,dev,apps` (default
`base,desktop`), `--no-reboot`, `--repo-url <url>` (for testing a branch or a
local clone).

Stages, each a directory under `install/` with an `all.sh` that runs its steps
in order, mirroring Omarchy:

1. **preflight**: systemd is PID 1, amd64, root, `emerge` present, network up,
   detect profile family and virtualization (`systemd-detect-virt`), refuse to
   run on OpenRC.
2. **portage**: `emerge-webrsync` when no tree exists (the cloud image ships
   none), `emerge --sync` if the tree is older than a day, install
   `app-eselect/eselect-repository` and `dev-vcs/git`, enable `guru` and
   `hyproverlay`, add `gentoozinho` (from `--repo-url` or the default), write
   the `/etc/portage` files from section 5, set the profile.
3. **packages**: `emerge --getbinpkg --keep-going=n` the selected metas.
   Fails loudly if any atom is unresolvable; no silent skipping.
4. **system**: `systemctl enable` NetworkManager, sddm, bluetooth,
   systemd-resolved; mask NetworkManager-wait-online; PAM entry for hyprlock;
   sddm autologin disabled by default; polkit and seat setup as needed by
   uwsm.
5. **user**: create the user if missing (groups: wheel, video, audio, input,
   docker when dev meta chosen), copy `config/` templates, set the default
   theme, install the shell init snippet.
6. **hardware**: `gpu.sh` detects amd, intel, nvidia, or virtio and applies the
   matching package.use and environment fragments (nvidia installs the driver
   and sets the Hyprland env vars); `vm.sh` installs qemu-guest-agent and
   spice-vdagent when virtualized; `laptop.sh` enables power-profiles-daemon
   when a battery is present.
7. **finish**: summary of what changed, reboot prompt unless `--no-reboot`.

Metal installs start from the Gentoo Handbook up to a booting stage3
desktop/systemd system with a user and network. `docs/install-metal.md` is a
checklist version of that path with gentoozinho-specific choices called out
(profile, dist-kernel, systemd-boot). `install.sh` takes over from there.

## 9. Testing

- `test/vm-smoke.sh`: creates a govm VM from the `gentoo` catalog entry, copies
  the working tree in, runs `install.sh --profile vm --no-reboot --repo-url
  /path/to/copy`, then asserts: the metas are in `@world`, `Hyprland
  --version` runs, `systemctl is-enabled sddm NetworkManager` succeed, the user
  exists with the config files in place, and the installer is idempotent (a
  second run exits 0 and changes nothing). Destroys the VM on success, keeps
  it on failure.
- `test/lint.sh`: `pkgcheck scan` on the overlay inside a `gentoo/stage3`
  container, `shellcheck` on `install.sh`, `install/`, `bin/`.
- Visual boot check (SDDM, Hyprland session, theme switching) uses govm's
  display support once available. Until then it is done by hand.
- Every new ebuild gets `ebuild <file> manifest` and a real merge in the VM
  before it lands.

## 10. Phases

1. **Skeleton and install**: overlay plumbing, profiles, four metas, installer
   stages 1 to 4 and 7, smoke test green in govm. Doc: portage, profiles,
   overlays, binhost.
2. **Payload and theming**: `app-misc/gentoozinho`, default configs, four
   themes, key bindings, waybar, installer stage 5, first visual boot. Doc:
   ebuild writing, git-r3, config ownership.
3. **Metal**: `docs/install-metal.md`, hardware modules (stage 6), install on
   the new machine. Doc: kernel and firmware, GPU stacks, systemd-boot.
4. **Later, not planned**: image pipeline (catalyst stage4 or qcow2 for govm),
   more Omarchy scripts, upstreaming ebuilds to GURU, versioned releases.

## 11. Out of scope for v1

OpenRC, other architectures, a custom kernel config, an ISO or image build,
Omarchy's Lua config layer and quickshell bar, Basecamp-only tools, migrations
framework, multiple desktop flavours.

## 12. Open items

- Project name: decided as "gentoozinho" on 2026-09-27 (Brazilian diminutive
  of Gentoo; research showed the name is unclaimed on GitHub, package
  registries and domains). Gentoo's name policy arguably covers software that
  extends Gentoo, so the README carries an "unofficial community project, not
  endorsed by Gentoo" line and a courtesy note goes to trustees@gentoo.org.
  The local checkout directory is still named `gentoozito`; renaming it is a
  local `mv` whenever convenient.
- Package atoms in section 6 were checked against a 2026-09-27 clone of
  `::gentoo` and `::guru`; USE flags are resolved during planning.
