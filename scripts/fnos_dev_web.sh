#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_root="${FLUTTER_ROOT:-$PWD/.porting/tools/flutter}"
export PUB_CACHE="${PUB_CACHE:-$PWD/.porting/pub-cache}"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true
printf 'Development Web URL: http://127.0.0.1:1183/?api=http%%3A%%2F%%2F127.0.0.1%%3A1182\n'
exec "$flutter_root/bin/flutter" run -d web-server --web-hostname 127.0.0.1 --web-port 1183 "$@"
