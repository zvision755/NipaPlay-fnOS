#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_root="${FLUTTER_ROOT:-$PWD/.porting/tools/flutter}"
expected=ee80f08bbf97172ec030b8751ceab557177a34a6
[[ "$(git -C "$flutter_root" rev-parse HEAD)" == "$expected" ]] || { echo 'Flutter SDK revision mismatch' >&2; exit 1; }
target="$PWD/.porting/docker-sdk/flutter"
if [[ ! -f "$target/.ready" ]]; then
  mkdir -p "$target/.git"
  COPYFILE_DISABLE=1 tar -C "$flutter_root" --exclude=./bin/cache --exclude=./.git -cf - . | tar -xf - -C "$target"
  for item in objects refs HEAD index shallow packed-refs; do
    [[ ! -e "$flutter_root/.git/$item" ]] || cp -R "$flutter_root/.git/$item" "$target/.git/$item"
  done
  # Export only public SDK metadata; do not copy credential helpers or logs.
  cat > "$target/.git/config" <<'CONFIG'
[core]
  repositoryformatversion = 0
  bare = false
[remote "origin"]
  url = https://github.com/flutter/flutter.git
  fetch = +refs/heads/*:refs/remotes/origin/*
CONFIG
  printf "%s\n" "$expected" > "$target/.ready"
fi
[[ "$(git -C "$target" rev-parse HEAD)" == "$expected" ]]
printf 'Flutter source snapshot: %s\n' "$expected"
