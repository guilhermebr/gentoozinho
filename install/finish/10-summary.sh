# shellcheck shell=bash
gz_log "gentoozinho installed:"
gz_log "  profile : gentoozinho:${GZ_TARGET_PROFILE}"
gz_log "  metas   : ${GZ_METAS}"
gz_log "  log     : ${GZ_LOG_FILE}"

if (( GZ_NO_REBOOT )); then
  gz_log "reboot skipped (--no-reboot)"
elif [[ -t 0 ]]; then
  read -r -p "Reboot now? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    systemctl reboot
  fi
else
  gz_log "no tty; reboot when convenient"
fi
