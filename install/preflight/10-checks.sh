# shellcheck shell=bash
# Refuse early and clearly rather than fail halfway through an emerge.

gz_check_root "$(id -u)"
gz_check_arch "$(uname -m)"
gz_check_init "$(ps -p 1 -o comm=)"
for cmd in emerge eselect gcc rsync; do
  gz_check_cmd "$cmd"
done
gz_check_gcc "$(gcc -dumpfullversion)"
gz_check_network

GZ_TARGET_PROFILE="$(gz_target_profile)"
GZ_VIRT="$(systemd-detect-virt || true)"
export GZ_TARGET_PROFILE GZ_VIRT
gz_log "target profile gentoozinho:${GZ_TARGET_PROFILE}, virtualization: ${GZ_VIRT:-none}"
