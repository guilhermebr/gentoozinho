#!/usr/bin/env bash
# gentoozinho installer: turns a systemd Gentoo into a Hyprland desktop.
# Idempotent: re-running converges. Everything is logged to
# /var/log/gentoozinho/install.log.
set -Eeuo pipefail

GZ_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GZ_SRC
export GZ_ROOT="${GZ_ROOT:-}"

# shellcheck source=install/lib/all.sh
source "${GZ_SRC}/install/lib/all.sh"

gz_parse_args "$@"

# Root is needed for the log directory itself, so check before anything else.
gz_check_root "$(id -u)"

if [[ "$GZ_LOG_FILE" != /dev/null ]]; then
  mkdir -p "$(dirname "$GZ_LOG_FILE")"
  exec > >(tee -a "$GZ_LOG_FILE") 2>&1
fi

GZ_CURRENT_STEP=""
trap 'gz_log "FAILED in ${GZ_CURRENT_STEP:-startup}; see ${GZ_LOG_FILE}"' ERR

gz_log "gentoozinho install starting (profile=${GZ_PROFILE} metas=${GZ_METAS} user=${GZ_USER})"

for stage in preflight portage packages system user finish; do
  # The desktop session stages only make sense when the desktop meta is chosen.
  if [[ $stage == system || $stage == user ]] && ! gz_meta_selected desktop; then
    gz_log "skipping the ${stage} stage: gentoozinho-meta/desktop not selected"
    continue
  fi
  for step in "${GZ_SRC}/install/${stage}/"[0-9][0-9]-*.sh; do
    GZ_CURRENT_STEP="${step#"${GZ_SRC}/"}"
    gz_log "==> ${GZ_CURRENT_STEP}"
    # shellcheck disable=SC1090
    source "$step"
  done
done

gz_log "done."
