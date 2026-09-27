# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho dev: containers and developer tooling"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-containers/docker
	app-containers/docker-buildx
	app-containers/docker-compose
	gentoozinho-meta/base
"
