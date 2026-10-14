#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_root="${FLUTTER_ROOT:-$PWD/.porting/tools/flutter}"
output="${1:-build/fnos/server.dill}"
mkdir -p "$(dirname "$output")"
host_artifacts="$(find "$flutter_root/bin/cache/artifacts/engine" -mindepth 2 -maxdepth 2 -name flutter_tester -print -quit)"
if [[ -z "$host_artifacts" ]]; then echo 'Missing Flutter headless engine; run flutter precache first' >&2; exit 1; fi
snapshot="$flutter_root/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
"$flutter_root/bin/cache/dart-sdk/bin/dartaotruntime" "$snapshot" \
  --sdk-root "$flutter_root/bin/cache/artifacts/engine/common/flutter_patched_sdk/" \
  --target=flutter --no-print-incremental-dependencies --packages .dart_tool/package_config.json \
  --output-dill "$output" server/fnos/main.dart
[[ -s "$output" ]]
