# shellcheck shell=bash
# Wayland greeter driven by Hyprland, our session as default, autologin on request.
gz_sddm_conf "$GZ_USER" "$GZ_AUTOLOGIN" | gz_write_file "${GZ_ROOT}/etc/sddm.conf.d/10-gentoozinho.conf" > /dev/null
