# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho apps: browser, office, media viewers"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

# Chromium itself was masked for removal from ::gentoo on 2026-09-24
# (bug #982204); the remaining chromium-based browsers are all proprietary.
RDEPEND="
	app-office/libreoffice-bin
	app-text/evince
	media-gfx/imv
	media-video/mpv
	www-client/firefox-bin
"
