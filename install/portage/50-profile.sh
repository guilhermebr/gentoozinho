# shellcheck shell=bash
# Select gentoozinho:vm or gentoozinho:desktop (see gz_target_profile).
want="gentoozinho:${GZ_TARGET_PROFILE}"
current="$(eselect profile show | sed -n 2p | tr -d '[:space:]')"
if [[ "$current" == "$want" ]]; then
  gz_log "profile already ${want}"
else
  eselect profile set "$want"
fi
