#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cache="${PUB_CACHE:-$PWD/.porting/pub-cache}"
target="$PWD/.porting/docker-pub"
# Export package sources only. Never export preferences, media, .env, or SDK caches.
for item in hosted hosted-hashes git; do
  [[ -d "$cache/$item" ]] || { echo "Missing package cache: run Flutter pub get first" >&2; exit 1; }
done
mkdir -p "$target"
for item in hosted hosted-hashes git; do
  COPYFILE_DISABLE=1 cp -R "$cache/$item" "$target/"
done
printf 'Public project package cache exported; Docker validates pubspec.lock offline.\n'
