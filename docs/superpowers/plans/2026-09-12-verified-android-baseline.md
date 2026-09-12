# Verified Android Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and prove a Flutter 3.47.2 Timberpile baseline that publishes three persistently signed Android split APKs through a real non-draft GitHub prerelease.

**Architecture:** Keep `develop_new_2` rooted on canonical upstream and make three implementation commits: toolchain/dependencies, CLI packaging, and Android release CI. The CLI derives packaged ABIs from Flutter arguments; GitHub Actions owns protected-key setup, pre-publish artifact/signature checks, publication, post-publish asset checks, and the opt-in emulator update test.

**Tech Stack:** Flutter 3.47.2, Dart workspace/pub, FVM, Gradle/Android SDK 36, `boorusama_cli`, GitHub Actions, `keytool`, `apksigner`, `apkanalyzer`, `adb`, Meson, NASM, Cargo caches.

**Spec:** `docs/superpowers/specs/2026-09-12-verified-android-baseline-design.md`

## Global Constraints

- Work only on `develop_new_2`, starting from the latest `upstream/master` already incorporated beneath the design commits.
- Use JakeDev commits only to compare intended behavior; do not cherry-pick them.
- Pin Flutter to exactly `3.47.2` in local and CI configuration.
- Preserve current upstream `flutter_libavif`/`libavif` and native-assets choices when resolving dependencies.
- Release ABIs are exactly `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
- GitHub release output is Android/APK only.
- Use only `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` for release signing.
- Routine defaults are `draft=true` and `verify_upgrade=false`; the baseline gate uses `prerelease=true`, `draft=false`, and `verify_upgrade=true`.
- Keep the successful verification prerelease and tag.
- Do not add Plus, Pixiv, Pawchive, Timberpile product features, Jake version bumps, or wholesale Jake documentation.

---

### Task 1: Pin and resolve the Flutter 3.47.2 toolchain

**Files:**
- Modify: `.fvmrc`
- Modify if required by Flutter 3.47.2 diagnostics: `analysis_options.yaml`
- Modify if required by Flutter 3.47.2 diagnostics: `packages/*/analysis_options.yaml`
- Regenerate: `pubspec.lock`
- Regenerate: `packages/boorusama_cli/pubspec.lock`

**Interfaces:**
- Consumes: current upstream manifests and native-asset pins.
- Produces: an exact FVM version declaration and lockfiles resolved by Flutter/Dart 3.47.2.

- [ ] **Step 1: Prove the repository is still based on the fetched canonical tip**

Run:

```bash
git merge-base --is-ancestor upstream/master HEAD
git log --oneline upstream/master..HEAD
git status --short --branch
```

Expected: the ancestor check exits 0; only the approved design commits are above `upstream/master`; the worktree is clean.

- [ ] **Step 2: Pin FVM to Flutter 3.47.2**

Change `.fvmrc` to:

```json
{
  "flutter": "3.47.2"
}
```

- [ ] **Step 3: Install and verify the exact SDK**

Run:

```bash
fvm install 3.47.2
fvm flutter --version
fvm dart --version
```

Expected: Flutter reports `3.47.2`; record the bundled Dart version in the execution notes.

- [ ] **Step 4: Regenerate current dependency resolution**

Run:

```bash
fvm flutter pub get
(cd packages/boorusama_cli && fvm dart pub get)
```

Expected: both commands succeed under the pinned SDK. Do not copy either JakeDev lockfile.

- [ ] **Step 5: Diagnose analyzer changes rather than copying exclusions**

Run:

```bash
fvm flutter analyze
```

Expected: either success or concrete generated/platform-directory diagnostics. Add only narrowly required `analyzer.exclude` entries, then rerun until there are no errors. Do not add exclusions for real source diagnostics.

- [ ] **Step 6: Confirm upstream native-asset choices survived resolution**

Run:

```bash
git diff upstream/master -- pubspec.yaml pubspec.lock packages/boorusama_cli/pubspec.lock
rg -n 'flutter_libavif|libavif|native_assets' pubspec.yaml pubspec.lock
```

Expected: manifest-level upstream choices remain; lockfile changes come from resolution under 3.47.2.

- [ ] **Step 7: Run the bootstrap and generation smoke gate**

Run:

```bash
./init.sh
./gen.sh
git status --short
```

Expected: both commands succeed and repeat generation does not create unexplained source changes.

- [ ] **Step 8: Commit the toolchain migration**

Run:

```bash
git add .fvmrc pubspec.lock packages/boorusama_cli/pubspec.lock analysis_options.yaml packages/*/analysis_options.yaml
git diff --cached --check
git commit -m "chore: migrate to Flutter 3.47.2"
```

Expected: commit contains only the pin, regenerated resolutions, and analyzer changes proven necessary by Step 5.

### Task 2: Make split-APK packaging follow Flutter arguments

**Files:**
- Modify: `packages/boorusama_cli/lib/src/package/android.dart`
- Create: `packages/boorusama_cli/test/package/android_test.dart`
- Verify: `packages/boorusama_cli/lib/src/command/release/github/build.dart`

**Interfaces:**
- Produces: `List<String> splitAbisFor(List<String> flutterArgs)`.
- Consumes later: `AndroidPackager._packageSplitApks` uses `splitAbisFor(plan.flutterArgs)`.

- [ ] **Step 1: Write failing ABI-selection tests**

Create `packages/boorusama_cli/test/package/android_test.dart` with parameterized cases asserting:

```dart
expect(splitAbisFor(['--split-per-abi']), [
  'arm64-v8a',
  'armeabi-v7a',
  'x86_64',
]);
expect(
  splitAbisFor(['--target-platform', 'android-arm64,android-arm']),
  ['arm64-v8a', 'armeabi-v7a'],
);
expect(
  splitAbisFor(['--target-platform=android-x64']),
  ['x86_64'],
);
expect(
  splitAbisFor([
    '--target-platform',
    'android-x64',
    '--target-platform=android-arm64',
  ]),
  ['arm64-v8a', 'x86_64'],
);
expect(splitAbisFor(['--target-platform', 'android-riscv64']), [
  'arm64-v8a',
  'armeabi-v7a',
  'x86_64',
]);
```

Also cover whitespace, an empty value, and a flag missing its value. Use one `test()` per parameterized case as required by `CLAUDE.md`.

- [ ] **Step 2: Run the focused test and observe failure**

Run:

```bash
(cd packages/boorusama_cli && fvm dart test test/package/android_test.dart)
```

Expected: compilation fails because `splitAbisFor` is undefined.

- [ ] **Step 3: Implement canonical ABI selection**

Add to `android.dart`:

```dart
List<String> splitAbisFor(List<String> flutterArgs) {
  const abiForPlatform = {
    'android-arm64': 'arm64-v8a',
    'android-arm': 'armeabi-v7a',
    'android-x64': 'x86_64',
  };
  const allAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
  final platforms = _targetPlatforms(flutterArgs);
  if (platforms.isEmpty) return allAbis;

  final selected = platforms
      .map((platform) => abiForPlatform[platform])
      .whereType<String>()
      .toSet();
  if (selected.isEmpty) return allAbis;
  return allAbis.where(selected.contains).toList();
}

List<String> _targetPlatforms(List<String> flutterArgs) {
  const flag = '--target-platform';
  final values = <String>[];
  for (var index = 0; index < flutterArgs.length; index++) {
    final argument = flutterArgs[index];
    if (argument == flag && index + 1 < flutterArgs.length) {
      values.addAll(flutterArgs[index + 1].split(','));
    } else if (argument.startsWith('$flag=')) {
      values.addAll(argument.substring(flag.length + 1).split(','));
    }
  }
  return values.map((value) => value.trim()).where((value) => value.isNotEmpty).toList();
}
```

Replace the fixed ABI constant in `_packageSplitApks` with:

```dart
final abis = splitAbisFor(plan.flutterArgs);
```

- [ ] **Step 4: Format and run focused/full CLI tests**

Run:

```bash
fvm dart format packages/boorusama_cli/lib/src/package/android.dart packages/boorusama_cli/test/package/android_test.dart
(cd packages/boorusama_cli && fvm dart test test/package/android_test.dart)
(cd packages/boorusama_cli && fvm dart test)
(cd packages/boorusama_cli && fvm dart analyze)
```

Expected: all commands pass.

- [ ] **Step 5: Confirm the GitHub build remains all-ABI**

Inspect `_extraFlutterArgsFor` in `build.dart` and retain exactly:

```dart
GithubReleaseTarget.apk => const ['--split-per-abi'],
```

Do not add `--target-platform`; default split behavior must produce all three ABIs.

- [ ] **Step 6: Commit CLI packaging**

Run:

```bash
git add packages/boorusama_cli/lib/src/package/android.dart packages/boorusama_cli/test/package/android_test.dart
git diff --cached --check
git commit -m "fix(release): package built Android split APKs"
```

### Task 3: Add testable Android signing and artifact verification helpers

**Files:**
- Create: `.github/scripts/setup-android-signing.sh`
- Create: `.github/scripts/verify-android-apks.sh`
- Create: `.github/scripts/verify-android-upgrade.sh`
- Create: `.github/scripts/test-android-release-scripts.sh`

**Interfaces:**
- `setup-android-signing.sh <keystore-path> <properties-path>` consumes the four signing environment variables, validates the alias, writes absolute Gradle properties, and emits normalized `certificate_sha256=<hex>` to `$GITHUB_OUTPUT` when set.
- `verify-android-apks.sh <apk-directory> <expected-certificate-sha256> <application-id> <version-name> <base-version-code>` requires exactly the three release ABI assets and validates signer plus metadata. It derives Flutter's split-APK manifest version codes by adding `1000` for `armeabi-v7a`, `2000` for `arm64-v8a`, and `4000` for `x86_64` to the tagged base version code.
- `verify-android-upgrade.sh <lower-apk> <published-apk> <application-id> <final-version-name> <final-base-version-code>` performs `adb install`, `adb install -r`, and final package-manager validation.

- [ ] **Step 1: Write the failing shell contract tests**

Create a test script that builds a temporary fake tool directory and asserts the helpers:

```bash
run_expect_failure env -u ANDROID_KEYSTORE_BASE64 \
  "$setup_script" "$tmp/release.jks" "$tmp/key.properties"
run_expect_failure env KEYTOOL_FAIL=1 PATH="$fake_path" \
  "$setup_script" "$tmp/release.jks" "$tmp/key.properties"
run_expect_failure env APKSIGNER_MODE=debug PATH="$fake_path" \
  "$verify_script" "$tmp/apks" "$expected_digest" \
  com.degenk.boorusama 4.5.0 185
run_expect_failure env APKSIGNER_MODE=mismatch PATH="$fake_path" \
  "$verify_script" "$tmp/apks" "$expected_digest" \
  com.degenk.boorusama 4.5.0 185
run_expect_success env PATH="$fake_path" \
  "$verify_script" "$tmp/apks" "$expected_digest" \
  com.degenk.boorusama 4.5.0 185
```

Fake `keytool`, `apksigner`, `apkanalyzer`, and `adb` executables must return deterministic output matching the real tools. Cover missing secrets, invalid alias, missing ABI, unsigned/debug APK, cross-APK digest disagreement, permanent-key mismatch, metadata mismatch, failed replace install, and the success path. The test creates only files below `mktemp -d` and removes them with a trap.

- [ ] **Step 2: Run the contract tests and observe missing-helper failures**

Run:

```bash
bash .github/scripts/test-android-release-scripts.sh
```

Expected: failure because the three helper scripts do not exist.

- [ ] **Step 3: Implement protected-key setup**

`setup-android-signing.sh` must:

```bash
set -euo pipefail
required=(ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD)
missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
(( ${#missing[@]} == 0 )) || { echo "Missing release signing secret(s): ${missing[*]}" >&2; exit 1; }

keystore_path=$(realpath -m "$1")
properties_path=$(realpath -m "$2")
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$keystore_path"
keytool -list -keystore "$keystore_path" -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias "$ANDROID_KEY_ALIAS" >/dev/null
```

Write `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` to the properties file, then derive the expected digest from `keytool -list -v`'s `SHA256:` line, normalize it to uppercase hexadecimal without colons, require 64 characters, and append it to `$GITHUB_OUTPUT` if that path is set. Never echo passwords or Base64.

- [ ] **Step 4: Implement exact-ABI APK verification**

`verify-android-apks.sh` must map release filenames ending in
`-android-arm64.apk`, `-android-armv7.apk`, and `-android-x64.apk` to the three
expected ABIs; reject duplicates, missing files, or additional APKs. For each
file run:

```bash
apksigner verify --print-certs "$apk"
apkanalyzer manifest application-id "$apk"
apkanalyzer manifest version-name "$apk"
apkanalyzer manifest version-code "$apk"
```

Extract `Signer #1 certificate SHA-256 digest:`, normalize it, require one
non-debug signer, compare it to the other APKs and the normalized expected
keystore digest, and compare metadata to the supplied expected values.

- [ ] **Step 5: Implement the emulator update assertion**

`verify-android-upgrade.sh` must run:

```bash
adb install "$lower_apk"
adb shell pm list packages | grep -Fx "package:$application_id"
adb install -r "$published_apk"
adb shell dumpsys package "$application_id"
```

Parse `versionCode=` from `dumpsys`, require it to equal the supplied final
versionCode, and fail if the published versionCode is not higher than the lower
APK metadata read by `apkanalyzer`.

- [ ] **Step 6: Run helper tests and syntax checks**

Run:

```bash
bash -n .github/scripts/*.sh
bash .github/scripts/test-android-release-scripts.sh
```

Expected: both pass.

### Task 4: Replace the release workflow with Android-only verified publication

**Files:**
- Modify: `.github/workflows/github-release.yml`
- Modify: `android/gradle.properties`
- Consume: `.github/scripts/setup-android-signing.sh`
- Consume: `.github/scripts/verify-android-apks.sh`
- Consume: `.github/scripts/verify-android-upgrade.sh`

**Interfaces:**
- Workflow inputs: `release_tag: string`, `prerelease: boolean=false`, `draft: boolean=true`, `verify_upgrade: boolean=false`, `recreate_release: boolean=false`.
- Build output: Actions artifact `boorusama-apk` containing three APKs plus the APK receipt.
- Publish behavior: passes `--target apk`; passes `--no-draft` exactly when `inputs.draft == false`.

- [ ] **Step 1: Enable Gradle build caching**

Append to `android/gradle.properties`:

```properties
org.gradle.caching=true
```

- [ ] **Step 2: Reduce the build matrix to Android and pin Flutter**

Use one build job guarded by:

```yaml
if: github.actor == github.repository_owner
runs-on: ubuntu-latest
env:
  BOORUSAMA_USE_FVM: "false"
  OUTPUT_DIR: release-artifacts/apk
```

Configure `subosito/flutter-action@v2` with `flutter-version: 3.47.2` and
`cache: true`. Install Android platform 36, build-tools 36.0.0, NDK
28.2.13676358, `meson`, and `nasm`. Remove all desktop/Apple matrix and setup
steps.

- [ ] **Step 3: Add correctly keyed Gradle and Cargo caches**

Add `actions/cache@v4` entries for:

```yaml
path: |
  ~/.gradle/caches
  ~/.gradle/wrapper
key: gradle-${{ runner.os }}-${{ hashFiles('android/**/*.gradle*', 'android/gradle.properties', 'android/gradle/wrapper/gradle-wrapper.properties') }}
```

and:

```yaml
path: |
  ~/.cargo/registry
  ~/.cargo/git
key: cargo-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
```

Include OS-scoped restore prefixes.

- [ ] **Step 4: Set up and validate persistent signing before building**

Expose the four secrets only to the setup step and run:

```bash
.github/scripts/setup-android-signing.sh \
  "$PWD/android/release.jks" \
  "$PWD/android/key.properties"
```

Give the step `id: signing`; its `certificate_sha256` output becomes the
expected fingerprint for pre-publish verification.

- [ ] **Step 5: Build and verify all three APKs before upload**

Run the existing CLI Android release build:

```bash
./build.sh release github build apk --ci --allow-dirty --output-dir "$OUTPUT_DIR"
```

Read version name/code from the tagged `pubspec.yaml`, then run
`verify-android-apks.sh` with the setup step's fingerprint and
`com.degenk.boorusama`. Upload only `$OUTPUT_DIR/**` as `boorusama-apk`.

- [ ] **Step 6: Publish only the APK receipt with explicit draft behavior**

Keep the owner guard, download `boorusama-apk`, and build arguments containing:

```bash
args+=(--target apk)
[[ "${{ inputs.draft }}" == "true" ]] || args+=(--no-draft)
[[ "${{ inputs.prerelease }}" == "true" ]] && args+=(--prerelease)
```

The publish job must continue to use the requested tag and retain existing
`recreate_release` behavior. Name the step according to the selected draft
state rather than claiming every release is a draft.

- [ ] **Step 7: Verify actual published assets**

Add a `verify_published` job guarded by repository owner and dependent on
`publish`. Decode/validate the permanent key, then run:

```bash
gh release download "${{ inputs.release_tag }}" \
  --repo "${{ github.repository }}" \
  --pattern '*.apk' \
  --dir published-apks
.github/scripts/verify-android-apks.sh published-apks \
  "${{ steps.signing.outputs.certificate_sha256 }}" \
  com.degenk.boorusama "$expected_version_name" "$expected_version_code"
```

This job must fail if `inputs.draft` is true because draft assets are not a
published-prerelease gate; routine draft creation can skip the post-publish job
with an explicit job condition.

- [ ] **Step 8: Add the opt-in same-key in-place update check**

When `inputs.verify_upgrade` is true, require `inputs.draft` to be false and
the source versionCode to exceed 1. Before starting the emulator, build an
`x86_64` verification APK at `versionCode - 1` from the tagged source with the
same key and production application ID. Use
`reactivecircus/android-emulator-runner@v2` to invoke:

```bash
.github/scripts/verify-android-upgrade.sh \
  verification-lower.apk \
  published-apks/*-android-x64.apk \
  com.degenk.boorusama \
  "$expected_version_code"
```

The lower APK remains in runner-local temporary storage and is never passed to
`actions/upload-artifact` or `gh release create`.

- [ ] **Step 9: Validate workflow structure and helper contracts**

Run:

```bash
bash .github/scripts/test-android-release-scripts.sh
actionlint .github/workflows/github-release.yml
git diff --check
rg -n "khoadng|linux-tar|appimage|windows-zip|ipa|dmg" .github/workflows/github-release.yml
```

Expected: tests/actionlint/diff checks pass and the final search has no matches.

- [ ] **Step 10: Commit CI, caching, and signing verification**

Run:

```bash
git add .github/workflows/github-release.yml .github/scripts android/gradle.properties
git diff --cached --check
git commit -m "ci(release): verify persistently signed Android releases"
```

### Task 5: Run the complete local baseline gate

**Files:**
- Verify only; generated changes must be reviewed before inclusion.

**Interfaces:**
- Consumes: all three implementation commits.
- Produces: local evidence that bootstrap, codegen, analysis, tests, packaging, ABI output, metadata, and locally signed upgrade behavior work.

- [ ] **Step 1: Recreate clean generated/dependency state**

Run from a clean worktree:

```bash
git status --short
./init.sh
./gen.sh
git status --short
```

Expected: no unexplained tracked differences.

- [ ] **Step 2: Run root static analysis and tests**

Run:

```bash
fvm flutter analyze
fvm flutter test
```

Expected: both pass without new errors.

- [ ] **Step 3: Run every affected package suite**

Run the CLI suite:

```bash
(cd packages/boorusama_cli && fvm dart analyze && fvm dart test)
```

Run every workspace package suite that exists, because the SDK and root
resolution affect the entire workspace:

```bash
for package in packages/*; do
  [[ -d "$package/test" ]] || continue
  (cd "$package" && fvm flutter test)
done
```

- [ ] **Step 4: Build locally signed production split APKs**

Create an isolated temporary JKS with `keytool`, Base64-encode it into temporary
environment variables, run `setup-android-signing.sh`, then run:

```bash
./build.sh release github build apk --allow-dirty --output-dir /tmp/boorusama-baseline-apks
```

Expected: packaging produces arm64, armv7, and x64 APKs plus an APK receipt.

- [ ] **Step 5: Validate local artifacts and update compatibility**

Run `verify-android-apks.sh` against the temporary keystore fingerprint and
source metadata. Start an available emulator, install an x86_64 build with a
lower versionCode, and pass the final x86_64 APK to
`verify-android-upgrade.sh`.

Expected: exactly three APKs validate and `adb install -r` succeeds. This local
test validates mechanics; the GitHub gate repeats it with the permanent key.

- [ ] **Step 6: Confirm scope and history**

Run:

```bash
git status --short --branch
git log --oneline upstream/master..HEAD
git diff --stat upstream/master...HEAD
```

Expected: clean branch; two design commits plus the three requested
implementation commits; no excluded feature files.

### Task 6: Publish and inspect the real baseline prerelease

**Files:**
- Remote verification only; do not modify product version.

**Interfaces:**
- Consumes: pushed `develop_new_2`, configured Android signing secrets, and the completed local gate.
- Produces: retained non-draft prerelease/tag and a successful workflow containing post-publish signer/metadata/update evidence.

- [ ] **Step 1: Verify GitHub authentication and secret names**

Run:

```bash
gh auth status
gh secret list --repo timberpile/Boorusama
```

Expected: authentication succeeds and all four required secret names exist.

- [ ] **Step 2: Push the development branch**

Run:

```bash
git push --set-upstream origin develop_new_2
```

Expected: remote branch points at the locally verified HEAD.

- [ ] **Step 3: Create and push a dedicated immutable verification tag**

Choose a unique tag such as `baseline-android-3.47.2-verify.1`, create it at
HEAD, and run:

```bash
git tag --annotate baseline-android-3.47.2-verify.1 \
  --message "Verify Flutter 3.47.2 Android baseline"
git push origin baseline-android-3.47.2-verify.1
```

If that tag already exists, increment the numeric suffix; never move or delete
an existing successful verification tag.

- [ ] **Step 4: Dispatch a non-draft prerelease with upgrade verification**

Run:

```bash
gh workflow run github-release.yml \
  --repo timberpile/Boorusama \
  --ref develop_new_2 \
  -f release_tag=baseline-android-3.47.2-verify.1 \
  -f prerelease=true \
  -f draft=false \
  -f verify_upgrade=true \
  -f recreate_release=false
```

- [ ] **Step 5: Watch the exact workflow run to completion**

Resolve the run ID created by Step 4, then run:

```bash
gh run watch "$run_id" --repo timberpile/Boorusama --exit-status
gh run view "$run_id" --repo timberpile/Boorusama --log-failed
```

Expected: build, publish, and post-publish verification jobs all succeed.

- [ ] **Step 6: Independently inspect the retained published prerelease**

Run:

```bash
gh release view baseline-android-3.47.2-verify.1 \
  --repo timberpile/Boorusama \
  --json isDraft,isPrerelease,tagName,url,assets
gh release download baseline-android-3.47.2-verify.1 \
  --repo timberpile/Boorusama \
  --pattern '*.apk' \
  --dir /tmp/boorusama-published-baseline
```

Expected: `isDraft=false`, `isPrerelease=true`, three APK assets, correct
package/version metadata, identical signer digests, and the permanent-key digest
reported by the successful workflow. Do not delete the release or tag.

- [ ] **Step 7: Record final evidence without adding product work**

Report the three implementation commit IDs, local command results, workflow run
URL/ID, prerelease URL, APK filenames/metadata, common certificate SHA-256
digest, and successful `adb install -r` evidence. Stop; do not create Plus or
Pixiv branches.
