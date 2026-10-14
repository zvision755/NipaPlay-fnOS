#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_root="${FLUTTER_ROOT:-$PWD/.porting/tools/flutter}"
kernel="${NIPAPLAY_SERVER_KERNEL:-build/fnos/server.dill}"
if [[ "${1:-}" == '--compile' ]]; then scripts/compile_fnos_server.sh "$kernel"; fi
engine="${NIPAPLAY_ENGINE:-}"
if [[ -z "$engine" ]]; then
  engine="$(find "$flutter_root/bin/cache/artifacts/engine" -mindepth 2 -maxdepth 2 -name flutter_tester -print -quit)"
fi
exec "$engine" --disable-vm-service \
  --icu-data-file-path="$(dirname "$engine")/icudtl.dat" --non-interactive "$kernel"
