# shellcheck shell=bash
# The cloud image ships without an ebuild tree at all, so the first run must
# fetch a snapshot (emerge-webrsync); later runs rsync only when stale.

case "$(gz_tree_needs_sync)" in
  webrsync) gz_log "no ebuild tree found, fetching a snapshot"; emerge-webrsync ;;
  sync)     gz_log "ebuild tree older than a day, syncing"; emerge --sync --quiet ;;
  fresh)    gz_log "ebuild tree is fresh, skipping sync" ;;
esac
