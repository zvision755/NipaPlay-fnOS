#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export NIPAPLAY_SOURCE_REVISION="$(git rev-parse HEAD)"
export NIPAPLAY_SOURCE_DIGEST="$(
  {
    git rev-parse HEAD
    git diff --binary HEAD
    git ls-files --others --exclude-standard -z | while IFS= read -r -d '' file; do
      [[ -f "$file" ]] && shasum -a 256 "$file"
    done
    git submodule status --recursive
  } | shasum -a 256 | cut -d ' ' -f 1
)"
if [[ "${1:-}" == '--dev' ]]; then
  shift
  exec docker compose -f compose.yaml -f compose.dev.yaml "$@"
fi
exec docker compose -f compose.yaml "$@"
