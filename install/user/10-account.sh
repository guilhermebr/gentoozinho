# shellcheck shell=bash
if gz_user_exists "$GZ_USER"; then
  gz_log "user ${GZ_USER} exists; ensuring desktop groups"
else
  gz_log "creating user ${GZ_USER}"
  useradd -m -s /bin/bash "$GZ_USER"
  gz_log "set a password with: passwd ${GZ_USER}"
fi
usermod -a -G "$(gz_user_groups)" "$GZ_USER"
