# shellcheck shell=bash
if gz_user_exists "$GZ_USER"; then
  gz_log "user ${GZ_USER} exists; ensuring desktop groups"
else
  if (( ! GZ_USER_EXPLICIT )); then
    gz_die "user '${GZ_USER}' does not exist; pass --user NAME (an existing account, or one to create)"
  fi
  gz_log "creating user ${GZ_USER}"
  useradd -m -s /bin/bash "$GZ_USER"
  GZ_USER_CREATED=1
  export GZ_USER_CREATED
fi
usermod -a -G "$(gz_user_groups)" "$GZ_USER"
