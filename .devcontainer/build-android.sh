#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

bash ./gen.sh

flutter build apk \
  --no-pub \
  --debug \
  --flavor dev

printf '\nAPK: %s\n' "$PWD/build/app/outputs/flutter-apk/app-dev-debug.apk"
