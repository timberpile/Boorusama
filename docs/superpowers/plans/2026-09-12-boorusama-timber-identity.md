# Boorusama Timber Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the installed and distributed fork as Boorusama Timber with application ID `com.timberpile.boorusama`, fork-aware release versions, and preserved upstream attribution.

**Architecture:** Change only public platform identity, release/update configuration, and attribution. Keep internal Dart/package/CLI names and compatible protocols unchanged to minimize upstream merge drift. Treat the historical commits as behavioral references and implement each change against the current verified Android baseline.

**Tech Stack:** Flutter 3.47.2, Dart, Android Gradle/Kotlin, Xcode project configuration, CMake/Win32 resources, web manifest HTML, Bash release verification, `pub_semver`.

**Spec:** `docs/superpowers/specs/2026-09-12-boorusama-timber-identity-design.md`

## Global Constraints

- Production display name is `Boorusama Timber`; development display name is `Boorusama Timber Dev`.
- Production application ID is `com.timberpile.boorusama`; development application ID is `com.timberpile.boorusama.dev`.
- Fork version is exactly `4.5.0-timberpile.1+185`; its derived release tag is `v4.5.0-timberpile.1`.
- Release APK names retain `boorusama-<full-version>-android-<abi>.apk`.
- Keep `boorusama://`, `_boorusama._tcp`, internal Dart/package/CLI names, support/legal/store data, and announcement endpoints unchanged.
- Preserve Nguyen Duc Khoa's authorship and add Timberpile modification attribution; do not alter GPL or dependency license texts.
- Do not import unrelated files or documentation from either historical reference commit.

---

### Task 1: Fork-aware version and update behavior

**Files:**
- Create: `packages/boorusama_cli/test/release/version/release_version_test.dart`
- Modify: `packages/boorusama_cli/lib/src/release/version/release_version.dart`
- Modify: `test/app_update/github_release_update_checker_test.dart`
- Modify: `lib/foundation/app_update/src/default_update_checker.dart`
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: `ReleaseVersion.fromPubspec(PubspecInfo)` and `kGitHubUpdateManifestUrl`.
- Produces: accepted full version `4.5.0-timberpile.1+185`, version name `4.5.0-timberpile.1`, build number `185`, tag `v4.5.0-timberpile.1`, and fork update-manifest URL.

- [ ] **Step 1: Add a failing release-version regression test**

Create `release_version_test.dart` with:

```dart
import 'package:boorusama_cli/src/project/pubspec.dart';
import 'package:boorusama_cli/src/release/version/release_version.dart';
import 'package:test/test.dart';

void main() {
  test('accepts Timberpile prerelease version with build metadata', () {
    const pubspec = PubspecInfo(
      name: 'boorusama',
      version: '4.5.0-timberpile.1+185',
      versionName: '4.5.0-timberpile.1',
      buildNumber: '185',
    );

    final version = ReleaseVersion.fromPubspec(pubspec);

    expect(version.full, '4.5.0-timberpile.1+185');
    expect(version.name, '4.5.0-timberpile.1');
    expect(version.buildNumber, '185');
    expect(version.tag, 'v4.5.0-timberpile.1');
  });
}
```

- [ ] **Step 2: Verify the CLI test fails for the current validator**

Run: `cd packages/boorusama_cli && fvm dart test test/release/version/release_version_test.dart`

Expected: FAIL with `Invalid pubspec version: 4.5.0-timberpile.1+185`.

- [ ] **Step 3: Accept independent prerelease and build components**

Replace the validator expression with:

```dart
final semver = RegExp(
  r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
);
```

- [ ] **Step 4: Verify the release-version regression passes**

Run: `cd packages/boorusama_cli && fvm dart test test/release/version/release_version_test.dart`

Expected: PASS.

- [ ] **Step 5: Add failing fork update-checker tests**

Extend `github_release_update_checker_test.dart` with a test whose current
package version is `4.5.0-timberpile.1`, whose manifest version is
`4.5.0-timberpile.2`, and which expects `UpdateAvailable`. Also assert:

```dart
expect(
  kGitHubUpdateManifestUrl,
  'https://github.com/timberpile/Boorusama/releases/latest/download/boorusama-update.json',
);
```

Update the test fixture package name to `com.timberpile.boorusama` and use
Timberpile release URLs in manifest fixtures.

- [ ] **Step 6: Verify the update URL assertion fails**

Run: `fvm flutter test test/app_update/github_release_update_checker_test.dart`

Expected: FAIL because the default URL still names `khoadng/Boorusama`.

- [ ] **Step 7: Switch the update endpoint and product version**

Set:

```dart
const kGitHubUpdateManifestUrl =
    'https://github.com/timberpile/Boorusama/releases/latest/download/boorusama-update.json';
```

Set the root manifest version to:

```yaml
version: 4.5.0-timberpile.1+185
```

- [ ] **Step 8: Run focused version and update tests**

Run: `cd packages/boorusama_cli && fvm dart test test/release/version/release_version_test.dart`

Run: `fvm flutter test test/app_update/github_release_update_checker_test.dart`

Expected: both PASS.

- [ ] **Step 9: Commit version/update behavior**

```bash
git add pubspec.yaml lib/foundation/app_update/src/default_update_checker.dart test/app_update/github_release_update_checker_test.dart packages/boorusama_cli/lib/src/release/version/release_version.dart packages/boorusama_cli/test/release/version/release_version_test.dart
git commit -m "fix(release): support Timberpile versioning"
```

### Task 2: Android installed identity and release contracts

**Files:**
- Modify: `android/app/build.gradle.kts`
- Move: `android/app/src/main/kotlin/com/degenk/boorusama/MainActivity.kt` to `android/app/src/main/kotlin/com/timberpile/boorusama/MainActivity.kt`
- Move: `android/app/src/main/kotlin/com/degenk/boorusama/MediaScannerChannel.kt` to `android/app/src/main/kotlin/com/timberpile/boorusama/MediaScannerChannel.kt`
- Modify: `lib/foundation/info/package_info.dart`
- Modify: `.github/workflows/github-release.yml`
- Modify: `.github/scripts/test-android-release-scripts.sh`
- Modify: `packages/boorusama_cli/test/release/test_support/prepare_plan.dart`
- Modify: current baseline design/plan references under `docs/superpowers/`

**Interfaces:**
- Consumes: the existing `${applicationId}` manifest authorities, split-APK receipt, signing verifier, and upgrade verifier.
- Produces: Android production ID `com.timberpile.boorusama`, development ID `com.timberpile.boorusama.dev`, and release checks that reject the upstream ID.

- [ ] **Step 1: Update release contract fixtures first**

Change the fake `apkanalyzer` and `adb` responses, verifier invocations, CLI
prepare-plan fixture, and workflow expectations from `com.degenk.boorusama` to
`com.timberpile.boorusama`. Change fixture filenames/version arguments from
`4.5.0+185` to `4.5.0-timberpile.1+185` while retaining expected ABI manifest
codes `1185`, `2185`, and `4185`.

- [ ] **Step 2: Verify the release contract fails against old production configuration**

Run: `.github/scripts/test-android-release-scripts.sh`

Run: `rg -n 'com\.degenk\.boorusama' android .github packages/boorusama_cli/test/release/test_support lib/foundation/info`

Expected: shell unit tests pass as isolated script tests, while the identity
audit still reports old Android/workflow application IDs that require the
implementation change.

- [ ] **Step 3: Change Android Gradle identity and display names**

Set:

```kotlin
namespace = "com.timberpile.boorusama"
applicationId = "com.timberpile.boorusama"
```

Use these flavor resources:

```kotlin
resValue("string", "app_name", "Boorusama Timber Dev")
resValue("string", "app_name", "Boorusama Timber")
```

Keep the `.dev` suffix and existing flavor dimension unchanged.

- [ ] **Step 4: Move both Kotlin channel classes with their namespace**

Move the two source files into `com/timberpile/boorusama/` and set the first
line of each to:

```kotlin
package com.timberpile.boorusama
```

- [ ] **Step 5: Update runtime dummy metadata and release assertions**

Set the dummy package info to:

```dart
appName: 'Boorusama Timber',
packageName: 'com.timberpile.boorusama',
```

Change all three application-ID arguments in `github-release.yml` and all
corresponding shell/CLI fixtures to `com.timberpile.boorusama`. Update the
workflow release title to `Boorusama Timber ${{ inputs.release_tag }}` while
keeping owner guards and signing behavior unchanged.

- [ ] **Step 6: Update normative baseline documentation references**

Replace active verification examples in the baseline spec/plan with the new
application ID and fork version. Preserve their historical design rationale and
do not import historical documentation.

- [ ] **Step 7: Run Android and CLI contract tests**

Run: `.github/scripts/test-android-release-scripts.sh`

Run: `cd packages/boorusama_cli && fvm dart test`

Run: `bash -n .github/scripts/*.sh`

Run: `/tmp/actionlint .github/workflows/github-release.yml`

Expected: all PASS; `rg` finds no active `com.degenk.boorusama` reference in
Android, release scripts/workflow, package-info fixtures, or normative docs.

- [ ] **Step 8: Commit Android identity**

```bash
git add android .github lib/foundation/info/package_info.dart packages/boorusama_cli/test/release/test_support/prepare_plan.dart docs/superpowers
git commit -m "chore(android): identify app as Boorusama Timber"
```

### Task 3: Apple, desktop, web, and attribution identity

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner/RunnerProfile.entitlements`
- Modify: `ios/ShareExtension/ShareExtensionProfile.entitlements`
- Modify: `macos/Runner.xcodeproj/project.pbxproj`
- Modify: `macos/Runner/Configs/AppInfo.xcconfig`
- Modify: `linux/CMakeLists.txt`
- Modify: `linux/my_application.cc`
- Modify: `packages/boorusama_cli/lib/src/package/flatpak.dart`
- Modify: `windows/runner/main.cpp`
- Modify: `windows/runner/Runner.rc`
- Modify: `web/index.html`
- Modify: `web/manifest.json`
- Modify: `README.md`

**Interfaces:**
- Consumes: native platform build configuration and existing upstream attribution.
- Produces: consistent user-visible `Boorusama Timber` identity and Timberpile bundle/application IDs on every configured platform.

- [ ] **Step 1: Capture the expected static identity audit before changes**

Run:

```bash
rg -n 'com\.degenk\.boorusama|PRODUCT_NAME = Boorusama|Boorusama-DEV|"boorusama"|L"boorusama"|com\.degenk' ios macos linux windows web packages/boorusama_cli/lib/src/package/flatpak.dart
```

Expected: matches identify every platform value that must change. Record
protocol/internal matches separately so `boorusama://`, `_boorusama._tcp`,
binary names, and CMake project names are not mechanically replaced.

- [ ] **Step 2: Update iOS bundle IDs, product names, and app groups**

Across all build configurations set runner IDs to
`com.timberpile.boorusama` or `com.timberpile.boorusama.dev`, share-extension
IDs to the same base plus `.ShareExtension`, production product name to
`Boorusama Timber`, and development product name to `Boorusama Timber Dev`.
Remove every `DEVELOPMENT_TEAM = 2YGRTXCBJ5;` assignment without inventing a
replacement team. Change both entitlement files to:

```xml
<string>group.com.timberpile.boorusama</string>
```

- [ ] **Step 3: Update macOS bundle/display metadata and attribution**

Use these AppInfo values:

```text
PRODUCT_NAME = Boorusama Timber
PRODUCT_BUNDLE_IDENTIFIER = com.timberpile.boorusama
PRODUCT_COPYRIGHT = Copyright © 2023 Nguyen Duc Khoa. Modifications © 2026 Timberpile.
```

Update any configuration-specific project overrides to the canonical
production/development IDs and names. Preserve internal target/project object
names unless they control the installed product name.

- [ ] **Step 4: Update Linux and Flatpak identity**

Set Linux `APPLICATION_ID` and `kFlatpakAppId` to
`com.timberpile.boorusama`. Change GTK header/window titles to `Boorusama
Timber`. Keep the Linux `BINARY_NAME` and CMake project name as `boorusama`.

- [ ] **Step 5: Update Windows display metadata and attribution**

Keep `boorusama.exe` and internal CMake names. Change the created window title,
file description, and product name to `Boorusama Timber`; set company name to
`Timberpile`; and set:

```text
Copyright © 2024 Nguyen Duc Khoa. Modifications © 2026 Timberpile.
```

- [ ] **Step 6: Update web display names**

Set the web manifest `name` and `short_name`, HTML `<title>`, and Apple mobile
web-app title to `Boorusama Timber`. Keep asset paths and runtime package names
unchanged.

- [ ] **Step 7: Add concise README attribution**

Add near the overview:

```markdown
**Boorusama Timber** is a private-use fork of Boorusama by Nguyen Duc Khoa. It
retains the original project's authorship and identifies Timberpile's changes
separately.
```

Do not rewrite support, Play Store, privacy, terms, translation, or announcement
references.

- [ ] **Step 8: Run targeted platform identity audits**

Run exact searches proving all configured platform IDs and public product names
use the canonical values. Separately assert that `boorusama://`,
`_boorusama._tcp`, internal binary/CMake names, upstream support/store/legal
references, and third-party licenses remain present and unchanged.

Run: `cd packages/boorusama_cli && fvm dart test`

Expected: tests PASS and the only remaining `com.degenk.boorusama` occurrences
are explicitly excluded support/store or historical material, not installed
platform identity.

- [ ] **Step 9: Commit cross-platform identity and attribution**

```bash
git add ios macos linux windows web packages/boorusama_cli/lib/src/package/flatpak.dart README.md
git commit -m "chore: brand distributions as Boorusama Timber"
```

### Task 4: Regenerate and verify the complete rebrand

**Files:**
- Modify if regenerated: `pubspec.lock`
- Verify: all files changed by Tasks 1–3

**Interfaces:**
- Consumes: canonical identity/version values from Tasks 1–3.
- Produces: a clean, tested branch and locally signed three-ABI Android release proving the new installed identity.

- [ ] **Step 1: Bootstrap and regenerate from the pinned toolchain**

Run: `./init.sh`

Run: `./gen.sh`

Expected: dependency resolution and code generation complete using Flutter
3.47.2. Review any lockfile/generated diff and retain only changes caused by
the version/identity update.

- [ ] **Step 2: Run static analysis and the root suite**

Run: `fvm flutter analyze`

Run: `fvm flutter test --concurrency=1`

Expected: no analyzer issues and all root tests PASS.

- [ ] **Step 3: Run every affected workspace suite**

Run Dart tests from `packages/boorusama_cli`. Run Flutter tests from any other
workspace package whose generated metadata changes. Expected: all PASS.

- [ ] **Step 4: Run release and configuration checks**

Run: `.github/scripts/test-android-release-scripts.sh`

Run: `bash -n .github/scripts/*.sh`

Run: `/tmp/actionlint .github/workflows/github-release.yml`

Run: `git diff --check`

Expected: all PASS.

- [ ] **Step 5: Create an isolated local signing key**

Run these commands without enabling shell tracing:

```bash
SIGNING_TMP=$(mktemp -d /tmp/boorusama-timber-signing.XXXXXX)
keytool -genkeypair -noprompt -keystore "$SIGNING_TMP/release.jks" -storepass local-test-password -keypass local-test-password -alias boorusama-timber-local -keyalg RSA -keysize 2048 -validity 365 -dname "CN=Boorusama Timber Local Verification"
export ANDROID_KEYSTORE_BASE64="$(base64 -w0 "$SIGNING_TMP/release.jks")"
export ANDROID_KEYSTORE_PASSWORD=local-test-password
export ANDROID_KEY_ALIAS=boorusama-timber-local
export ANDROID_KEY_PASSWORD=local-test-password
export GITHUB_OUTPUT="$SIGNING_TMP/signing-output"
.github/scripts/setup-android-signing.sh "$PWD/android/release.jks" "$PWD/android/key.properties"
```

Expected: the setup script validates the alias and writes
`certificate_sha256=<64 hexadecimal characters>` to the temporary output file.
Do not print passwords or commit signing files.

- [ ] **Step 6: Build the production split APK release**

Run:

```bash
RELEASE_OUTPUT=$(mktemp -d /tmp/boorusama-timber-release.XXXXXX)
RELEASE_STAGE=$(mktemp -d /tmp/boorusama-timber-stage.XXXXXX)
./build.sh release github build apk --allow-dirty --output-dir "$RELEASE_OUTPUT"
.github/scripts/stage-android-release.sh "$RELEASE_OUTPUT" "$RELEASE_STAGE"
```

The APK target adds `--split-per-abi` through its existing release plan.
Expected staged receipt assets:

```text
boorusama-4.5.0-timberpile.1+185-android-arm64.apk
boorusama-4.5.0-timberpile.1+185-android-armv7.apk
boorusama-4.5.0-timberpile.1+185-android-x64.apk
```

- [ ] **Step 7: Inspect the locally built APKs**

Run:

```bash
CERTIFICATE_SHA256=$(sed -n 's/^certificate_sha256=//p' "$GITHUB_OUTPUT")
.github/scripts/verify-android-apks.sh "$RELEASE_STAGE" "$CERTIFICATE_SHA256" com.timberpile.boorusama 4.5.0-timberpile.1 185
find "$RELEASE_STAGE" -type f -name '*.apk' -exec apkanalyzer manifest application-label {} \;
```

Expected: exactly three APKs, ABI codes `2185`, `1185`, and `4185`, one shared
non-debug certificate, matching package ID/version, and the new label.

- [ ] **Step 8: Remove local signing material and inspect final state**

Confirm the cleanup targets first:

```bash
realpath android/release.jks android/key.properties
```

Both paths must resolve inside the repository's `android/` directory. Delete
only those two ignored files, then run:

```bash
rm -f android/release.jks android/key.properties
git status --short
git diff --check
git log --oneline upstream/master..HEAD
```

Expected: no uncommitted generated/signing material and only the approved
baseline plus Boorusama Timber identity commits.

- [ ] **Step 9: Commit attributable generated changes, if any**

If bootstrap changed a tracked lockfile solely because the root version changed:

```bash
git add pubspec.lock
git commit -m "chore: refresh Timberpile package metadata"
```

If there is no attributable tracked diff, do not create an empty commit.
