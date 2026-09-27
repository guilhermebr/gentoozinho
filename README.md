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
