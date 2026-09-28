# shellcheck shell=bash
# Command-line parsing. Results are exported as GZ_* so sourced steps see them.

GZ_DEFAULT_REPO_URL="https://github.com/guilhermebr/gentoozinho.git"

gz_usage() {
  cat >&2 <<'USAGE'
usage: install.sh [--profile vm|desktop] [--user NAME] [--metas LIST]
                  [--no-reboot] [--repo-url URL_OR_DIR]

  --profile    gentoozinho profile to select (default: detected from the
               current profile; no-multilib -> vm, otherwise desktop)
  --user       login user to create/configure (default: $SUDO_USER or gentoo)
  --metas      comma-separated subset of base,desktop,dev,apps
               (default: base,desktop)
  --no-reboot  do not offer to reboot at the end
  --autologin  log the user straight into the gentoozinho session (SDDM autologin)
  --repo-url   git URL or local directory of the gentoozinho repository
USAGE
}

# gz_need_value FLAG COUNT: die if the flag has no value after it.
gz_need_value() {
  (( $2 >= 2 )) || gz_die "$1 needs a value"
}

gz_parse_args() {
  GZ_PROFILE="auto"
  GZ_USER="${SUDO_USER:-gentoo}"
  GZ_METAS="base,desktop"
  GZ_NO_REBOOT=0
  GZ_AUTOLOGIN=0
  GZ_REPO_URL="$GZ_DEFAULT_REPO_URL"

  while (( $# )); do
    case "$1" in
      --profile)   gz_need_value "$1" $#; GZ_PROFILE="$2"; shift 2 ;;
      --user)      gz_need_value "$1" $#; GZ_USER="$2"; shift 2 ;;
      --metas)     gz_need_value "$1" $#; GZ_METAS="$2"; shift 2 ;;
      --repo-url)  gz_need_value "$1" $#; GZ_REPO_URL="$2"; shift 2 ;;
      --no-reboot) GZ_NO_REBOOT=1; shift ;;
      --autologin) GZ_AUTOLOGIN=1; shift ;;
      -h|--help)   gz_usage; exit 0 ;;
      *)           gz_usage; gz_die "unknown argument: $1" ;;
    esac
  done

  case "$GZ_PROFILE" in
    auto|vm|desktop) ;;
    *) gz_die "--profile must be vm or desktop (got $GZ_PROFILE)" ;;
  esac

  local m
  for m in ${GZ_METAS//,/ }; do
    case "$m" in
      base|desktop|dev|apps) ;;
      *) gz_die "unknown meta: $m (choose from base,desktop,dev,apps)" ;;
    esac
  done

  export GZ_PROFILE GZ_USER GZ_METAS GZ_NO_REBOOT GZ_AUTOLOGIN GZ_REPO_URL
}

# gz_meta_atoms "base,desktop" -> "gentoozinho-meta/base gentoozinho-meta/desktop"
gz_meta_atoms() {
  local out=() m
  for m in ${1//,/ }; do
    out+=("gentoozinho-meta/$m")
  done
  echo "${out[*]}"
}

# gz_repo_kind URL_OR_DIR -> local if it is an existing directory, else git
gz_repo_kind() {
  if [[ -d "$1" ]]; then echo local; else echo git; fi
}
