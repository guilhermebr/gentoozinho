# shellcheck shell=bash
# Resolve first so an unresolvable atom or a missing USE flag fails with
# Portage's own explanation instead of halfway through a build. We do not
# autounmask: a needed flag belongs in profiles/base/package.use, not in a
# machine-local file.

read -ra atoms <<< "$(gz_meta_atoms "$GZ_METAS")"
gz_log "resolving ${atoms[*]}"
emerge --pretend --quiet "${atoms[@]}" || gz_die "dependency resolution failed for ${atoms[*]}"

gz_log "merging ${atoms[*]} (binary packages where available)"
emerge --getbinpkg --keep-going=n --verbose "${atoms[@]}"
