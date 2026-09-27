#!/usr/bin/env bash
# Lint every shell file in the repo with shellcheck, using the official image.
set -euo pipefail
cd "$(dirname "$0")/.."
# -co: tracked and untracked (not ignored), so new files are linted before they are added.
mapfile -t files < <(git ls-files -co --exclude-standard '*.sh' install.sh | sort -u)
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable -x -s bash "${files[@]}"
