# shellcheck shell=bash
# eselect-repository manages repos.conf; git is needed for git-synced overlays.
emerge --noreplace --quiet app-eselect/eselect-repository dev-vcs/git
