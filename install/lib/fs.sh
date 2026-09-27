# shellcheck shell=bash
# Idempotent file helpers. Callers pass full paths, already prefixed with
# "${GZ_ROOT}" so unit tests can run against a scratch directory.

# gz_ensure_line FILE LINE: append LINE unless an identical line exists.
gz_ensure_line() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : > "$file"
  grep -qxF -- "$line" "$file" && return 0
  printf '%s\n' "$line" >> "$file"
}

# gz_write_file FILE < content: write stdin to FILE only if it differs.
# Prints "changed" or "unchanged" so callers and tests can tell.
gz_write_file() {
  local file="$1" tmp
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  cat > "$tmp"
  if [[ -f "$file" ]] && cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    echo unchanged
    return 0
  fi
  install -m 0644 "$tmp" "$file"
  rm -f "$tmp"
  echo changed
}
