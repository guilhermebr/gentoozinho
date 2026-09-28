# shellcheck shell=bash
# Seed ~/.config from the templates; never overwrites files the user already has.
gz_run_as_user "$GZ_USER" gentoozinho-refresh-config --init
