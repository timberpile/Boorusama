#!/usr/bin/env bash
set -euo pipefail

workspace=${BOORUSAMA_WORKSPACE:?BOORUSAMA_WORKSPACE is required}
bash "$workspace/.devcontainer/validate-workspace.sh"
cd "$workspace"

# Avoid false-positive Git changes caused by Linux stat metadata on Windows bind mounts.
git config --global core.checkStat minimal
# Treat CRLF files from Windows worktree checkouts as clean in the Linux container.
git config --global core.autocrlf true

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
