#!/usr/bin/env bash
# End-to-end: fresh Gentoo VM -> install.sh -> assertions -> second run is a no-op.
# Requires limactl (Lima), QEMU/KVM and OVMF. The VM is the current official
# Gentoo cloud-init build, booted in Lima plain mode with a virtio-vga display
# served on VNC (see ~/.lima/$VM/vncdisplay). Set GZ_KEEP_VM=1 to keep the VM
# after success. Set GZ_SMOKE_SSH="ssh -p PORT user@host" to run against a VM
# you booted by hand instead of creating one with Lima.
# shellcheck disable=SC2016  # single-quoted commands are expanded on the remote side on purpose
set -euo pipefail
cd "$(dirname "$0")/.."

VM="${GZ_SMOKE_VM:-gz-smoke}"
GZ_SMOKE_CPUS="${GZ_SMOKE_CPUS:-8}" GZ_SMOKE_MEM="${GZ_SMOKE_MEM:-8}" GZ_SMOKE_DISK="${GZ_SMOKE_DISK:-30}"   # memory and disk in GiB
GENTOO_CLOUD="https://distfiles.gentoo.org/releases/amd64/autobuilds/current-di-amd64-cloudinit/"

if [[ -n "${GZ_SMOKE_SSH:-}" ]]; then
  vm() { ${GZ_SMOKE_SSH} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"; }
else
  if ! limactl list -q | grep -qx "$VM"; then
    # Gentoo publishes only dated filenames and prunes them after about a week,
    # so resolve the current build from the signed pointer at create time.
    img="$(curl -fsSL "${GENTOO_CLOUD}latest-di-amd64-cloudinit.txt" | awk '/\.qcow2/ {print $1; exit}')"
    [[ -n "$img" ]] || { echo "could not resolve the current Gentoo cloud image" >&2; exit 1; }
    limactl start --name "$VM" --plain --tty=false \
      --cpus "$GZ_SMOKE_CPUS" --memory "$GZ_SMOKE_MEM" --disk "$GZ_SMOKE_DISK" \
      --set '.video.display="vnc"' "${GENTOO_CLOUD}${img}"
  else
    limactl start --tty=false "$VM"
  fi
  # Plain ssh (not `limactl shell`) so single-quoted commands expand on the remote side, as before.
  vm() { ssh -F "$HOME/.lima/$VM/ssh.config" "lima-$VM" "$@"; }
fi

step() { printf '\n### %s\n' "$*"; }

if [[ -n "$(git status --porcelain)" ]]; then
  echo "commit first: app-misc/gentoozinho is a git live ebuild and installs the committed HEAD" >&2
  exit 1
fi

step "copy working tree (with .git) into the VM"
tar --exclude=test/artifacts -cz . | vm 'rm -rf ~/src && mkdir ~/src && tar xz -C ~/src'

step "first install"
vm 'sudo ~/src/install.sh --profile vm --no-reboot --autologin --repo-url "$HOME/src"'

step "assertions"
vm 'eselect profile show | grep -q "gentoozinho:vm"'
vm 'grep -qx gentoozinho-meta/base /var/lib/portage/world'
vm 'grep -qx gentoozinho-meta/desktop /var/lib/portage/world'
vm 'Hyprland --version'
vm 'test -x /usr/bin/sddm && test -x /usr/bin/waybar && test -x /usr/bin/walker'
vm 'grep -qx "source /etc/portage/gentoozinho.conf" /etc/portage/make.conf'
vm 'test "$(ls /etc/portage/binrepos.conf | wc -l)" -eq 1'   # cloud image already had one
vm 'test -x /usr/bin/gentoozinho-theme-set && test -f /usr/share/wayland-sessions/gentoozinho.desktop'
vm 'test "$(gentoozinho-theme-current)" != none && test -f ~/.config/hypr/hyprland.lua && grep -q gentoozinho ~/.bashrc'
vm 'grep -q "^Session=gentoozinho.desktop" /etc/sddm.conf.d/10-gentoozinho.conf && systemctl is-enabled sddm NetworkManager bluetooth'

step "reboot into the desktop session"
vm 'sudo systemctl reboot' || true
sleep 20
for _ in $(seq 1 30); do vm true 2> /dev/null && break; sleep 5; done
vm 'systemctl is-active sddm'
vm 'systemctl is-active NetworkManager'
vm 'for _ in $(seq 1 30); do pgrep -x Hyprland > /dev/null && break; sleep 2; done; pgrep -x Hyprland'
vm 'loginctl list-sessions --no-legend | grep -q "$(id -un)"'
vm 'sleep 5; pgrep -x waybar && pgrep -x mako && pgrep -x hypridle && pgrep -x swaybg'

step "screenshot from inside the session"
mkdir -p test/artifacts
vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -m1 "^wayland-[0-9]$"); grim /tmp/shot.png && hyprctl -j clients > /tmp/clients.json'
vm 'cat /tmp/shot.png' > test/artifacts/smoke.png
[[ -s test/artifacts/smoke.png ]]
vm 'test -f ~/.config/hypr/hyprland.lua && test ! -e ~/.config/hypr/hyprland.conf'
vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); hyprctl -j binds | grep -q "gentoozinho-launch-terminal"'

step "theme switching inside the session"
vm 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr | head -1); gentoozinho-theme-set catppuccin && test "$(gentoozinho-theme-current)" = catppuccin && hyprctl getoption general:col.active_border | grep -qi 89b4fa'

step "SDDM greeter without autologin (Hyprland as greeter compositor)"
vm 'sudo sed -i "/^\[Autologin\]/,\$d" /etc/sddm.conf.d/10-gentoozinho.conf && sudo systemctl restart sddm'
sleep 20
vm 'pgrep -f sddm-greeter-qt6 > /dev/null && pgrep -x Hyprland > /dev/null'
vm 'sudo journalctl -u sddm --since -30s --no-pager | grep -qi CrashExit && exit 1 || true'
vm 'sock=$(sudo ls /run/user/$(id -u sddm) | grep -m1 "^wayland-[0-9]$"); sudo -u sddm env XDG_RUNTIME_DIR=/run/user/$(id -u sddm) WAYLAND_DISPLAY=$sock timeout 20 grim /tmp/greeter.png && sudo chmod 644 /tmp/greeter.png'
vm 'cat /tmp/greeter.png' > test/artifacts/greeter.png
[[ -s test/artifacts/greeter.png ]]

step "second run (no --profile: auto-detect must keep vm) changes nothing under /etc/portage"
before="$(vm 'sudo find /etc/portage -type f -exec md5sum {} + | sort | md5sum')"
vm 'sudo ~/src/install.sh --no-reboot --repo-url "$HOME/src"'
after="$(vm 'sudo find /etc/portage -type f -exec md5sum {} + | sort | md5sum')"
[[ "$before" == "$after" ]] || { echo "FAIL: second run modified /etc/portage"; exit 1; }

step "dev and apps metas resolve"
vm 'sudo emerge --pretend --quiet gentoozinho-meta/dev gentoozinho-meta/apps'

step "pkgcheck on the overlay"
vm 'sudo emerge --noreplace --quiet dev-util/pkgcheck && pkgcheck scan -r gentoozinho -p stable --keywords=-UnknownCategoryDirs --exit=error,warning'

echo
echo "SMOKE OK"
if [[ -z "${GZ_SMOKE_SSH:-}" && -z "${GZ_KEEP_VM:-}" ]]; then
  limactl delete --force "$VM"
fi
