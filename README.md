# gentoozinho

An opinionated Hyprland desktop for Gentoo, installed the Gentoo way: a real
ebuild repository with its own profiles and meta-packages, plus one bootstrap
script. Inspired by [Omarchy](https://omarchy.org).

gentoozinho is an unofficial community project. It is not affiliated with or
endorsed by Gentoo Linux or the Gentoo Foundation. Gentoo is a trademark of
the Gentoo Foundation, Inc. See <https://www.gentoo.org>.

## Status

Phase 1 done: overlay, `vm` and `desktop` profiles, four meta-packages and the
installer. Proven on the official Gentoo cloud-init image (amd64, systemd) in
an 8 vCPU QEMU VM: 430 packages merged, 368 as binaries and 62 from source,
in about 4.5 hours of wall time dominated by gcc 16 and the kernel rebuild.
The second run is a no-op, `dev` and `apps` resolve, and `pkgcheck` is clean.
No desktop configuration is installed yet; that is phase 2. Design:
`docs/superpowers/specs/2026-09-27-gentoozinho-design.md`. Notes on what the
work taught: `docs/learning/`.

A 20 GB disk is tight for a VM that compiles; give it 25 GB or more.

## Install

On a systemd Gentoo (amd64) with network, as root:

    git clone https://github.com/guilhermebr/gentoozinho.git
    cd gentoozinho
    ./install.sh

Flags: `--profile vm|desktop`, `--user NAME`, `--metas base,desktop,dev,apps`,
`--no-reboot`, `--repo-url URL_OR_DIR`.

What it does to your system: selects a gentoozinho profile (which inherits
Gentoo's desktop target), writes a few files named `gentoozinho` under
`/etc/portage`, enables the guru and hyproverlay overlays, then runs a full
`emerge --update --deep --newuse @world` plus the meta-packages. On an
out-of-date system that world update is the slow part. Only the `vm` profile
on the cloud image has been tested so far; real hardware (`desktop`) is phase
3. Before trying it on metal: be on a 23.0 systemd profile and have
`sys-kernel/gentoo-kernel-bin` installed, or `virtual/dist-kernel` will pull
the source kernel and rebuild it.

## Develop

    test/unit.sh        # bats unit tests (docker)
    test/lint.sh        # shellcheck (docker)
    test/vm-smoke.sh    # full install in a govm VM (needs govm, KVM, OVMF)

## License

MIT.
