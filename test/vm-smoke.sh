#!/usr/bin/env bash
# End-to-end: fresh Gentoo VM -> install.sh -> assertions -> second run is a no-op.
# Requires govm, KVM and a govm gentoo entry that boots (OVMF). Set GZ_KEEP_VM=1
# to keep the VM after success. Set GZ_SMOKE_SSH="ssh -p PORT user@host" to run
# against a VM you booted by hand instead of creating one with govm.
# shellcheck disable=SC2016  # single-quoted commands are expanded on the remote side on purpose
set -euo pipefail
cd "$(dirname "$0")/.."

VM="${GZ_SMOKE_VM:-gz-smoke}"
export GOVM_CPUS="${GOVM_CPUS:-8}" GOVM_MEM_MB="${GOVM_MEM_MB:-8192}"

if [[ -n "${GZ_SMOKE_SSH:-}" ]]; then
  vm() { ${GZ_SMOKE_SSH} -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$@"; }
else
  govm status "$VM" > /dev/null 2>&1 || govm create gentoo "$VM"
  vm() { govm ssh "$VM" -- "$@"; }
fi

step() { printf '\n### %s\n' "$*"; }

step "copy working tree into the VM"
tar --exclude=.git -cz . | vm 'rm -rf ~/src && mkdir ~/src && tar xz -C ~/src'

step "first install"
vm 'sudo ~/src/install.sh --profile vm --no-reboot --repo-url "$HOME/src"'

step "assertions"
vm 'eselect profile show | grep -q "gentoozinho:vm"'
vm 'grep -qx gentoozinho-meta/base /var/lib/portage/world'
vm 'grep -qx gentoozinho-meta/desktop /var/lib/portage/world'
vm 'Hyprland --version'
vm 'test -x /usr/bin/sddm && test -x /usr/bin/waybar && test -x /usr/bin/walker'
vm 'grep -qx "source /etc/portage/gentoozinho.conf" /etc/portage/make.conf'
vm 'test "$(ls /etc/portage/binrepos.conf | wc -l)" -eq 1'   # cloud image already had one

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
  yes | govm delete "$VM"
fi
