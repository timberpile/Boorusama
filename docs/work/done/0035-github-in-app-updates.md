# 0035 — GitHub in-app updates

| Field | Value |
| --- | --- |
| Priority | Normal |
| Area | App updates / Android distribution |
| Status | Completed; local integration authorized |
| Branch | `feature/0035-github-in-app-updates` |
| Agent/session | ChatGPT, 2026-10-15 and 2026-10-20 |
| Worktree | `.worktrees/0035-github-in-app-updates` |
| Base | `develop` at `d4e15586f06192f0ff4315d36a3f61ae69a752d5` |

## Problem

The existing GitHub release checker exposes only a Home search-bar indicator and opens the release page. Checks are effectively once per provider lifetime; no on-resume policy or manual status is available. Users must download and install the correct APK manually.

## Scope and acceptance criteria

- [x] Preserve GitHub-release update notifications and release notes, with at most one automatic foreground check per 24 hours and a forceable manual check.
- [x] Expose a localized Updates entry/status in Settings and report network errors clearly when checked manually.
- [x] Parse existing `boorusama-update.json` APK assets; compare Android build numbers as well as version names and choose an APK compatible with the device's supported ABIs.
- [x] On GitHub Android builds, user explicitly downloads the APK, sees cancel/progress, and can initiate Android's confirmation installer after digest/size and package/version/signature validation.
- [x] Provide unknown-app-sources permission guidance and a GitHub release-page fallback; never silently install or download.
- [x] Gate APK installation strictly to GitHub Android builds. Play build's merged Android manifest must **not** request `REQUEST_INSTALL_PACKAGES`.
- [x] Exercise version parsing, ABI choice, download validation, cooldown, and install safety in automated tests; document device validation and its limits.
- [x] Preserve the release workflow format; integrate into local `develop` only with explicit user authorization (given on 2026-10-20).

## Constraints

Follow `AGENTS.md`, `docs/work/README.md`, and `.agents/skills/implement-change/SKILL.md`. Reuse existing release-manifest receipts and app i18n. Kotlin native platform code should reject arbitrary APK paths. Android must make the final signature decision.

## Progress / verification

2026-10-15: Investigated existing updater, release manifest generator, settings, Android flavors, and signing workflow. Created dedicated branch. GitHub connector allows committed source edits, but the execution environment has no local repository, Flutter/FVM or Android SDK/emulator; compilation, formatting, widget tests, merged-manifest inspection, and on-device installation will remain **unverified** until run in a suitable checkout. Do not mark this work item done or integrate before the required full verification gate.

## Implementation handoff (2026-10-15)

Implemented on this branch:
- Existing GitHub release checker now compares numeric Android build codes where available and parses APK artifact architecture, size and SHA-256 from the existing release manifest.
- 24-hour cooldown for successful foreground checks, one-hour in-memory backoff after errors, cached results in the existing misc Hive box, manual force-check and an opt-out preference persisted in Settings.
- App lifecycle observation at the root (foreground/resume); an Updates settings section reports status and offers Check now.
- Android-only GitHub APK download with progress, cancellation, private cache storage, size and SHA-256 verification; manual OS installer launch, unknown-source permission guidance, browser fallback.
- Android platform channel rejects APKs outside the private updates cache, checks matching package ID, strictly newer version code, expected build/version and exact current signing certificate. The OS installer handles final approval.
- Install-request permission is set through a release-channel Gradle manifest placeholder. GitHub releases should contain REQUEST_INSTALL_PACKAGES; Play and development builds should not.
- Added controlled-clock cooldown tests, ABI/release link tests, build number tests, and settings persistence tests. Added English and German UI strings.

**Not verified**: No local repository/SDK checkout in this session. Cannot run fvm dart format, ./gen.sh, fvm flutter test, Gradle Kotlin compilation, manifest-merge inspection, emulator or physical install tests. Treat this branch as a working implementation candidate, not merge-ready.

**Required checkout verification before merge**:
1. Run `./gen.sh` to generate i18n, then `fvm dart format` on modified Dart files.
2. Run `fvm flutter analyze` for the changed paths and `fvm flutter test test/app_update`. Fix any compilation/test failures; run the full regression suite `./scripts/run_regression_tests.sh` on the integration candidate.
3. Produce signed GitHub release APK and Play AAB variants. Inspect their *merged* manifests: REQUEST_INSTALL_PACKAGES must be present only in GitHub builds, absent in Play builds. Ensure RELEASE_CHANNEL dart-defines reaches Gradle as expected.
4. Perform actual signed version-N to N+1 Android upgrade tests for arm64 and armv7 if available; test unknown-sources opt-in, denied permission, cancel, checksum/size mismatch, signing mismatch, no compatible ABI, app data preservation, and Play variant behavior.
5. Review whether signature rotation should be supported. Current preflight intentionally rejects different signers; user can fall back to the GitHub release page.

No PR, merge, or release was created.

## Continuation (2026-10-15)

- Kept the existing branch rather than replacing the in-progress implementation.
- Hardened Android APK signature preflight: on Android 9/10, if archive `signingInfo` is unavailable, retry via `GET_SIGNATURES` while **still requiring** the archived signer set to exactly match the installed signer set; the OS retains final installer validation.
- Made temporary update storage injectable in the downloader and added HTTP-backed Flutter tests for successful SHA-256/size verification, rejection and cleanup for bad metadata, and cancellation without publishing an unverified APK.
- Inspected the published manifest producer and consumer shapes, GitHub/Play release-channel manifest placeholder, native cache paths, and Settings wiring.
- **Still unverified:** The execution environment has no project checkout, FVM/Flutter/Dart, Android SDK, or device. No compilation, tests, generated localization, merged-manifest check, or on-device installation was performed here. Remain in progress until the validation checklist above passes.

## Local review and corrections (2026-10-15)

Continued the exact requested branch from `f2c1f8a01` in an isolated local
worktree, based on current `develop` / `origin/develop` at `d4e15586f`.

Confirmed defects corrected:
- Concurrent/reopened dialogs used the same pending and verified APK paths.
  Each transfer now owns a private cache subdirectory; failed/cancelled
  transfers remove their directory, including cancellation during verification.
- A failed manual check could refresh to a misleading successful/no-update
  status, and a retained manual result masked later foreground results.
  Preserve the latest error during backoff and display the current provider
  result. Successful checks retain their cooldown even if persistence fails.
- Build-code comparison also affected desktop releases; restrict it to Android
  and reject non-positive string build codes so version comparison can apply.
- The Play update dialog showed an unrelated GitHub action. Keep that action
  for GitHub release links and preserve Play's Later/Update actions.
- Fixed-height dialog content could overflow with enlarged text/keyboard.
  Let the complete dialog scroll so all actions remain reachable.
- Closing a dialog during permission lookup could still launch the installer.
  Recheck widget lifetime before launching the native install operation.
- Require expected build/version metadata on the native channel and extract
  the existing package/version/signer/cache-path rules for JVM safety tests.
- Restrict the install permission placeholder to GitHub **prod** builds; dev
  stays permission-free even if passed a GitHub release-channel define.
- Correct the existing URL test to compare the decoded APK path segment;
  literal `+` is valid in this URL path and need not be percent-encoded.

The initial full application run exposed an inherited flaky bulk-download
session test, unchanged from develop: a fixed 100 ms wait sometimes reached
cancellation while the sessions were still in dry-run preparation. Its isolated
unchanged rerun passed (34 tests). Await preparation/enqueueing explicitly,
retaining concurrent session starts and cancellation assertions; the corrected
whole file also passed (34 tests). Initial full runs were stopped for fixes;
only the final complete run qualifies the corrected candidate.

Focused final checks: 31 updater tests passed, including narrow 320 px layout,
2x text, open keyboard, permission flow, close-during-async actions,
incompatible ABI fallback, foreground cooldown, and manual error recovery.
Affected analysis passed with no issues. Broader analysis including the existing
Settings page reported only two pre-existing `omit_obvious_property_types`
infos (lines 155/284), outside the changed code. Formatting and diff whitespace
checks passed.

Android emulator `emulator-5556` was reserved using the exclusive lease procedure
and booted without wiping its existing data. ADB sees it online. Maestro MCP
`list_devices` repeatedly did not respond, including a bounded 50-second attempt;
interactive UI acceptance cannot yet be claimed.

Final local regression gate: `./scripts/run_regression_tests.sh` passed all 16
required suites using the default six workers: 3,315 application tests, 934
package/CLI tests, 61 Python tests, and both repository shell suites. No test
skips. The application suite includes the 31 focused updater cases. Opt-in
workload benchmarks and Android instrumentation are outside this gate and were
not run.

`fvm flutter analyze --no-pub lib/foundation/app_update
lib/core/settings/src/pages/updates_settings_page.dart
lib/core/settings/src/types/settings.dart lib/core/boorusama_app.dart
test/app_update test/bulk_downloads/providers/downloads/session_test.dart`
passed with no issues. The final whole-diff formatter check exposed one
line-wrap change in Settings; applying that formatting-only change does not
alter the qualified runtime candidate.

`fvm flutter build apk --no-pub --release --flavor prod --target-platform
android-x64 --dart-define=RELEASE_CHANNEL=github` passed. `apksigner verify
--verbose` verified its v2 signature (one signer). APK and merged manifest are
retained under ignored `build/review-0035/`. The GitHub prod merged manifest
contains `REQUEST_INSTALL_PACKAGES`.

`cd android && ./gradlew :app:testProdReleaseUnitTest
-x :app:compileFlutterBuildProdRelease
-Pdart-defines=UkVMRUFTRV9DSEFOTkVMPWdpdGh1Yg==` passed: 40 JVM tests across
seven classes, zero failures/errors/skips. The Flutter compile task was excluded
because the same release APK had already been built. These tests validate the
native preflight policy; they do not replace OS installer acceptance.

The signed GitHub APK installed and launched with `fvm flutter run --no-pub
--release --flavor prod --dart-define=RELEASE_CHANNEL=github
--use-application-binary=build/review-0035/github-x64.apk -d emulator-5556`.
ADB confirmed the process alive, MainActivity resumed, rendered frames, and an
empty crash buffer for that process. This proves installation/startup on the
x86_64 emulator; interactive Settings navigation and an N-to-N+1 update were
not verified through the unavailable Maestro connection.

`fvm flutter build appbundle --no-pub --release --flavor prod
--dart-define=RELEASE_CHANNEL=play` passed, and `jarsigner -verify` verified the
bundle. The Play prod merged manifest and packaged AAB manifest both omit
`REQUEST_INSTALL_PACKAGES`. `cd android && ./gradlew
:app:processDevDebugManifest -x :app:compileFlutterBuildDevDebug
-Pdart-defines=UkVMRUFTRV9DSEFOTkVMPWdpdGh1Yg==` passed; its dev manifest also
omits the permission despite the GitHub define. Saved APK/AAB/manifests remain
in ignored `build/review-0035/` for inspection.

The builds emitted non-fatal Kotlin/Gradle deprecation warnings, the documented
libavif cache-hook warning, and a Cupertino font tree-shaking warning. None
prevented builds or the emulator start; toolchain/font maintenance is outside
this updater review. The app produced no Flutter/AndroidRuntime error log
entries during the start check. The test app and the emulator started for this
review were stopped, and the emulator lease was released.

Remaining acceptance: interactive Settings/permission/download/installer flows
through Maestro; real signed N-to-N+1 upgrades, especially arm64/armv7, signature
mismatch/rotation handling and data preservation on-device. Exact current-signer
matching remains intentional; signature rotation support was not redesigned.
Keep the work item in progress until that Android acceptance is performed.

The complete suite checked the candidate based on `f2c1f8a01` with the runtime
and test corrections described above. Subsequent edits were limited to
formatting, a comment and this report, so the complete pass remains applicable.
No merge, PR, push, tag or remote modification was performed.

## Follow-up emulator upgrade validation (2026-10-15)

The user supplied running `emulator-5554`. Reserved that exact serial; left the
existing app data intact. It initially contained the signed performance build
with Android version code 4190. Test APKs therefore use base build numbers
4191/4192, which Flutter's x64 ABI split encodes as Android codes 8191/8192.
Both use the existing permanent signing certificate and the production package
ID `com.timberpile.boorusama`.

The test exposed a release-contract defect missed by the initial review:
`boorusama-update.json` records the base build number from the release receipt,
while GitHub release APKs are built with `--split-per-abi`. The pinned Flutter
3.47.2 Gradle plugin adds 1000 for armv7, 2000 for arm64 and 4000 for x64.
Comparing the base receipt number to PackageInfo's encoded Android code hid
valid upgrades, and passing that base number to native preflight would reject
the downloaded APK. The checker now selects using the actual device ABI and
compares the resulting Android code. Installation passes the same encoded
code; the existing receipt schema, filenames and raw cached release build
number remain compatible. Universal APKs keep their base code.

Added regression cases for all three split architectures, universal builds,
up-to-date/newer installed builds, base values above 1000, and the install
channel's exact encoded build argument. Focused updater suite: 39 passed.
Affected analysis: no issues. Complete local regression runner passed again:
3,323 application tests, 934 package/CLI tests, 61 Python tests and both shell
suites, no skips.

The hosted Maestro connector again timed out. A separate local Maestro MCP
STDIO session (`maestro mcp --no-viewer`, Java 17) successfully listed and
controlled the exact reserved emulator. No shared MCP configuration/process was
changed. The initial temporary harness used an extra outer ProviderScope and
showed the generic import-recovery gate; the revised ignored harness injects
only the downloader into the normal root scope, keeping initialization and the
recovery gate intact.

The temporary entrypoint and artifacts live only under ignored
`build/upgrade-0035/`. Version N fetches a receipt-shaped manifest from a
loopback-only HTTP server forwarded over ADB; only the matching test APK URL
is rerouted to that server. The real parser, ABI selection, HTTP file download,
size/SHA-256 checks, private cache, native package/version/signer preflight and
OS confirmation installer remain active. Version N+1 uses the ordinary
production entrypoint with no fixture overrides. This is a controlled local
upgrade test, not a publication or GitHub CDN acceptance test.

### Upgrade result: passed on x86_64

- Both corrected signed APK builds passed. Source candidate: `8b832f69e` plus
  the ABI-code changes in this follow-up; no production entrypoint or release
  workflow changes. Base build 4191 / Android 8191 was installed with `adb
  install -r` solely to prepare N. N+1 was **not** installed through ADB.
- With automatic checks switched off in Settings, Check now detected the
  same-version-name update (4.5.0-timberpile.5) using Android codes 8191→8192.
- Explicit Download update transferred 107,950,008 bytes. The real downloader
  displayed APK verified and ready to install after size and SHA-256 validation.
  The target digest was
  `8b739d830064cb169f7d3fad093b247ea6074b51557abe038d6710150d383dbf`.
- With install-source permission initially disallowed, Install update showed
  the localized guidance and Allow installs opened the actual Android
  Install unknown apps screen. Enabled Allow from this source via Maestro.
- Native package/version/current-signer validation passed. Android displayed
  Update this app? for Boorusama Timber. Confirmed Android's Update button via
  Maestro; Android then displayed App updated.
- PackageManager independently reported Android version code 8192 and retained
  firstInstallTime `2026-10-10 18:35:42`; no uninstall or data reset occurred.
- Open from the OS installer launched the ordinary N+1 production entrypoint.
  Maestro assertions confirmed the existing safebooru profile, Default group,
  the local `UpdateTest0035_8191` group created before the upgrade, and the
  persisted disabled automatic-update setting. No recovery gate appeared with
  the corrected harness or ordinary N+1 app.
- Removed only the empty test group and verified Default remained. Restored
  automatic checks to their original enabled value, reset install-source
  permission to the original non-allowed/default mode, removed the exact ADB
  reverse mapping, and stopped the loopback server. The updated app process
  had no Flutter/AndroidRuntime error entries. Released the emulator lease;
  the user-started emulator was left running with test build 8192 installed.

Ignored local evidence includes `package-before.txt`, `package-after.txt`,
`sentinel-before.json`, `sentinel-after.json`, `settings-after.json`, the native
confirmation screenshot and App updated hierarchy under `build/upgrade-0035/`.
These are local acceptance artifacts and are not committed.

Remaining limits: arm64/armv7 physical upgrades and signature rotation are not
proved by this x64 emulator run. Download cancellation/checksum rejection and
unsafe native identities remain covered by the previously recorded automated
checks; those negative device paths were not rerun here. The local fixture
proves the app/OS upgrade path, not a publication or production CDN download.
The final full pass applies to the ABI runtime/test changes in this commit;
subsequent changes were this report only. No push or merge was performed.


## Final integration validation (2026-10-20)

The user explicitly authorized integration into local `develop`. The existing
feature worktree was reused. Current `develop` at
`3bf372bb01ba475659059b459ed3949b39d3cea1` is already an ancestor of the feature
tip, so the combined integration candidate requires no conflict resolution.
The runtime/test candidate checked was
`9b1409a1e7ccae77932c545a4aafdba4be4956cf` (tree
`188084fa02065c57ab9d99798c406e759d3d7ed6`). Its final rebase correction uses
`MiscDataStore` for the persisted check cooldown; the added provider test covers
restart persistence and isolation after upgrading the installed build number.

Verification on that exact combined candidate:

- `./scripts/run_regression_tests.sh`, using the default six physical-core
  workers: exit 0. Passed 4,146 application tests, 1,467 package/CLI tests,
  72 Python tests, and both repository shell suites. All 17 required suites
  completed. No failure markers. The vendored `go_router` suite has two existing
  `skip: true` tests (`routing config works with shell route` and obsolete
  StatefulShellRoute branch cleanup); that package is unchanged from develop.
  No new skips were introduced. Opt-in workload benchmarks were not run.
- `fvm flutter analyze --no-pub lib/foundation/app_update
  lib/core/settings/src/pages/updates_settings_page.dart
  lib/core/app_external_effects.dart test/app_update`: exit 0, no issues.
- From `android`, `./gradlew :app:testProdReleaseUnitTest --offline
  --console=plain -Pdart-defines=UkVMRUFTRV9DSEFOTkVMPWdpdGh1Yg==`:
  BUILD SUCCESSFUL. All 40 native tests across seven classes passed, without
  errors or skips. This also compiled the production GitHub Flutter/native
  integration against the current develop base.
- `git diff --check develop..HEAD`: passed. Subsequent changes only complete
  and move this historical work item; they do not change the checked runtime,
  tests, dependencies, or generated runtime output.

The prior signed x86_64 N-to-N+1 emulator result above remains historical device
acceptance; no emulator was operated during this integration. The rebased
candidate received the fresh automated checks above. Physical ARM upgrades,
signing-key rotation, and production GitHub CDN delivery remain unverified;
the existing strict signer policy and release workflow are unchanged.

Acceptance APKs, merged manifests, emulator evidence, current test logs/native
XML reports, and local Android configuration are preserved outside the task
worktree at `.worktrees/.artifacts/0035-github-in-app-updates-20261020/`.
The earlier `build/upgrade-0035/` and `build/review-0035/` paths describe their
original locations. These private local artifacts are ignored and not committed.
The task is complete and approved for a single local squash commit into develop;
its task worktree and local feature branch can then be removed after verifying
identical integrated contents. Publication and remote branch deletion were not
authorized.
