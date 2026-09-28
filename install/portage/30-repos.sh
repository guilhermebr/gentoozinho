# shellcheck shell=bash
# Enable the overlays we depend on and register gentoozinho itself, either as a
# git repo (normal install) or as a copy of a local checkout (tests).

etc="${GZ_ROOT}/etc/portage"

# Portage finds ::gentoo through its built-in defaults, but pkgcore (and so
# pkgcheck) only reads repos.conf. The Handbook recommends this copy too.
if [[ ! -f "$etc/repos.conf/gentoo.conf" ]]; then
  mkdir -p "$etc/repos.conf"
  cp /usr/share/portage/config/repos.conf "$etc/repos.conf/gentoo.conf"
fi

# gentoozinho lists guru and hyproverlay as masters, so they must exist and be
# synced before gentoozinho itself is registered.
for repo in guru hyproverlay; do
  if grep -qs "^\[${repo}\]" "$etc"/repos.conf/*; then
    gz_log "repo ${repo} already enabled"
  else
    eselect repository enable "$repo"
  fi
  emaint sync -r "$repo"
done

case "$(gz_repo_kind "$GZ_REPO_URL")" in
  local)
    gz_write_file "$etc/repos.conf/gentoozinho.conf" <<'CONF'
# Managed by gentoozinho (local checkout, not synced).
[gentoozinho]
location = /var/db/repos/gentoozinho
auto-sync = no
CONF
    rsync -a --delete --exclude .git "${GZ_REPO_URL%/}/" "${GZ_ROOT}/var/db/repos/gentoozinho/"
    # app-misc/gentoozinho is a git live ebuild: make git-r3 clone this checkout
    # (its committed HEAD) instead of GitHub. git-r3 names the override after the
    # repository URL (guilhermebr/gentoozinho.git), not after the package.
    if git -C "$GZ_REPO_URL" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
      export EGIT_OVERRIDE_REPO_GUILHERMEBR_GENTOOZINHO="file://${GZ_REPO_URL%/}"
      EGIT_OVERRIDE_BRANCH_GUILHERMEBR_GENTOOZINHO="$(git -C "$GZ_REPO_URL" rev-parse --abbrev-ref HEAD)"
      export EGIT_OVERRIDE_BRANCH_GUILHERMEBR_GENTOOZINHO
      gz_log "git-r3 will clone app-misc/gentoozinho from ${EGIT_OVERRIDE_REPO_GUILHERMEBR_GENTOOZINHO} (${EGIT_OVERRIDE_BRANCH_GUILHERMEBR_GENTOOZINHO})"
    fi
    ;;
  git)
    if grep -qs '^\[gentoozinho\]' "$etc"/repos.conf/*; then
      gz_log "repo gentoozinho already registered"
    else
      eselect repository add gentoozinho git "$GZ_REPO_URL"
    fi
    ;;
esac

if [[ "$(gz_repo_kind "$GZ_REPO_URL")" == git ]]; then
  emaint sync -r gentoozinho
fi
