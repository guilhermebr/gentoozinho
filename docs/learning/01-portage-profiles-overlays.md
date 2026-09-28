# 01. Portage, profiles and overlays (what phase 1 taught)

Everything below was learned by making the first real install work on the
official Gentoo cloud image inside a VM, on 2026-09-27 and 28. Each section
names the mechanism, what we did with it, and what broke.

## The tree and how it gets there

- `/var/db/repos/gentoo` is the `::gentoo` ebuild repository. The cloud image
  ships **without it**: no tree, no `git`, no `eselect-repository`. Portage is
  there, but it cannot resolve anything until a tree exists.
- `emerge-webrsync` fetches a daily snapshot tarball (about a minute). It is
  the right first fetch. `emerge --sync` does an rsync delta afterwards and is
  what `gentoozinho-update` will use.
- `metadata/timestamp.chk` inside the tree tells you how old it is; the
  installer syncs only when it is older than a day.
- Portage finds `::gentoo` through `/usr/share/portage/config/repos.conf`
  even when `/etc/portage/repos.conf` has no entry for it. `pkgcore`, and so
  `pkgcheck`, only read `/etc/portage/repos.conf`. The Handbook's advice to
  copy that default file into `/etc/portage/repos.conf/gentoo.conf` is not
  cosmetic.

## Repositories (overlays)

- `/etc/portage/repos.conf/*.conf` holds one `[name]` section per repository
  with `location`, `sync-type`, `sync-uri`. `eselect repository enable NAME`
  writes `eselect-repo.conf` for repositories listed in Gentoo's
  `repositories.xml` (guru, hyproverlay); `eselect repository add NAME git URL`
  does the same for any git URL (gentoozinho). `emaint sync -r NAME` syncs one.
- A repository is a directory with `metadata/layout.conf` and
  `profiles/repo_name`. Only the categories listed in `profiles/categories`
  are scanned; other top-level directories (`bin/`, `docs/`, `test/`) are
  ignored by Portage, though `pkgcheck` reports them as `UnknownCategoryDirs`.
- `masters` in `layout.conf` is not decoration. It says which repositories
  yours may reference for dependencies, eclasses and profiles. Ours started as
  `masters = gentoo` and `pkgcheck` correctly flagged every hyproverlay and
  GURU atom as nonexistent. It is now `gentoo guru hyproverlay`, and the
  installer syncs those two before registering gentoozinho.
- `profile-formats = portage-2` enables the `repo:path` syntax in a profile's
  `parent` file, which is how our profiles inherit from `::gentoo`.
- Why hyproverlay: in 2026 Hyprland is not in `::gentoo` at all. The whole
  Hypr stack (hyprland, hyprlock, hypridle, hyprpaper, hyprpicker, hyprshot,
  xdg-desktop-portal-hyprland, aquamarine, hyprutils, hyprlang, a newer
  waybar) lives in hyproverlay, keyworded `~amd64`. GURU has walker, swayosd,
  lazygit, brightnessctl, pamixer.

## Profiles

- `/etc/portage/make.profile` is a symlink. `eselect profile list` shows every
  profile from every repository's `profiles.desc` as `repo:path`, so ours
  appear as `gentoozinho:vm` and `gentoozinho:desktop`.
- A profile is a directory whose `parent` file lists what it inherits, in
  order; later parents win. `::gentoo`'s own `23.0/desktop/systemd` is
  `23.0/desktop` (which pulls `targets/desktop`) followed by `targets/systemd`.
- Our `vm` profile mirrors that chain on a no-multilib base:
  `gentoo:default/linux/amd64/23.0/no-multilib`, `gentoo:targets/desktop`,
  `gentoo:targets/systemd`, `../base`. We got there the hard way: the first
  attempt inherited only `no-multilib/systemd`, and Portage refused pipewire
  (`bluetooth? ( dbus )`), alacritty (`libxkbcommon[X]`) and qtbase
  (`wayland? ( opengl )`) one REQUIRED_USE at a time. Each was a flag that
  `targets/desktop` sets globally. Inheriting the target instead of copying
  its flags fixed all of them at once.
- `make.defaults` sets global USE and may only use flags declared in
  `profiles/use.desc` of the repository or its masters; `pipewire` is a local
  flag and `pkgcheck` flagged it (`UnknownProfileUse`). `package.use` sets
  per-package flags and is where workarounds live: `dev-libs/cxxopts -icu`
  (the 3.3.1 ebuild has `IUSE=icu` but no dependency on icu, a real `::gentoo`
  bug worth reporting) and `sys-kernel/gentoo-kernel -debug` (see below).
- Profiles cannot carry `package.accept_keywords`, licenses or binhost
  settings. That is why the installer writes
  `/etc/portage/package.accept_keywords/gentoozinho` and friends.
- **Switching profile means rebuilding.** The Handbook's
  `emerge --update --deep --newuse @world` after a profile change is not
  optional: the cloud image's systemd was built without `policykit` and polkit
  from the desktop target needed it, so without `--newuse` Portage stopped
  with a slot conflict. On the cloud image the switch to the desktop target
  rebuilt 21 packages, among them glibc (`compile-locales`), python
  (`bluetooth`), ncurses (`gpm`), linux-firmware and the kernel (`initramfs`).
- no-multilib versus multilib is decided at install time and cannot be
  switched later; that is the whole reason `vm` and `desktop` are two profiles.

## Keywords, licenses, masks

- `amd64` means stable, `~amd64` means testing. `*/*::hyproverlay ~amd64` in
  `package.accept_keywords` accepts testing for a whole repository; a few
  `::gentoo` packages the desktop needs are still testing too (`gui-apps/uwsm`,
  `dev-cpp/sdbus-c++`, `app-shells/zoxide`).
- `emerge --pretend --autounmask=y --autounmask-write=n` prints every keyword,
  USE and license change a set of atoms needs without touching anything. It
  turned five one-at-a-time failures into one list.
- `package.mask` in `::gentoo` is how packages are retired. `www-client/chromium`
  was masked on 2026-09-24 for removal a month later (bug 982204), which is
  why the apps meta ships `firefox-bin`.
- `ACCEPT_LICENSE="@FREE"` plus per-package exceptions in
  `package.license/gentoozinho` (firmware, microcode).

## Binary packages

- `/etc/portage/binrepos.conf/` points at
  `distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64`; the cloud
  image ships that entry already, so the installer only adds one when none
  exists. `FEATURES="getbinpkg"` uses it, `binpkg-request-signature` enforces
  GPG (getuto builds the keyring on first use), and
  `--binpkg-respect-use=y` refuses a binary whose USE flags differ from ours;
  those packages compile instead.
- Measured on the first install (8 vCPU, 8 GB, `MAKEOPTS=-j3`, `--jobs=2`):

  | | |
  |---|---|
  | packages in the plan | 430 (409 new, 21 reinstalls) |
  | from the binhost | 368 |
  | compiled from source | 62 |
  | of which from hyproverlay or GURU | 11 (hyprland, hyprlock, hypridle, hyprpicker, waybar, xdg-desktop-portal-hyprland, glaze, walker, swayosd, lazygit, brightnessctl, pamixer) |
  | wall time, merging only | about 4.5 hours across two runs |

  The time is not the Hypr stack. It is `sys-devel/gcc:16` (a new stable slot
  the world update pulled in, about 50 minutes), the kernel rebuild (about 45
  minutes without debug info), glibc and python.

## Disk is a build resource

- `/var/tmp/portage` is where every package is built. The kernel with
  `USE=debug` needed 9.6 GB there and overflowed the image's 20 GB disk; a
  failed build directory also stays behind until removed. With `-debug` the
  kernel needs about 4 GB. Budget 25 GB or more for a VM that compiles.
- The host matters too: a QEMU overlay disk placed on a 16 GB tmpfs filled it
  and the guest saw hundreds of I/O errors. VM disks belong on real storage.

## Meta-packages

- An ebuild with only `RDEPEND` and `LICENSE="metapackage"`, no `SRC_URI`, so
  with `thin-manifests` it needs no `Manifest` at all. Merging one adds a line
  to `/var/lib/portage/world`; `--depclean` then keeps everything it pulls.
- `pkgcheck scan -r gentoozinho -p stable --exit=error,warning` is the lint.
  Without `--exit` it returns 0 even with findings. `-p stable` skips the
  musl and x32 developer profiles where binary-only packages such as
  `firefox-bin` can never resolve.

## Commands worth remembering

    emerge --info | grep -E '^(USE|FEATURES|MAKEOPTS)='
    eselect profile list
    emerge -pv gentoozinho-meta/desktop
    emerge -pv --autounmask=y --autounmask-write=n gentoozinho-meta/apps
    equery uses gui-wm/hyprland
    pkgcheck scan -r gentoozinho -p stable --exit=error,warning
    eselect news read
