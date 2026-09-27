# shellcheck shell=bash
# Keywords, licenses, binhost, FEATURES and MAKEOPTS that profiles cannot carry.
mem_mb="$(awk '/MemTotal/ { print int($2 / 1024) }' /proc/meminfo)"
gz_write_portage_config "$(nproc)" "$mem_mb"
