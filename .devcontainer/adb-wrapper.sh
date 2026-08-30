#!/usr/bin/env bash
set -euo pipefail

real_adb="$(dirname "$0")/adb.real"
args=("$@")

forward_index=-1
for index in "${!args[@]}"; do
  if [[ "${args[$index]}" == "forward" ]]; then
    forward_index=$index
    break
  fi
done

if (( forward_index >= 0 )); then
  operation="${args[$((forward_index + 1))]:-}"

  if [[ "$operation" == "--remove" ]]; then
    endpoint="${args[$((forward_index + 2))]:-}"
    "$real_adb" "${args[@]}"
    if [[ "$endpoint" == tcp:* ]]; then
      port="${endpoint#tcp:}"
      pid_file="/tmp/boorusama-adb-forward-${port}.pid"
      if [[ -f "$pid_file" ]]; then
        kill "$(<"$pid_file")" 2>/dev/null || true
        rm -f "$pid_file"
      fi
    fi
    exit 0
  fi

  if [[ "$operation" == tcp:* ]]; then
    output="$("$real_adb" "${args[@]}")"
    printf '%s' "$output"

    port="${operation#tcp:}"
    if [[ "$port" == "0" ]]; then
      port="${output##*$'\n'}"
    fi

    if [[ "$port" =~ ^[0-9]+$ ]]; then
      pid_file="/tmp/boorusama-adb-forward-${port}.pid"
      if [[ -f "$pid_file" ]]; then
        kill "$(<"$pid_file")" 2>/dev/null || true
      fi
      socat \
        "TCP-LISTEN:${port},bind=127.0.0.1,reuseaddr,fork" \
        "TCP:host.docker.internal:${port}" \
        </dev/null >/tmp/boorusama-adb-forward-${port}.log 2>&1 &
      printf '%s\n' "$!" >"$pid_file"
    fi
    exit 0
  fi
fi

exec "$real_adb" "${args[@]}"
