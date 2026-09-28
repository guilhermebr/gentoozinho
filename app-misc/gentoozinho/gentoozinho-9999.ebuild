# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

inherit git-r3

DESCRIPTION="gentoozinho desktop payload: scripts, defaults, themes, config templates"
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
	gui-apps/hyprshot
	gui-apps/mako
	gui-apps/slurp
	gui-apps/swaybg
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
