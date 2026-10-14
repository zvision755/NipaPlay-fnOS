#!/usr/bin/env bash
# Run upstream's full Web build and reject its warning-only success path.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -x .porting/tools/flutter/bin/flutter ]]; then
  export PATH="$PWD/.porting/tools/flutter/bin:$PATH"
  export PUB_CACHE="$PWD/.porting/pub-cache"
fi
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true
mkdir -p .porting/logs
log=".porting/logs/web-build-$(date +%Y%m%d-%H%M%S).log"
# Flutter may restore cached compiler output with its original modification
# time. Isolate the old directory instead of treating mtime as freshness.
if [[ -d build/web ]]; then
  mv build/web ".porting/previous-web-$(date +%Y%m%d-%H%M%S)-$$"
fi
bash build_and_copy_web.sh 2>&1 | tee "$log"

if grep -q 'WARNING: Flutter web build failed' "$log"; then
  echo "Web build failed; see $log" >&2
  exit 1
fi
for file in index.html main.dart.js flutter_bootstrap.js; do
  for directory in build/web assets/web; do
    if [[ ! -s "$directory/$file" ]]; then
      echo "Missing Web output: $directory/$file" >&2
      exit 1
    fi
  done
  if ! cmp -s "build/web/$file" "assets/web/$file"; then
    echo "Copied Web output differs: $file" >&2
    exit 1
  fi
done
echo "Current Flutter Web output and copied files verified. Browser and backend tests are still required."
