#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! adb devices | grep -q $'\tdevice$'; then
  printf 'No Android device is available through the Windows ADB server.\n' >&2
  printf 'Run .devcontainer\\start-host-adb.ps1 on Windows and authorize the device.\n' >&2
  exit 1
fi

device_args=()
if [[ -n "${1:-}" ]]; then
  device_args=(-d "$1")
fi

flutter run "${device_args[@]}" \
  --debug \
  --flavor dev
