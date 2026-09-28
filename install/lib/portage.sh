# shellcheck shell=bash
# Portage configuration owned by gentoozinho. Everything lands under
# "${GZ_ROOT}/etc/portage"; unit tests point GZ_ROOT at a temp dir.

GZ_BINHOST_URI="https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64"

# gz_profile_family PROFILE_PATH -> vm | desktop
# After the first run make.profile already points at one of our profiles, so
# recognise those first (a re-run must never flip no-multilib to multilib).
# Otherwise the cloud image is no-multilib; everything else is a multilib desktop.
gz_profile_family() {
  case "$1" in
    */gentoozinho/profiles/vm) echo vm ;;
    */gentoozinho/profiles/desktop) echo desktop ;;
    *no-multilib*) echo vm ;;
    *) echo desktop ;;
  esac
}

# gz_current_profile -> target of the make.profile symlink
gz_current_profile() {
  readlink "${GZ_ROOT:-}/etc/portage/make.profile"
}

# gz_target_profile -> vm | desktop, honouring an explicit --profile
gz_target_profile() {
  if [[ "${GZ_PROFILE:-auto}" == auto ]]; then
    gz_profile_family "$(gz_current_profile)"
  else
    echo "$GZ_PROFILE"
  fi
}

# gz_makeopts NCPU MEM_MB -> "-jN -lN", N = min(ncpu, mem_mb/2048), at least 1.
# Gentoo's rule of thumb is about 2 GB of RAM per compile job.
gz_makeopts() {
  local ncpu="$1" mem_mb="$2" jobs
  jobs=$(( mem_mb / 2048 ))
  (( jobs > ncpu )) && jobs=$ncpu
  (( jobs < 1 )) && jobs=1
  echo "-j${jobs} -l${jobs}"
}

# gz_tree_needs_sync -> webrsync (no tree), sync (older than a day), fresh
gz_tree_needs_sync() {
  local ts="${GZ_ROOT:-}/var/db/repos/gentoo/metadata/timestamp.chk"
  if [[ ! -f "$ts" ]]; then
    echo webrsync
  elif (( $(date +%s) - $(stat -c %Y "$ts") > 86400 )); then
    echo sync
  else
    echo fresh
  fi
}

# gz_require_dir PATH: die clearly if PATH exists but is a regular file
# (hand-maintained systems sometimes keep package.* as single files).
gz_require_dir() {
  if [[ -e "$1" && ! -d "$1" ]]; then
    gz_die "$(basename "$1") is a file; gentoozinho needs $1 to be a directory. Move the file into it, e.g. $1/local, and re-run."
  fi
}

# gz_write_portage_config NCPU MEM_MB: write every /etc/portage file we own.
gz_write_portage_config() {
  local ncpu="$1" mem_mb="$2" etc="${GZ_ROOT:-}/etc/portage"
  local makeopts_line=""

  gz_require_dir "$etc/package.accept_keywords"
  gz_require_dir "$etc/package.license"

  # Respect a MAKEOPTS the user already tuned in make.conf (file or directory).
  if ! grep -rqs '^MAKEOPTS=' "$etc/make.conf"; then
    makeopts_line="MAKEOPTS=\"$(gz_makeopts "$ncpu" "$mem_mb")\""
  fi

  gz_write_file "$etc/package.accept_keywords/gentoozinho" <<'EOF_KW'
# Managed by gentoozinho. The Hypr stack, GURU and our own overlay are ~amd64 only.
*/*::hyproverlay ~amd64
*/*::gentoozinho ~amd64
*/*::guru ~amd64
# The payload is a git live ebuild (no KEYWORDS at all), so it needs **.
app-misc/gentoozinho **
# Packages in ::gentoo that are still ~amd64 but the desktop needs.
gui-apps/uwsm ~amd64
dev-cpp/sdbus-c++ ~amd64
app-shells/zoxide ~amd64
EOF_KW

  gz_write_file "$etc/package.license/gentoozinho" <<'EOF_LIC'
# Managed by gentoozinho. Firmware and microcode needed by the distribution kernel.
sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE
sys-firmware/intel-microcode intel-ucode
EOF_LIC

  gz_write_file "$etc/gentoozinho.conf" <<EOF_CONF
# Managed by gentoozinho and sourced from make.conf. Put local overrides in
# make.conf after the source line. MAKEOPTS is only set here when make.conf
# does not define it.
FEATURES="\${FEATURES} getbinpkg binpkg-request-signature"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --binpkg-respect-use=y --jobs=2 --load-average=${ncpu}"
${makeopts_line}
ACCEPT_LICENSE="\${ACCEPT_LICENSE} @FREE"
EOF_CONF

  if [[ -d "$etc/make.conf" ]]; then
    gz_write_file "$etc/make.conf/zz-gentoozinho" <<'EOF_SRC'
source /etc/portage/gentoozinho.conf
EOF_SRC
  else
    gz_ensure_line "$etc/make.conf" 'source /etc/portage/gentoozinho.conf'
  fi

  if ! grep -rqs 'binpackages/' "$etc/binrepos.conf"; then
    gz_write_file "$etc/binrepos.conf/gentoozinho.conf" <<EOF_BIN
# Managed by gentoozinho. Official Gentoo binary package host for amd64 23.0.
[gentoobinhost]
priority = 1
sync-uri = ${GZ_BINHOST_URI}
EOF_BIN
  fi
}
