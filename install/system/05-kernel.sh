# shellcheck shell=bash
# Make sure a DRM-capable kernel is installed. A kernel built while the
# headless snippet was in place has no graphics drivers at all; the binary
# distribution kernel is the fast way out (the source one goes at reboot).
if gz_kernel_has_drm "${GZ_ROOT}/lib/modules" "${GZ_ROOT}/sys/module"; then
  gz_log "an installed kernel has DRM support"
else
  gz_log "no installed kernel has DRM support; installing sys-kernel/gentoo-kernel-bin"
  emerge --getbinpkg --quiet sys-kernel/gentoo-kernel-bin
  if compgen -G "${GZ_ROOT}/var/db/pkg/sys-kernel/gentoo-kernel-[0-9]*" > /dev/null; then
    gz_log "removing the DRM-less source kernel; the new one boots next time"
    emerge -C --quiet sys-kernel/gentoo-kernel
  fi
fi
