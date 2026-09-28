# shellcheck shell=bash
# Pick the default theme only when the user has none yet; a re-run must not
# clobber their choice (or restart their bar from outside the session). A home
# upgraded from the hyprlang layout has a theme but no rendered Lua fragment
# yet, so re-render the theme it already uses.
current="$(gz_run_as_user "$GZ_USER" gentoozinho-theme-current)"
home="$(getent passwd "$GZ_USER" | cut -d: -f6)"
if [[ $current == none ]]; then
  gz_run_as_user "$GZ_USER" gentoozinho-theme-set tokyo-night
elif [[ ! -f $home/.config/gentoozinho/current/theme/hyprland.lua ]]; then
  gz_log "re-rendering theme ${current} for the Lua config"
  gz_run_as_user "$GZ_USER" gentoozinho-theme-set "$current"
else
  gz_log "user ${GZ_USER} already has a theme; leaving it alone"
fi
