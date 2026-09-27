# shellcheck shell=bash
# Portage configuration owned by gentoozinho. Everything lands under
# "${GZ_ROOT}/etc/portage"; unit tests point GZ_ROOT at a temp dir.

GZ_BINHOST_URI="https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64"

# gz_profile_family PROFILE_PATH -> vm | desktop
# The cloud image is no-multilib; everything else is treated as a multilib desktop.
gz_profile_family() {
  case "$1" in
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

# gz_write_portage_config NCPU MEM_MB: write every /etc/portage file we own.
gz_write_portage_config() {
  local ncpu="$1" mem_mb="$2" etc="${GZ_ROOT:-}/etc/portage"

  gz_write_file "$etc/package.accept_keywords/gentoozinho" <<'EOF_KW'
# Managed by gentoozinho. The Hypr stack, GURU and our own overlay are ~amd64 only.
*/*::hyproverlay ~amd64
*/*::gentoozinho ~amd64
*/*::guru ~amd64
EOF_KW

  gz_write_file "$etc/package.license/gentoozinho" <<'EOF_LIC'
# Managed by gentoozinho. Firmware and microcode needed by the distribution kernel.
sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE
sys-firmware/intel-microcode intel-ucode
EOF_LIC

  gz_write_file "$etc/gentoozinho.conf" <<EOF_CONF
# Managed by gentoozinho and sourced from make.conf. Put local overrides in
# make.conf after the source line.
FEATURES="\${FEATURES} getbinpkg binpkg-request-signature"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --binpkg-respect-use=y --jobs=2 --load-average=${ncpu}"
MAKEOPTS="$(gz_makeopts "$ncpu" "$mem_mb")"
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
