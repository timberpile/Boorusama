# Accepted review follow-up handoff — #108

Prepared 2026-10-31. Branch `feature/108-selection-action-parity`.

Verified implementation/test candidate: `8c783e3e813381e6dc6cc86f1f9ce0a17f450075`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Single-post selection uses the actual viewer Bookmark group-picker anchor. Batch actions retain a compact dialog with a dialog-specific bounded adaptive title. Remove From lists only applicable groups and necessary ancestors; Add remains the normal tree. Decorated actions preserve primary type/metadata and session/post identity.

Reviewed actual viewer anchor reuse, single/batch transitions, action decorator compatibility, async account/post snapshots, source/auth keys, filtered remove-tree navigation and large-text dialog bounds. Updated an obsolete folder expectation after valid pruning returns to root.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1037.3 s, exact candidate `8c783e3e813381e6dc6cc86f1f9ce0a17f450075`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 101.4 s, build commit `9828060c0377952bbd8e85241e4eefdba6c6251a`.
- Non-runtime changes after that build: `test/core/bookmarks/bookmark_folder_ux_test.dart`.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/widgets/bookmark_batch_dialog.dart lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart lib/core/posts/listing/src/widgets/default_multi_selection_actions.dart lib/core/widgets/multi_select_button.dart test/core/bookmarks/bookmark_batch_dialog_layout_test.dart test/core/bookmarks/bookmark_batch_remove_paths_test.dart test/core/bookmarks/bookmark_folder_ux_test.dart test/core/posts/listing/selection_action_parity_test.dart` — PASS: 0 errors, 0 warnings, 15 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 8c783e3e813381e6dc6cc86f1f9ce0a17f450075` passed.
- Focused evidence `focused-final-v2`: `fvm flutter test --no-pub --concurrency=6 test/core/posts/listing/selection_action_parity_test.dart test/core/bookmarks/bookmark_batch_dialog_layout_test.dart test/core/bookmarks/bookmark_batch_remove_paths_test.dart test/core/bookmarks/bookmark_bulk_current_group_test.dart test/application/selection_search_actions_flow_test.dart` — PASS (104.5 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `final-metadata`: `fvm flutter test --no-pub --concurrency=6 test/core/posts/listing/selection_action_parity_test.dart test/core/widgets/multi_selection_action_bar_test.dart test/core/bookmarks/bookmark_batch_dialog_layout_test.dart test/core/bookmarks/bookmark_batch_remove_paths_test.dart test/core/bookmarks/bookmark_bulk_current_group_test.dart test/application/selection_search_actions_flow_test.dart` — PASS (75.2 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `dynamic-paths`: `fvm flutter test --concurrency=6 test/core/bookmarks/bookmark_folder_ux_test.dart test/core/bookmarks/bookmark_batch_remove_paths_test.dart` — PASS (103.8 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/108-selection-action-parity/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `327d2292e2f996a5250236102d06174e1cbab7fc37da1ce0b94df9ab3cd8c322`.

Actual single -> batch -> single passed on device; batch cancellation and Remove no-applicable state checked without library mutation. Populated/nested applicable trees and stale account/selection behavior are controlled tests. #130 app-wide title adoption stays separate.

Detailed actual observations and provenance are retained in `108-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Select one post and tap Bookmark: compact viewer-style anchor. Select a second: batch Add To/Remove From menu and compact dialog. Return to one selected post.
2. Remove From should show only applicable groups plus required ancestors; Add To retains the normal destination tree.
3. Use long group/title text, narrow width, enlarged text and keyboard; change account or selection while a picker is pending.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
8c783e3e813381e6dc6cc86f1f9ce0a17f450075 test: reconcile live removal paths with applicable groups (#108)
9828060c0377952bbd8e85241e4eefdba6c6251a fix: align selection bookmark actions and removal paths (#108)
```
