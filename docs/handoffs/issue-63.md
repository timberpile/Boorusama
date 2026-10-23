# Issue #63 — Local acceptance handoff

Branch: `bug/63-scroll-to-top`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/63

## Implementation and rationale

The shared `KurumiScrollToTop` previously checked its top boundary only when `userScrollDirection` changed. A continuous upward drag could therefore reach zero without hiding the button. The boundary is now checked on every position notification, independently of direction. A half-logical-pixel tolerance uses `minScrollExtent`, rather than assuming an exact zero. Normal upward/downward visibility away from the top is retained, without restarting an already requested animation.

The component now detaches and rebinds listeners when its supplied controller changes, disposes only owned controllers, tolerates unattached/multiply attached controllers, and synchronizes after a rebuild's layout. The scroll-to-bottom component and unrelated controller extensions are unchanged.

Regression tests in `packages/kurumi/test/scroll_to_top_test.dart` cover a single continuous drag, jumpTo including near-zero, animateTo, ballistic scrolling, controller replacement, content shrink, and an unattached controller. Widget pumps advance Flutter's controlled clock; there are no wall-clock sleeps.

## Verification status

Source reviewed, including the application consumer `PostGridScrollToTopButton`. **Formatting, analysis, tests, and device checks have not run:** this remote environment has no Flutter/Dart/FVM SDK and cannot clone GitHub. This is an implementation handoff, not passed acceptance or integration readiness.

## Required local acceptance

1. Fetch and use this branch in its own isolated worktree. Read `AGENTS.md`. Initialize the pinned FVM SDK, dependencies, and missing generated output through the normal bootstrap workflow.
2. Format both changed Dart files. From `packages/kurumi`, run its complete `fvm flutter test` suite with concurrency from `python3 ../../scripts/physical_core_count.py`, and analyze the package. Run affected application grid/search/bookmark consumer tests as well; select existing paths after inspecting `test/core/posts` and `test/core/bookmarks`.
3. Check the original gesture on real grid screens: scroll down, then continuously drag up to the start; repeat with a fling and the button's jump action. Verify downscroll hides and upscroll below the top still shows the button.
4. Check refresh/filter/content shrink, tab/grid controller replacement, and navigation away during animation. In particular, verify a content-only rebuild that does not rebuild the button still delivers the controller's boundary notification. If a consumer suppresses that notification, route its metrics change through the existing shared boundary rather than adding polling. Check an enlarged-text/narrow layout. Acquire the documented exclusive emulator lease before device work.
5. Review the full diff and fix small defects on this branch, rerun checks, and record exact commands/results and the checked commit. `./scripts/run_regression_tests.sh` must pass on the eventual combined develop integration candidate.

## Coordination

Independent of the other quick-win branches. No merge, PR, issue closure, or deletion is authorized. Include `#63` in any subsequently approved final integration commit subject. Keep `Refs #63` while required acceptance is outstanding.

## Local acceptance evidence (2026-10-22)

Checked runtime/test commit: `d716ecf6a689475435597ca896ae931fdc11e7b8`. Initialized missing generated output with `./gen.sh`, formatted changed Dart files, and passed `git diff --check`.

- Reproduced a content-only shrink defect: the button remained visible after the grid reached its boundary without rebuilding the button. Added optional `layoutChanges` to the shared component and connected the existing grid items notifier. It schedules the existing post-layout synchronization and follows listener disposal/replacement; no polling was introduced.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/scroll_to_top_test.dart` from `packages/kurumi`: **8 passed** after the fix, including the newly reproduced shrink path.
- `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/core/posts test/core/bookmarks test/core/search`: **1811 passed**.
- Package Dart analysis passed without errors or warnings.
- `./scripts/run_regression_tests.sh` on the committed runtime/test candidate: **incomplete (runner exit 143)**. All stage logs reported success, but termination is not a clean complete-suite pass. Application **4459 passed**; all **13 package/CLI suites passed**, including Kurumi **141 passed**. The two existing go_router skips are `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. Both shell tooling suites passed; Python tooling **72 passed**. Full log: `/tmp/boorusama-acceptance/63-scroll-to-top-full-regression.log`.

Flutter 3.47.2 / Dart 3.13.2 and six detected physical-core workers were used, with `FVM_CACHE_PATH=/tmp/boorusama-acceptance/fvm` pointing at an isolated copy of the pinned SDK. Generated files remain ignored. Android gesture/navigation acceptance is still outstanding at this point. No merge, push, PR, issue closure, deletion, or combined-develop qualification occurred.

### Complete-run repeat and Android follow-up (2026-10-23)

The unchanged-candidate full repeat finished **exit 1**, with **4457 application tests passed and two failures** before package/tooling stages. Both failures were asynchronous file cleanup after their tests completed: `test/settings/image_cache_limit_ui_test.dart` tried deleting a missing Hive lock, and `test/core/posts/shares/share_sheet_unsupported_media_test.dart` tried releasing an already-deleted temporary share image. Both test files and implicated production files match the branch base. Each entire test file then passed in isolation with `fvm flutter test --no-pub --reporter=expanded --concurrency=1 <file>`: **1 passed each**. The earlier post/bookmark/search consumer pass also included the share fixture. No unrelated cleanup, sleeps, timeouts or expectations were changed. These results do not establish a clean complete-suite pass. Logs: `/tmp/boorusama-acceptance/63-scroll-to-top-full-regression-rerun.log`, `63-cache-settings-isolated-rerun.log`, `63-share-cleanup-isolated-rerun.log`.

Initialized Flutter native plugin metadata with `fvm flutter pub get --offline`, then `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed under an exclusive emulator lease using `adb -s emulator-5554 install -r`, preserving data. APK SHA-256: `73f6a73a7a3cf1dce0024154de0613c5ec9ebed93be8f6de315fa124f1a3c9fa`.

Maestro used the existing populated Safebooru profile at 360 dp portrait width. Scrolled down, reversed upward below the top and observed the button, then used one continuous upward-to-start drag and visually confirmed the button disappeared at the first tiles. At 2x text, exercised the jump button and switched Following/Browse, returning to the grid without a crash. Screenshots: `/tmp/boorusama-acceptance/63-{grid-start,upscroll-below-top,continuous-drag-top,jump-top-2x,return-grid-2x}.png`.

Real-device content-only shrink/refresh/filter/controller-replacement and interruption during an animation remain covered only by controlled widget fixtures rather than this manual pass. Combined-develop qualification and a clean complete-run result remain outstanding. No merge, push, closure or branch deletion occurred.

## Review V2 remediation (2026-10-23)

Starting/runtime commit: `249a180accbc7125fb17de180abb0d44b171f1cc`, identical to the review's pinned #63 head. Final commit is the documentation-only commit containing this section. No application, package, fixture, concurrency or timeout changes were needed.

The historical `/tmp/boorusama-acceptance/63-scroll-to-top-full-regression-rerun.log` is no longer present; its exceptions were not independently re-inspected. The two implicated current fixtures were inspected: they use per-test temporary directories, and the share fixture owns its mock file lease. No prior test run owned by this session was active when the retry began. Dependencies were refreshed with `fvm flutter pub get --offline`; no tracked dependency/generated files changed. The complete runner used a newly created task-owned `TMPDIR` (`mktemp -d /tmp/boorusama-review-63.XXXXXX`) to isolate its filesystem root, retaining the default **six physical-core workers** and all normal suites.

`TMPDIR="$task_tmp" ./scripts/run_regression_tests.sh`: **passed, exit 0**. **4,459 application tests**, all **13 package/CLI suites** (Kurumi: **141 passed**), both shell tooling suites, and **72 Python tooling tests** passed. The same two existing go_router skips remain (`routing config works with shell route`; `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`). Log: `/tmp/boorusama-review-63-full.log`; bootstrap log: `/tmp/boorusama-review-63-bootstrap.log`. Flutter 3.47.2 / Dart 3.13.2. No test was excluded or retried within this successful runner, and concurrency was not reduced. Earlier unsuccessful runs remain unsuccessful historical evidence.

This resolves V2's missing clean **standalone** regression result. There is no persistent failure requiring baseline reproduction. No new #63 device run was performed; the manual scenario limits above remain. Current develop (`afc04f4933aa0e442b9f80b2662f0fc5ad277379`) and the other issue branches were not integrated or changed by this verification. A future combined candidate still needs its own complete gate. No merge, push, PR, issue closure, branch deletion or worktree deletion occurred.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `5876551df7517179e840539e2a0a5d113a0d9fb3`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

V2 is resolved by the successful complete integration run recorded below; no concurrency reduction, test skip or timeout change was used. Controller ownership/replacement, top-boundary ordering and `layoutChanges: controller.itemsNotifier` remain intact.

Maestro scrolled the actual populated Browse timeline down, reversed direction to show the floating control, then tapped it. Visually confirmed the original top/header returned and the button disappeared. Continuous/ballistic/programmatic movement, near-zero, replacement/unattached controller and content-shrink cases pass in Kurumi's complete suite.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
