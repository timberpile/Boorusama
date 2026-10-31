# Issue #108: ready for manual branch review

Branch: `feature/108-selection-action-parity`. Session: `all-live-review-20261030`.
Checked runtime/test candidate: `937087386e8e39f33ffd843e9f2669b8c8e14303`. This handoff and subsequent report-only
commits do not change runtime, tests, dependencies or generated runtime inputs.
Human acceptance and integration remain pending.

## Review and fixes

Reviewed the complete single/batch action, constrained dialog, compact picker and account snapshot changes. Confirmed a context-menu regression when Comments became available for zero-comment posts: long menus clipped Select/Bookmark. Kurumi now bounds menu width and height to the usable viewport/keyboard and the larger space above/below its opening point, with independent ordinary-action scrolling.

Two actual final-action tests cover exact 320-dp width, upper/lower placement, 2x text, keyboard bounds, one dispatch and dismissal. Updated the production navigation journey for both single BookmarkGroupPicker and batch BookmarkBatchDialog, and the shared test driver to reveal and hit-test scrollable actions. All 169 Kurumi tests and 26 affected application/selection consumers passed. Captured origin/account guards and credentialless local Bookmark fallback remain intact.

The older Danbooru action-label fixture now supplies the production builder required for Comments availability. The final direct-consumer run passed 58 tests, including all 14 original account/rating/localization cases, without weakening assertions.

Reviewed the complete branch diff from actual develop merge base
`422aeae087c1108e655d85d1a3dac25120456cd6` and relevant consumers/tests. The result concerns this issue
branch; combining sibling changes or current develop requires checking the
resulting candidate. Older handoffs retain their historical provenance; this
report supersedes their technical-readiness status.

## Verification

Pinned FVM Flutter 3.47.2; six physical-core workers for ordinary tests.

- `./scripts/run_regression_tests.sh`: **passed, exit 0**. Application:
  **5,483 passed**. All 13 package/CLI suites: **1,610 passed**.
  Both repository shell suites and **72 Python tests** passed. No suite was
  omitted. The vendored router retains two declared individual skips:
  `routing config works with shell route` and `Obsolete branches in StatefulShellRoute
  are cleaned up after route configuration change`.
  Evidence: Fresh complete runner on the checked candidate; durable raw log retained in local verification artifacts.
- `fvm flutter build apk --debug --flavor dev
  --dart-define-from-file=env/dev.json --no-pub`: **passed, exit 0**, on the same
  clean candidate. APK: `build/app/outputs/flutter-apk/app-dev-debug.apk`.
  SHA-256: `67a8c25e504fb7d3fe414a274c65f942eec87207b156cb400d5c63190e267e18`.
- Scoped `fvm flutter analyze --no-pub --no-fatal-infos`, covering every changed
  Dart source/test path: **0 errors, 0 warnings,
  informational findings: 7**, exit 0.
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

1. Change selection from one post to several and back. Single selection exposes the corresponding viewer actions, including inline Share, Comments and ordinary single Download; multiple selection keeps batch actions.
2. Exercise Bookmark add/remove and nested groups at narrow width, enlarged text and keyboard. Change active/source profile while a popup is pending: retain the captured source or fail visibly, never borrow another account.
3. Test native Share, favorite/unfavorite and source-specific actions on configured engines, including a locally bookmarked post whose source is unavailable.
4. Open a long post context menu near the top and bottom of a narrow screen, with enlarged text and a keyboard where relevant. Scroll to Select and Comments; the final action must remain visible, tappable and execute once.

No new device installation, UI interaction or authenticated live-service
acceptance was performed in this all-branch pass. Any older device evidence is
limited to its recorded candidate/scenarios. Technical readiness for review does
not approve UX, account-policy choices or integration. No PR, develop merge,
issue closure, branch deletion or release is part of this delivery.
