# Issue #118: ready for manual branch review

Branch: `feature/118-pixiv-following-artists`. Session: `all-live-review-20261030`.
Checked runtime/test candidate: `5b2ef956de4e809fbae70a51c0dfd0d4e8ad93e9`. This handoff and subsequent report-only
commits do not change runtime, tests, dependencies or generated runtime inputs.
Human acceptance and integration remain pending.

## Review and fixes

Reviewed complete Following navigation/card/presentation/provider/DTO/client and tests. Propagated shared Pixiv origin/401 and manual Verify identity fixes; retained supplied-only previews, strict scoped advancing offset, cancellation, retry retention and source numeric user Search. Formatted all changed Dart. Auth/Following focused run: 61 passed.

Reviewed the complete branch diff from actual develop merge base
`422aeae087c1108e655d85d1a3dac25120456cd6` and relevant consumers/tests. The result concerns this issue
branch; combining sibling changes or current develop requires checking the
resulting candidate. Older handoffs retain their historical provenance; this
report supersedes their technical-readiness status.

## Verification

Pinned FVM Flutter 3.47.2; six physical-core workers for ordinary tests.

- `./scripts/run_regression_tests.sh`: **passed, exit 0**. Application:
  **5,514 passed**. All 13 package/CLI suites: **1,621 passed**.
  Both repository shell suites and **72 Python tests** passed. No suite was
  omitted. The vendored router retains two declared individual skips:
  `routing config works with shell route` and `Obsolete branches in StatefulShellRoute
  are cleaned up after route configuration change`.
  Evidence: Fresh complete runner on the checked candidate; durable raw log retained in local verification artifacts.
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **passed, exit 0**, on the same
  clean candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  SHA-256: `1c5c5a40c4981c42aa40dd4092e9b0c793c5b5bc69b34bb0417d2f757a839488`.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos`, covering every changed
  Dart source/test path: **0 errors, 0 warnings,
  informational findings: 8**, exit 0.
- Task Dart formatting, complete correction review and `git diff --check`: passed.

The host restarted during this pass. Interrupted jobs were not counted as
passes. Completed results observed before restart were recovered against the
unchanged source commits; surviving APK hashes were verified. Subsequent logs
and recovery state use durable, ignored workspace artifacts. Existing complete
passes are reused only for the same runtime/test candidate with verified
documentation-only differences.

Existing native-hook/finalizer diagnostics and Android toolchain-support warnings
may occur during successful commands. They were not suppressed or claimed fixed.
Passing assertions and exit codes do not imply warning-free native runtime logs.

## Manual checks

1. Open Pixiv Tools -> Following Artists while global Following Topics remains available. Compare Public/Private, load more, refresh and retry; errors remain visible without dropping known results.
2. Inspect avatar/name and zero-to-three supplied previews at narrow width and enlarged text. Missing previews keep cards usable, no requests fill missing slots, and explicit covers reset with artwork/artist/account changes.
3. Tap an artist with another profile globally active: normal Search opens in the source Pixiv profile using `user:<numeric-id>`. Switch account/privacy during loading and test manual token Verify. Live mute/unknown-payload and local-blacklist preview policies remain acceptance questions.

No new device installation, UI interaction or authenticated live-service
acceptance was performed in this all-branch pass. Any older device evidence is
limited to its recorded candidate/scenarios. Technical readiness for review does
not approve UX, account-policy choices or integration. No PR, develop merge,
issue closure, branch deletion or release is part of this delivery.
