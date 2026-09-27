# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho apps: browser, office, media viewers"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-office/libreoffice-bin
	app-text/evince
	media-gfx/imv
	media-video/mpv
	www-client/chromium
"
