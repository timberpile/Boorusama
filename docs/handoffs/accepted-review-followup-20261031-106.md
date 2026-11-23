# Accepted review follow-up handoff — #106

Prepared 2026-10-31. Branch `bug/106-live-undo-toast-insets`.

Verified implementation/test candidate: `f16b529b3c0b20af77d5143f8b464318a1a79030`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Ordinary success and Undo share the live feedback inset wrapper. Bookmark callers resolve the actual scoped feedback context. Selection obstruction measures controls above the keyboard once, including nested hosts, and considers native view insets when a resizing Scaffold has consumed its body MediaQuery inset. OKToast window movement is disabled only for the full-inset scoped host.

Actual device QA exposed a remaining double-counted keyboard despite earlier simulated checks. A new real BookmarkPage/Scaffold regression failed with a 316-dp gap instead of 16; the native/local inset measurement fixed it. Reviewed root/nested navigation, safe area, footer offsets, viewer/selection transitions and ordinary callers. Unrelated comic notice behavior was restored and retested.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 637.7 s, exact candidate `f16b529b3c0b20af77d5143f8b464318a1a79030`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 45.7 s, build commit `f16b529b3c0b20af77d5143f8b464318a1a79030`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/widgets/bookmark_context_menu_section.dart lib/core/bookmarks/src/widgets/bookmark_group_picker.dart lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart lib/core/navigation/navigation_overlay_insets.dart lib/core/posts/listing/src/_internal/raw_post_grid.dart packages/kurumi/lib/src/components/media_query.dart packages/kurumi/lib/src/components/toast.dart packages/kurumi/test/toast_test.dart test/application/bookmark_selection_keyboard_toast_test.dart test/application/timeline_selection_undo_insets_test.dart test/core/navigation/root_undo_toast_insets_test.dart test/core/navigation/undo_toast_insets_test.dart test/support/keyboard_toast_host.dart` — PASS: 0 errors, 0 warnings, 12 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 f16b529b3c0b20af77d5143f8b464318a1a79030` passed.
- Focused evidence `consumed-inset-green-v2`: `fvm flutter test --no-pub --concurrency=6 test/application/bookmark_selection_keyboard_toast_test.dart test/application/timeline_selection_undo_insets_test.dart test/core/navigation/undo_toast_insets_test.dart test/core/navigation/root_undo_toast_insets_test.dart` — PASS (16.0 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `measured-final`: `fvm flutter test --concurrency=6 test/application/timeline_selection_undo_insets_test.dart test/core/navigation/undo_toast_insets_test.dart test/core/navigation/root_undo_toast_insets_test.dart test/core/navigation/navigation_overlay_insets_test.dart test/application/post_selection_layout_flow_test.dart` — PASS (71.0 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/106-live-undo-toast-insets/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `2ec02f096e01f2eb21f00bcd505de2454792d86d919e19e076ad73fb9368ed21`.

Final normal-duration APK ordinary success checked live. A separately hashed QA variant changes only both toast durations to 30 seconds for stable keyboard geometry inspection; stable success and Undo screenshots plus actual bounds were checked. Actual Undo restored two of two memberships. Final source and normal APK were restored; QA groups/posts removed. QA duration is not production behavior.

Detailed actual observations and provenance are retained in `106-device-observations.json` (and the duration-only QA provenance/patch/bounds for #106).

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. With a Selection Manager active, trigger an ordinary Add To success: it must sit above the controls.
2. Keep selected posts in one group, remove their membership from another, open/focus Search with the real keyboard: Undo follows the controls and remains tappable.
3. Tap Undo and inspect actual group membership; hide/show keyboard, leave selection, navigate root/nested pages and viewer.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
f16b529b3c0b20af77d5143f8b464318a1a79030 fix: exclude consumed keyboard inset from selection feedback (#106)
31862361759e270bcc39944fa358ee344b5c39ab fix: preserve explicit context for comic-strip notices (#106)
7c2d6266d22adab2989659ffa2dff11e700d1ce2 fix: unify live bookmark toast obstruction geometry (#106)
```
