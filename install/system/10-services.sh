# shellcheck shell=bash
# Desktop services. NetworkManager takes over from systemd-networkd.
systemctl enable NetworkManager.service bluetooth.service sddm.service
systemctl mask NetworkManager-wait-online.service
if systemctl is-enabled systemd-networkd.service > /dev/null 2>&1; then
  gz_log "disabling systemd-networkd in favour of NetworkManager"
  systemctl disable systemd-networkd.service systemd-networkd-wait-online.service || true
fi
