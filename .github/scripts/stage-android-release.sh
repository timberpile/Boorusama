#!/usr/bin/env bash
set -euo pipefail

if (($# != 2)); then
  echo "Usage: $0 <build-directory> <staging-directory>" >&2
  exit 2
fi

build_directory=$(realpath -m "$1")
staging_directory=$(realpath -m "$2")
receipt="$build_directory/release/github/apk.json"

[[ -f "$receipt" ]] || { echo "GitHub APK receipt is missing: $receipt" >&2; exit 1; }
if [[ -d "$staging_directory" ]] && find "$staging_directory" -mindepth 1 -print -quit | grep -q .; then
  echo "Release staging directory is not empty: $staging_directory" >&2
  exit 1
fi

mapfile -t artifact_paths < <(jq -r '.artifacts[].relativePath' "$receipt")
[[ "${#artifact_paths[@]}" == 3 ]] || { echo 'Expected exactly three receipt artifacts.' >&2; exit 1; }

mkdir -p "$staging_directory/release/github"
for relative_path in "${artifact_paths[@]}"; do
  if [[ -z "$relative_path" || "$relative_path" == /* || "$relative_path" == *'/'* || "$relative_path" == *'..'* ]]; then
    echo "Unsafe receipt artifact path: $relative_path" >&2
    exit 1
  fi
  [[ -f "$build_directory/$relative_path" ]] || { echo "Receipt artifact is missing: $relative_path" >&2; exit 1; }
  cp -- "$build_directory/$relative_path" "$staging_directory/$relative_path"
done
cp -- "$receipt" "$staging_directory/release/github/apk.json"

echo "Staged ${#artifact_paths[@]} canonical Android release APKs."
