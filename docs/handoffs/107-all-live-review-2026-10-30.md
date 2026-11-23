# Issue #107: ready for manual branch review

Branch: `feature/107-local-post-sorting`. Session: `all-live-review-20261030`.
Checked runtime/test candidate: `6a9cff5883357ca049e5bdfb26c277730c17885a`. This handoff and subsequent report-only
commits do not change runtime, tests, dependencies or generated runtime inputs.
Human acceptance and integration remain pending.

## Review and fixes

Reviewed all stable score/date sorting, local Feed projection, history suppression, selectors and tests. Fixed actual mixed-source Feed blacklist identity/count and stale-publication behavior using the reviewed #114 controller fix, without toolbar UI. Final affected Feed/controller/selection run: 27 passed. The complete suite exposed a Hive fixture teardown race; the cache-settings test now awaits repository closeFuture after each unmount before reopening/deleting its directory, retaining every settings/cache assertion. Focused final widget test passed.

Reviewed the complete branch diff from actual develop merge base
`422aeae087c1108e655d85d1a3dac25120456cd6` and relevant consumers/tests. The result concerns this issue
branch; combining sibling changes or current develop requires checking the
resulting candidate. Older handoffs retain their historical provenance; this
report supersedes their technical-readiness status.

## Verification

Pinned FVM Flutter 3.47.2; six physical-core workers for ordinary tests.

- `./scripts/run_regression_tests.sh`: **passed, exit 0**. Application:
  **5,533 passed**. All 13 package/CLI suites: **1,608 passed**.
  Both repository shell suites and **72 Python tests** passed. No suite was
  omitted. The vendored router retains two declared individual skips:
  `routing config works with shell route` and `Obsolete branches in StatefulShellRoute
  are cleaned up after route configuration change`.
  Evidence: Fresh complete runner on the checked candidate; durable raw log retained in local verification artifacts.
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **passed, exit 0**, on the same
  clean candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  SHA-256: `5e41fbe2aca2f19fca4a1971f935d7586a6d0251c45f0605ebd8f1fbae681e1d`.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos`, covering every changed
  Dart source/test path: **0 errors, 0 warnings,
  informational findings: 0**, exit 0.
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

1. In Bookmarks, compare highest/lowest score and newest/oldest upload, including ties and missing metadata. Group covers follow the same order. Combine source/tag filters with selection.
2. In a populated cached Topic Feed, change local sort during pending requests/automatic updates. No new remote sort request or Search history entry should be created; closing Search restores normal order. Check equal numeric IDs from different sites against blacklist rules.

No new device installation, UI interaction or authenticated live-service
acceptance was performed in this all-branch pass. Any older device evidence is
limited to its recorded candidate/scenarios. Technical readiness for review does
not approve UX, account-policy choices or integration. No PR, develop merge,
issue closure, branch deletion or release is part of this delivery.
