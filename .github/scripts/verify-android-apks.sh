#!/usr/bin/env bash
set -euo pipefail

if (($# != 5)); then
  echo "Usage: $0 <apk-directory> <certificate-sha256> <application-id> <version-name> <version-code>" >&2
  exit 2
fi

apk_directory=$1
expected_digest=$(tr -d '[:space:]:' <<< "$2" | tr '[:lower:]' '[:upper:]')
expected_application_id=$3
expected_version_name=$4
expected_version_code=$5

[[ -d "$apk_directory" ]] || { echo "APK directory not found: $apk_directory" >&2; exit 1; }
[[ "$expected_digest" =~ ^[0-9A-F]{64}$ ]] || { echo 'Invalid expected certificate SHA-256 digest.' >&2; exit 1; }
[[ "$expected_version_code" =~ ^[0-9]+$ ]] || { echo 'Invalid expected base versionCode.' >&2; exit 1; }

declare -A apk_for_abi=()
while IFS= read -r -d '' apk; do
  case "$(basename "$apk")" in
    *-android-arm64.apk) abi=arm64-v8a ;;
    *-android-armv7.apk) abi=armeabi-v7a ;;
    *-android-x64.apk) abi=x86_64 ;;
    *) echo "Unexpected release APK name: $apk" >&2; exit 1 ;;
  esac
  [[ -z "${apk_for_abi[$abi]:-}" ]] || { echo "Duplicate release APK for $abi." >&2; exit 1; }
  apk_for_abi[$abi]=$apk
done < <(find "$apk_directory" -type f -name '*.apk' -print0)

expected_abis=(arm64-v8a armeabi-v7a x86_64)
declare -A version_code_offset=(
  [armeabi-v7a]=1000
  [arm64-v8a]=2000
  [x86_64]=4000
)
for abi in "${expected_abis[@]}"; do
  [[ -n "${apk_for_abi[$abi]:-}" ]] || { echo "Missing release APK for $abi." >&2; exit 1; }
done
if ((${#apk_for_abi[@]} != ${#expected_abis[@]})); then
  echo "Expected exactly ${#expected_abis[@]} release APKs." >&2
  exit 1
fi

common_digest=
for abi in "${expected_abis[@]}"; do
  apk=${apk_for_abi[$abi]}
  signer_output=$(apksigner verify --print-certs "$apk")
  signer_count=$(grep -c '^Signer #[0-9][0-9]* certificate SHA-256 digest:' <<< "$signer_output")
  [[ "$signer_count" == 1 ]] || { echo "Expected exactly one signer for $apk, found $signer_count." >&2; exit 1; }
  signer_dn=$(sed -n 's/^Signer #1 certificate DN:[[:space:]]*//p' <<< "$signer_output" | head -n 1)
  signer_digest=$(sed -n 's/^Signer #1 certificate SHA-256 digest:[[:space:]]*//p' <<< "$signer_output" \
    | head -n 1 \
    | tr -d '[:space:]:' \
    | tr '[:lower:]' '[:upper:]')

  [[ -n "$signer_dn" ]] || { echo "Missing signer certificate for $apk." >&2; exit 1; }
  [[ "$signer_dn" != *'Android Debug'* ]] || { echo "Debug-signed APK rejected: $apk" >&2; exit 1; }
  [[ "$signer_digest" =~ ^[0-9A-F]{64}$ ]] || { echo "Missing signer SHA-256 digest for $apk." >&2; exit 1; }
  [[ "$signer_digest" == "$expected_digest" ]] || { echo "Signer digest does not match the permanent keystore for $apk." >&2; exit 1; }

  if [[ -n "$common_digest" && "$signer_digest" != "$common_digest" ]]; then
    echo 'Release APKs do not share one signing certificate.' >&2
    exit 1
  fi
  common_digest=$signer_digest

  application_id=$(apkanalyzer manifest application-id "$apk" | tr -d '\r')
  version_name=$(apkanalyzer manifest version-name "$apk" | tr -d '\r')
  version_code=$(apkanalyzer manifest version-code "$apk" | tr -d '\r')
  expected_abi_version_code=$((10#$expected_version_code + version_code_offset[$abi]))
  [[ "$application_id" == "$expected_application_id" ]] || { echo "Unexpected application ID in $apk: $application_id" >&2; exit 1; }
  [[ "$version_name" == "$expected_version_name" ]] || { echo "Unexpected version name in $apk: $version_name" >&2; exit 1; }
  [[ "$version_code" == "$expected_abi_version_code" ]] || { echo "Unexpected version code in $apk: $version_code" >&2; exit 1; }

  echo "$(basename "$apk"): $application_id $version_name+$version_code $signer_digest"
done

echo "Verified ${#expected_abis[@]} release APKs with one permanent certificate."
