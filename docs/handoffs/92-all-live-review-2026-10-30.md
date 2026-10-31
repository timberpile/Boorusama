# Issue #92: ready for manual branch review

Branch: `bug/92-selection-share-image`. Session: `all-live-review-20261030`.
Checked runtime/test candidate: `5172d23cbbe2a18f5ca5d08151f46a21ce29b8ba`. This handoff and subsequent report-only
commits do not change runtime, tests, dependencies or generated runtime inputs.
Human acceptance and integration remain pending.

## Review and fixes

Reviewed original display fallback, exact Original/video boundaries, media facts row and all changed tests. Propagated shared Pixiv exact-origin/401 and manual Verify/account-identity fixes from #117 without copying Favorites. Auth/share focused run: 71 passed.

Reviewed the complete branch diff from actual develop merge base
`422aeae087c1108e655d85d1a3dac25120456cd6` and relevant consumers/tests. The result concerns this issue
branch; combining sibling changes or current develop requires checking the
resulting candidate. Older handoffs retain their historical provenance; this
report supersedes their technical-readiness status.

## Verification

Pinned FVM Flutter 3.47.2; six physical-core workers for ordinary tests.

- `./scripts/run_regression_tests.sh`: **passed, exit 0**. Application:
  **5,505 passed**. All 13 package/CLI suites: **1,608 passed**.
  Both repository shell suites and **72 Python tests** passed. No suite was
  omitted. The vendored router retains two declared individual skips:
  `routing config works with shell route` and `Obsolete branches in StatefulShellRoute
  are cleaned up after route configuration change`.
  Evidence: Fresh complete runner on the checked candidate; durable raw log retained in local verification artifacts.
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **passed, exit 0**, on the same
  clean candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  SHA-256: `3ad567197f990cdde03adc8c4da23ec13a73878e5cdbb0acb52776e6872eda42`.
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

1. From Selection Manager, share one/multiple posts as Image before opening viewer media. Available display samples must work when Original is absent; Original/video choices keep their separate availability.
2. Check known and missing media facts: Image stays centered without layout jumps or unsolicited image downloads. Test native share/copy, cancellation and retry.
3. For Pixiv manual credentials, replace the token, Verify and save. Unverified/failed replacements must not retain old account identity; confirm media sharing still works.

No new device installation, UI interaction or authenticated live-service
acceptance was performed in this all-branch pass. Any older device evidence is
limited to its recorded candidate/scenarios. Technical readiness for review does
not approve UX, account-policy choices or integration. No PR, develop merge,
issue closure, branch deletion or release is part of this delivery.
