#!/usr/bin/env bash
set -euo pipefail

cd /workspace/Boorusama

flutter --version
rustc --version
meson --version
nasm --version
flutter pub get

printf '\nContainer ready. Build the dev APK with:\n'
printf '  bash .devcontainer/build-android.sh\n'
printf 'Or attach Flutter to a host-connected device with:\n'
printf '  bash .devcontainer/run-android.sh [device-id]\n'
