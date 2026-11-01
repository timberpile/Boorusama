# Issue #106: ready for manual branch review

Branch: `bug/106-live-undo-toast-insets`. Session: `all-live-review-20261030`.
Checked runtime/test candidate: `ebb9c8ecbbd3841e2546f2b59927a71eeaaf0db8`. This handoff and subsequent report-only
commits do not change runtime, tests, dependencies or generated runtime inputs.
Human acceptance and integration remain pending.

## Review and fixes

Reviewed entire root/live inset, measured selection/viewer obstruction, notifier/disposal, Kurumi toast and consumer/test diff. Existing final correction covers actual selection removal at narrow width and 2x text. No additional defect established; native IME/motion acceptance remains manual.

Reviewed the complete branch diff from actual develop merge base
`422aeae087c1108e655d85d1a3dac25120456cd6` and relevant consumers/tests. The result concerns this issue
branch; combining sibling changes or current develop requires checking the
resulting candidate. Older handoffs retain their historical provenance; this
report supersedes their technical-readiness status.

## Verification

Pinned FVM Flutter 3.47.2; six physical-core workers for ordinary tests.

- `./scripts/run_regression_tests.sh`: **passed, exit 0**. Application:
  **5,488 passed**. All 13 package/CLI suites: **1,608 passed**.
  Both repository shell suites and **72 Python tests** passed. No suite was
  omitted. The vendored router retains two declared individual skips:
  `routing config works with shell route` and `Obsolete branches in StatefulShellRoute
  are cleaned up after route configuration change`.
  Evidence: Recorded complete pass on `ebb9c8ecbbd3841e2546f2b59927a71eeaaf0db8`. docs/handoffs/106-final-review.md
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **passed, exit 0**, on the same
  clean candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  SHA-256: `1b4eb02b45f0973d56745e3241605a0217d0658aa7508e9d412646514645cb21`.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos`, covering every changed
  Dart source/test path: **0 errors, 0 warnings,
  informational findings: 23**, exit 0.
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

1. Remove a bookmark through the real Selection Manager and tap Undo while selection remains visible. Repeat in the viewer and close the viewer while the toast is alive; it must stay above current controls.
2. With Undo visible, open/close the native keyboard, resize selection controls, rotate, use large system text and background/resume. Undo stays reachable and executes once; expired/superseded Undo must not restore the wrong removal.

No new device installation, UI interaction or authenticated live-service
acceptance was performed in this all-branch pass. Any older device evidence is
limited to its recorded candidate/scenarios. Technical readiness for review does
not approve UX, account-policy choices or integration. No PR, develop merge,
issue closure, branch deletion or release is part of this delivery.
