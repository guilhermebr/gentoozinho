# shellcheck shell=bash
# Preflight predicates. Each takes its input as an argument so tests can
# exercise them without root, systemd or a real compiler.

gz_check_root() {
  [[ "$1" == 0 ]] || gz_die "run as root (sudo ./install.sh)"
}

gz_check_arch() {
  [[ "$1" == x86_64 ]] || gz_die "gentoozinho supports amd64 only (got $1)"
}

gz_check_init() {
  [[ "$1" == systemd ]] || gz_die "PID 1 is '$1'; gentoozinho requires systemd (OpenRC is not supported)"
}

# gz_check_gcc VERSION (e.g. 15.3.0): gui-wm/hyprland needs gcc 15 or newer.
gz_check_gcc() {
  local major="${1%%.*}"
  (( major >= 15 )) || gz_die "gcc $1 is too old; gui-wm/hyprland needs gcc 15 or newer"
}

gz_check_cmd() {
  command -v "$1" > /dev/null 2>&1 || gz_die "required command not found: $1"
}

gz_check_network() {
  getent hosts distfiles.gentoo.org > /dev/null || gz_die "cannot resolve distfiles.gentoo.org; network is required"
}
