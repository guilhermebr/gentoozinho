#!/usr/bin/env bash
# Run the bats unit tests inside the official bats image (bats is not on the host).
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm -v "$PWD:/code" -w /code bats/bats:1.14.0 "${@:-test/unit}"
