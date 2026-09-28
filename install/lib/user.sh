# shellcheck shell=bash
# User account helpers and the SDDM configuration text.

gz_user_exists() { getent passwd "$1" > /dev/null; }

gz_user_groups() { echo "wheel,users,video,audio,input,plugdev"; }

# gz_run_as_user NAME CMD...: run CMD as NAME with a proper HOME and PATH.
gz_run_as_user() {
  local user="$1"; shift
  local home; home="$(getent passwd "$user" | cut -d: -f6)"
  sudo -u "$user" env HOME="$home" PATH="/usr/bin:/bin:/usr/local/bin" "$@"
}

# gz_sddm_conf USER AUTOLOGIN(0|1): print /etc/sddm.conf.d/10-gentoozinho.conf
gz_sddm_conf() {
  local user="$1" autologin="$2"
  cat <<EOF_SDDM
# Managed by gentoozinho.
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=Hyprland -c /usr/share/gentoozinho/default/sddm/hyprland.conf
EOF_SDDM
  if (( autologin )); then
    cat <<EOF_AUTO

[Autologin]
User=${user}
Session=gentoozinho.desktop
EOF_AUTO
  fi
}
