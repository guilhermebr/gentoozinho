# shellcheck shell=bash
# The Gentoo cloud image ships a kernel config snippet that disables DRM
# (CONFIG_DRM=n) to keep a headless image small. A desktop cannot live with
# it, and it must go before any kernel gets (re)built by the packages stage.
livecd_cfg="${GZ_ROOT}/etc/kernel/config.d/dist-amd64-livecd.config"
if [[ -f $livecd_cfg ]]; then
  gz_log "removing the cloud image's headless kernel config: ${livecd_cfg}"
  rm -f "$livecd_cfg"
fi
