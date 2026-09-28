# shellcheck shell=bash
# User account helpers and the SDDM configuration text.

gz_user_exists() { getent passwd "$1" > /dev/null; }

gz_user_groups() { echo "wheel,users,video,audio,input,plugdev"; }

# gz_run_as_user NAME CMD...: run CMD as NAME with a proper HOME and PATH.
gz_run_as_user() {
  local user="$1"; shift
  local home; home="$(getent passwd "$user" | cut -d: -f6)"
  # runuser is util-linux, present on every Gentoo; the installer runs as root.
  runuser -u "$user" -- env HOME="$home" PATH="/usr/bin:/bin:/usr/local/bin" "$@"
}

# gz_sddm_conf USER AUTOLOGIN(0|1): print /etc/sddm.conf.d/10-gentoozinho.conf
gz_sddm_conf() {
  local user="$1" autologin="$2"
  cat <<EOF_SDDM
# Managed by gentoozinho.
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.lua
EOF_SDDM
  if (( autologin )); then
    cat <<EOF_AUTO

[Autologin]
User=${user}
Session=gentoozinho.desktop
EOF_AUTO
  fi
}

# gz_kernel_has_drm MODULES_DIR SYS_MODULE_DIR: 0 when any installed kernel
# ships DRM modules, or the running kernel has DRM built in.
gz_kernel_has_drm() {
  local moddir="$1" sysmod="$2"
  compgen -G "$moddir/*/kernel/drivers/gpu/drm" > /dev/null && return 0
  [[ -d $sysmod/drm ]]
}
