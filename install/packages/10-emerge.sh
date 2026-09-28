# shellcheck shell=bash
# Resolve first so an unresolvable atom or a missing USE flag fails with
# Portage's own explanation instead of halfway through a build. We never let
# Portage write USE or keyword changes for us: a needed flag belongs in
# profiles/base/package.use, not in a machine-local file.
#
# Selecting a gentoozinho profile changes global USE flags, so installed
# packages need rebuilding with their new flags: that is what
# --update --deep --newuse @world does, exactly as the Handbook prescribes
# after any profile change.

read -ra atoms <<< "$(gz_meta_atoms "$GZ_METAS")"
gz_log "resolving @world update plus ${atoms[*]}"
emerge --pretend --quiet --update --deep --newuse @world "${atoms[@]}" \
  || gz_die "dependency resolution failed for ${atoms[*]}"

gz_log "merging (binary packages where available)"
emerge --getbinpkg --keep-going=n --verbose --update --deep --newuse @world "${atoms[@]}"

# A git live ebuild is never re-merged by a world update, so a re-run of the
# installer would keep a stale payload. Refresh it explicitly.
if [[ -d "${GZ_ROOT}/var/db/pkg/app-misc/gentoozinho-9999" ]]; then
  gz_log "refreshing the live payload (app-misc/gentoozinho-9999)"
  emerge --oneshot --quiet app-misc/gentoozinho
fi
