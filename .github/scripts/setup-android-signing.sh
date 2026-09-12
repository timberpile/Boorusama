#!/usr/bin/env bash
set -euo pipefail
umask 077

if (($# != 2)); then
  echo "Usage: $0 <keystore-path> <key-properties-path>" >&2
  exit 2
fi

required=(
  ANDROID_KEYSTORE_BASE64
  ANDROID_KEYSTORE_PASSWORD
  ANDROID_KEY_ALIAS
  ANDROID_KEY_PASSWORD
)
missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
if ((${#missing[@]} > 0)); then
  echo "Missing release signing secret(s): ${missing[*]}" >&2
  exit 1
fi

keystore_path=$(realpath -m "$1")
properties_path=$(realpath -m "$2")
mkdir -p "$(dirname "$keystore_path")" "$(dirname "$properties_path")"

printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$keystore_path"
keytool -list \
  -keystore "$keystore_path" \
  -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias "$ANDROID_KEY_ALIAS" >/dev/null

printf '%s\n' \
  "storeFile=$keystore_path" \
  "storePassword=$ANDROID_KEYSTORE_PASSWORD" \
  "keyAlias=$ANDROID_KEY_ALIAS" \
  "keyPassword=$ANDROID_KEY_PASSWORD" > "$properties_path"

certificate_output=$(keytool -list -v \
  -keystore "$keystore_path" \
  -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias "$ANDROID_KEY_ALIAS")
certificate_sha256=$(sed -n 's/.*SHA256:[[:space:]]*//p' <<< "$certificate_output" \
  | head -n 1 \
  | tr -d '[:space:]:' \
  | tr '[:lower:]' '[:upper:]')

if [[ ! "$certificate_sha256" =~ ^[0-9A-F]{64}$ ]]; then
  echo 'Could not derive a SHA-256 certificate digest from the release keystore.' >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'certificate_sha256=%s\n' "$certificate_sha256" >> "$GITHUB_OUTPUT"
fi

echo "Release keystore alias '$ANDROID_KEY_ALIAS' is valid."
