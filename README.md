# gentoozinho

An opinionated Hyprland desktop for Gentoo, installed the Gentoo way: a real
ebuild repository with its own profiles and meta-packages, plus one bootstrap
script. Inspired by [Omarchy](https://omarchy.org).

gentoozinho is an unofficial community project. It is not affiliated with or
endorsed by Gentoo Linux or the Gentoo Foundation. Gentoo is a trademark of
the Gentoo Foundation, Inc. See <https://www.gentoo.org>.

## Status

Phase 2 done: the VM boots into SDDM, logs into a themed Hyprland session
with waybar, walker, mako, hyprlock, hypridle and swaybg, and the smoke test
proves it with a screenshot taken inside the session. The payload
(`app-misc/gentoozinho`) installs helper scripts, defaults, four themes
(tokyo-night, catppuccin, gruvbox, nord) and user config templates;
`gentoozinho-theme-set NAME` switches themes live. Phase 1 proved the overlay,
profiles, meta-packages and installer on the official Gentoo cloud-init image
(430 packages, 368 binary). Design:
`docs/superpowers/specs/2026-09-27-gentoozinho-design.md`. Notes on what the
work taught: `docs/learning/`.

Known: Hyprland 0.56 warns that `.conf` config support ends in 0.57; the Lua
migration is the next structural job. Real hardware (`desktop` profile) is
still untested (phase 3). A 20 GB disk is tight for a VM that compiles; give it
25 GB or more.

Configs and themes are adapted from [Omarchy](https://omarchy.org) v3.8.4
(MIT) by Basecamp.

## Install

On a systemd Gentoo (amd64) with network, as root:

    git clone https://github.com/guilhermebr/gentoozinho.git
    cd gentoozinho
    ./install.sh

Flags: `--profile vm|desktop`, `--user NAME`, `--metas base,desktop,dev,apps`,
`--no-reboot`, `--autologin`, `--repo-url URL_OR_DIR`.

After a reboot, log in to the "gentoozinho (Hyprland, uwsm)" session. Useful
commands: `gentoozinho-theme-list`, `gentoozinho-theme-set NAME`,
`gentoozinho-theme-next`, `gentoozinho-refresh-config --init`,
`gentoozinho-update`. Super+K lists the key bindings.

What it does to your system: selects a gentoozinho profile (which inherits
Gentoo's desktop target), writes a few files named `gentoozinho` under
`/etc/portage`, enables the guru and hyproverlay overlays, then runs a full
`emerge --update --deep --newuse @world` plus the meta-packages. On an
out-of-date system that world update is the slow part. With the desktop meta
it also: enables SDDM as the display manager and NetworkManager as the
network stack (systemd-networkd gets disabled, which can drop a remote box);
deletes `/etc/kernel/config.d/dist-amd64-livecd.config` if present and, when
no installed kernel has graphics drivers, installs `gentoo-kernel-bin` and
unmerges the source kernel (its modules are gone until you reboot); creates
the `--user` account if you ask for one that does not exist, adds it to the
desktop groups, seeds `~/.config` and appends one line to `~/.bashrc`. Only
the `vm` profile on the cloud image has been tested so far; real hardware
(`desktop`) is phase 3. The SDDM greeter itself (without `--autologin`) has
had only a manual check.

## Develop

    test/unit.sh        # bats unit tests (docker)
    test/lint.sh        # shellcheck (docker)
    test/vm-smoke.sh    # full install, reboot into the session, screenshot (needs a VM)

The smoke VM is a [Lima](https://lima-vm.io) instance: `test/vm-smoke.sh`
resolves the current official Gentoo cloud-init image, boots it in plain mode
with a virtio-vga display on VNC (`~/.lima/gz-smoke/vncdisplay` and
`vncpassword`), and drives it over ssh. Needs `limactl`, QEMU/KVM and OVMF.
To reuse a VM you booted yourself, set `GZ_SMOKE_SSH="ssh -p PORT user@host"`.

## License

MIT.
