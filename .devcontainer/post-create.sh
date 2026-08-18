#!/usr/bin/env bash
set -euo pipefail

cd /workspace/Boorusama

# Windows bind mounts may expose repository shell scripts with CRLF endings.
# Normalize only the scripts used by initialization and code generation.
for script in init.sh gen.sh scripts/bootstrap.sh scripts/toolchain.sh; do
  sed -i 's/\r$//' "$script"
done

flutter --version
rustc --version
meson --version
nasm --version
bash ./init.sh

printf '\nContainer ready. Build the dev APK with:\n'
printf '  bash .devcontainer/build-android.sh\n'
printf 'Or attach Flutter to a host-connected device with:\n'
printf '  bash .devcontainer/run-android.sh [device-id]\n'
