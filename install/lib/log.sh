# shellcheck shell=bash
# Logging. install.sh already tees all output to the log file, so these only
# need to write to stderr with a recognisable prefix.

GZ_LOG_FILE="${GZ_LOG_FILE:-${GZ_ROOT:-}/var/log/gentoozinho/install.log}"

gz_log() {
  printf '%s [gentoozinho] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}

gz_die() {
  gz_log "ERROR: $*"
  exit 1
}
