#!/usr/bin/env bash
# Run the Lua config modules on the host against a fake `hl` (needs lua5.4).
set -euo pipefail
cd "$(dirname "$0")/.."
export GENTOOZINHO_PATH="$PWD"
HOME="$(mktemp -d)"; export HOME
trap 'rm -rf "$HOME"' EXIT
lua5.4 test/lua/run.lua
