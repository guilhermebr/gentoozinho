# Copyright 2026 gentoozinho contributors
# Distributed under the terms of the MIT License

EAPI=8

DESCRIPTION="gentoozinho base: shell and command-line tools"
HOMEPAGE="https://github.com/guilhermebr/gentoozinho"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	app-admin/sudo
	app-editors/neovim
	app-misc/fastfetch
	app-misc/jq
	app-misc/tmux
	app-shells/fzf
	app-shells/starship
	app-shells/zoxide
	dev-vcs/git
	dev-vcs/lazygit
	sys-apps/bat
	sys-apps/eza
	sys-apps/fd
	sys-apps/ripgrep
	sys-process/btop
"
