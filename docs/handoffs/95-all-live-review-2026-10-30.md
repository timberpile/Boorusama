# Issue #95: ready for manual branch review

Branch: `feature/95-artist-links`. Session: `all-live-review-20261030`.
Checked runtime/test candidate: `7fa4e4f7fadd28cdf332c6855ac18e4fd28b3e9a`. This handoff and subsequent report-only
commits do not change runtime, tests, dependencies or generated runtime inputs.
Human acceptance and integration remain pending.

## Review and fixes

Reviewed complete artist URI/envelope/parser, profile receiver, production Artist header, sharing adapter and tests. Existing adapter already contains unsupported native errors; no redundant catch or further runtime defect found.

Reviewed the complete branch diff from actual develop merge base
`422aeae087c1108e655d85d1a3dac25120456cd6` and relevant consumers/tests. The result concerns this issue
branch; combining sibling changes or current develop requires checking the
resulting candidate. Older handoffs retain their historical provenance; this
report supersedes their technical-readiness status.

## Verification

Pinned FVM Flutter 3.47.2; six physical-core workers for ordinary tests.

- `./scripts/run_regression_tests.sh`: **passed, exit 0**. Application:
  **5,500 passed**. All 13 package/CLI suites: **1,608 passed**.
  Both repository shell suites and **72 Python tests** passed. No suite was
  omitted. The vendored router retains two declared individual skips:
  `routing config works with shell route` and `Obsolete branches in StatefulShellRoute
  are cleaned up after route configuration change`.
  Evidence: Fresh complete runner on the checked candidate; durable raw log retained in local verification artifacts.
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **passed, exit 0**, on the same
  clean candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  SHA-256: `0a71a84c7df0a6115530e78f7632fb5958518c21fc698228c59320c8c4169841`.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos`, covering every changed
  Dart source/test path: **0 errors, 0 warnings,
  informational findings: 6**, exit 0.
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

1. Share an Artist link from a Danbooru Artist page; reopen its .bslink while the app is running and from a cold start. Confirm the same artist and site.
2. Repeat with another globally active profile and with the source profile unavailable. Check profile setup/selection and cancellation without borrowing unrelated credentials; inspect long names at large text.

No new device installation, UI interaction or authenticated live-service
acceptance was performed in this all-branch pass. Any older device evidence is
limited to its recorded candidate/scenarios. Technical readiness for review does
not approve UX, account-policy choices or integration. No PR, develop merge,
issue closure, branch deletion or release is part of this delivery.
