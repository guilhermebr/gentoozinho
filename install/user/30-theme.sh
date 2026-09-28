# shellcheck shell=bash
# Pick the default theme only when the user has none yet; a re-run must not
# clobber their choice (or restart their bar from outside the session).
if [[ "$(gz_run_as_user "$GZ_USER" gentoozinho-theme-current)" == none ]]; then
  gz_run_as_user "$GZ_USER" gentoozinho-theme-set tokyo-night
else
  gz_log "user ${GZ_USER} already has a theme; leaving it alone"
fi
