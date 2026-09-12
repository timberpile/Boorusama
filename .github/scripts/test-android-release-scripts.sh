#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
setup_script="$script_dir/setup-android-signing.sh"
verify_script="$script_dir/verify-android-apks.sh"
upgrade_script="$script_dir/verify-android-upgrade.sh"
stage_script="$script_dir/stage-android-release.sh"
gradle_file="$script_dir/../../android/app/build.gradle.kts"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/keytool" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${KEYTOOL_FAIL:-false}" == false ]] || exit 1
if [[ " $* " == *" -v "* ]]; then
  echo 'Certificate fingerprints:'
  echo '         SHA256: AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA:AA'
fi
EOF

cat > "$fake_bin/apksigner" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
apk=${!#}
[[ "${APKSIGNER_MODE:-release}" != unsigned ]] || exit 1
case "${APKSIGNER_MODE:-release}:$(basename "$apk")" in
  multiple:*)
    echo 'Signer #1 certificate DN: CN=Release'
    echo 'Signer #1 certificate SHA-256 digest: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    echo 'Signer #2 certificate DN: CN=Other Release'
    echo 'Signer #2 certificate SHA-256 digest: CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC'
    ;;
  debug:*)
    echo 'Signer #1 certificate DN: CN=Android Debug,O=Android,C=US'
    echo 'Signer #1 certificate SHA-256 digest: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    ;;
  mismatch:*-android-x64.apk)
    echo 'Signer #1 certificate DN: CN=Release'
    echo 'Signer #1 certificate SHA-256 digest: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'
    ;;
  *)
    echo 'Signer #1 certificate DN: CN=Release'
    echo 'Signer #1 certificate SHA-256 digest: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    ;;
esac
EOF

cat > "$fake_bin/apkanalyzer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
field=$2
case "$field" in
  application-id) [[ "${METADATA_MODE:-valid}" == wrong-app ]] && echo wrong.app || echo com.timberpile.boorusama ;;
  version-name) echo 4.5.0-timberpile.1 ;;
  version-code)
    if [[ "${METADATA_MODE:-valid}" == wrong-version ]]; then
      echo 999
    elif [[ "$(basename "${!#}")" == lower.apk ]]; then
      echo 4184
    else
      case "$(basename "${!#}")" in
        *-android-armv7.apk) echo 1185 ;;
        *-android-arm64.apk) echo 2185 ;;
        *-android-x64.apk) echo 4185 ;;
        *) exit 2 ;;
      esac
    fi
    ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case " $* " in
  *" install -r "*) [[ "${ADB_REPLACE_FAIL:-false}" == false ]] ;;
  *" install "*) exit 0 ;;
  *" pm list packages "*) echo 'package:com.timberpile.boorusama' ;;
  *" dumpsys package "*)
    echo 'versionCode=4185 minSdk=24 targetSdk=36'
    echo "versionName=${ADB_VERSION_NAME:-4.5.0-timberpile.1}"
    ;;
  *) exit 2 ;;
esac
EOF

cat > "$fake_bin/jq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sed -n 's/.*"relativePath":"\([^"]*\)".*/\1/p' "${!#}"
EOF
chmod +x "$fake_bin"/*

failures=0

if grep -Fq 'signingConfigs.getByName("debug")' "$gradle_file" ||
  ! grep -Fq 'gradle.taskGraph.whenReady' "$gradle_file"; then
  echo 'not ok - Gradle release signing fails closed'
  failures=$((failures + 1))
else
  echo 'ok - Gradle release signing fails closed'
fi

run_success() {
  local description=$1
  shift
  if ! "$@" >"$test_root/output" 2>&1; then
    echo "not ok - $description"
    cat "$test_root/output"
    failures=$((failures + 1))
    return
  fi
  echo "ok - $description"
}

run_failure() {
  local description=$1
  shift
  if "$@" >"$test_root/output" 2>&1; then
    echo "not ok - $description"
    failures=$((failures + 1))
    return
  fi
  echo "ok - $description"
}

export PATH="$fake_bin:$PATH"
export ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_BASE64=$(printf 'fake keystore' | base64 -w0)
export ANDROID_KEYSTORE_PASSWORD=store-password
export ANDROID_KEY_ALIAS=release
export ANDROID_KEY_PASSWORD=key-password
export GITHUB_OUTPUT="$test_root/github-output"

run_success 'valid signing configuration writes absolute Gradle properties' \
  "$setup_script" "$test_root/release.jks" "$test_root/key.properties"
if [[ -f "$test_root/key.properties" ]] &&
  grep -Fqx "storeFile=$test_root/release.jks" "$test_root/key.properties" &&
  grep -Fqx 'certificate_sha256=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "$GITHUB_OUTPUT" &&
  [[ "$(stat -c '%a' "$test_root/release.jks")" == 600 ]] &&
  [[ "$(stat -c '%a' "$test_root/key.properties")" == 600 ]]; then
  echo 'ok - signing setup records the permanent certificate digest'
else
  echo 'not ok - signing setup records the permanent certificate digest'
  failures=$((failures + 1))
fi

run_failure 'missing signing configuration is rejected' \
  env -u ANDROID_KEYSTORE_BASE64 "$setup_script" \
  "$test_root/missing.jks" "$test_root/missing.properties"
run_failure 'an invalid keystore alias is rejected' \
  env KEYTOOL_FAIL=1 "$setup_script" \
  "$test_root/invalid.jks" "$test_root/invalid.properties"

build_dir="$test_root/build-output"
staged_dir="$test_root/staged-output"
mkdir -p "$build_dir/release/github"
touch "$build_dir/raw-arm64.apk"
for name in \
  boorusama-4.5.0-timberpile.1+185-android-arm64.apk \
  boorusama-4.5.0-timberpile.1+185-android-armv7.apk \
  boorusama-4.5.0-timberpile.1+185-android-x64.apk; do
  touch "$build_dir/$name"
done
cat > "$build_dir/release/github/apk.json" <<'EOF'
{"artifacts":[
  {"relativePath":"boorusama-4.5.0-timberpile.1+185-android-arm64.apk"},
  {"relativePath":"boorusama-4.5.0-timberpile.1+185-android-armv7.apk"},
  {"relativePath":"boorusama-4.5.0-timberpile.1+185-android-x64.apk"}
]}
EOF
run_success 'only receipt-declared APKs are staged for release' \
  "$stage_script" "$build_dir" "$staged_dir"
if [[ "$(find "$staged_dir" -type f -name '*.apk' | wc -l)" == 3 ]] &&
  [[ ! -e "$staged_dir/raw-arm64.apk" ]] &&
  [[ -f "$staged_dir/release/github/apk.json" ]]; then
  echo 'ok - staged release excludes raw build APKs'
else
  echo 'not ok - staged release excludes raw build APKs'
  failures=$((failures + 1))
fi

apk_dir="$test_root/apks"
mkdir -p "$apk_dir"
touch "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-arm64.apk"
touch "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-armv7.apk"
touch "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-x64.apk"
expected_digest=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

verify_args=(
  "$apk_dir"
  "$expected_digest"
  com.timberpile.boorusama
  4.5.0-timberpile.1
  185
)
run_success 'three release APKs with matching signers and metadata are accepted' \
  "$verify_script" "${verify_args[@]}"
run_failure 'unsigned APKs are rejected' \
  env APKSIGNER_MODE=unsigned "$verify_script" "${verify_args[@]}"
run_failure 'debug-signed APKs are rejected' \
  env APKSIGNER_MODE=debug "$verify_script" "${verify_args[@]}"
run_failure 'APKs with an additional signer are rejected' \
  env APKSIGNER_MODE=multiple "$verify_script" "${verify_args[@]}"
run_failure 'different APK certificate digests are rejected' \
  env APKSIGNER_MODE=mismatch "$verify_script" "${verify_args[@]}"
run_failure 'a digest different from the permanent key is rejected' \
  "$verify_script" "$apk_dir" \
  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB \
  com.timberpile.boorusama 4.5.0-timberpile.1 185
run_failure 'incorrect package metadata is rejected' \
  env METADATA_MODE=wrong-app "$verify_script" "${verify_args[@]}"
run_failure 'incorrect version metadata is rejected' \
  env METADATA_MODE=wrong-version "$verify_script" "${verify_args[@]}"

rm "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-armv7.apk"
run_failure 'a missing release ABI is rejected' \
  "$verify_script" "${verify_args[@]}"
touch "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-armv7.apk"

touch "$apk_dir/universal.apk"
run_failure 'an additional noncanonical APK is rejected' \
  "$verify_script" "${verify_args[@]}"
rm "$apk_dir/universal.apk"

touch "$test_root/lower.apk"
run_success 'a same-package higher-version replacement is accepted' \
  "$upgrade_script" "$test_root/lower.apk" \
  "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-x64.apk" \
  com.timberpile.boorusama 4.5.0-timberpile.1 185
run_failure 'a failed in-place replacement is rejected' \
  env ADB_REPLACE_FAIL=true "$upgrade_script" "$test_root/lower.apk" \
  "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-x64.apk" \
  com.timberpile.boorusama 4.5.0-timberpile.1 185
run_failure 'an installed version name mismatch is rejected' \
  env ADB_VERSION_NAME=wrong "$upgrade_script" "$test_root/lower.apk" \
  "$apk_dir/boorusama-4.5.0-timberpile.1+185-android-x64.apk" \
  com.timberpile.boorusama 4.5.0-timberpile.1 185

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo 'All Android release script tests passed.'
