# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

MY_PV="${PV/_alpha/-alpha}"
DESCRIPTION="gentoozinho desktop payload: scripts, defaults, themes, config templates"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"
SRC_URI="https://github.com/guilhermebr/gentoozinho/archive/refs/tags/v${MY_PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/${PN}-${MY_PV}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

# Tools the helper scripts call at runtime.
RDEPEND="
	app-misc/brightnessctl
	app-misc/jq
	app-shells/bash
	gnome-extra/polkit-gnome
	gui-apps/grim
	gui-apps/hypridle
	gui-apps/hyprlock
	gui-apps/hyprpicker
	gui-apps/hyprshot
	gui-apps/mako
	gui-apps/slurp
	gui-apps/swaybg
	gui-apps/swayosd
	gui-apps/uwsm
	gui-apps/walker
	gui-apps/waybar
	gui-apps/wl-clipboard
	gui-wm/hyprland
	x11-libs/libnotify
	x11-misc/xdg-utils
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
