# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho desktop: Hyprland session, bar, launcher, portals, audio, fonts"
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
