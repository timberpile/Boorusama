# Accepted review follow-up handoff — #130

Prepared 2026-10-31. Branch `feature/130-adaptive-titles`.

Verified implementation/test candidate: `cf6cd9e3b2e4819bb2564a2bbfc7e803bed1791b`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `de5928283aa39f0d67d6a834e42d4fa5e9369b86`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Suitable bounded settings, bottom-sheet, searchable-option-sheet and notice-card title hosts use the existing Kurumi fitter. Custom FollowTopic/PostsPerPage dialog titles have explicit local bounds; FollowTopic accounts for the real keyboard. Existing fitted app bars are not wrapped twice; intrinsic dialogs, scroll-flow headings and ordinary accessible values retain justified wrapping.

The committed adaptive-title audit covers each surface category and exceptions. Reviewed intrinsic-width constraints, action space/hit targets, keyboard availability, semantics and both themes. A geometry test caught the FollowTopic action behind the keyboard. A separate existing grid-sizing probe was corrected to avoid treating real decoder latency as a sizing contract; controlled image-picker deadline tests remain unchanged.

No new sibling-branch prerequisite was added by this correction.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1103.1 s, exact candidate `cf6cd9e3b2e4819bb2564a2bbfc7e803bed1791b`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 356.5 s, build commit `aab442097b08017ef0aabd197d77c4213cbdd5b8`.
- Non-runtime changes after that build: `test/core/posts/listing/post_grid_item_test.dart`.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/search/following_topics/src/widgets/follow_topic_dialog.dart lib/core/settings/src/pages/appearance/posts_per_page_dialog.dart packages/kurumi/lib/src/components/bottom_sheet_header.dart packages/kurumi/lib/src/components/info_container.dart packages/kurumi/lib/src/components/option_searchable_sheet.dart packages/kurumi/lib/src/components/settings_card.dart packages/kurumi/test/adaptive_title_hosts_test.dart test/core/posts/listing/post_grid_item_test.dart test/core/search/following_topics/follow_topic_dialog_test.dart` — PASS: 0 errors, 0 warnings, 3 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check de5928283aa39f0d67d6a834e42d4fa5e9369b86 cf6cd9e3b2e4819bb2564a2bbfc7e803bed1791b` passed.
- Focused evidence `title-final-v2`: `fvm flutter test --concurrency=6 test/adaptive_title_hosts_test.dart` — PASS (15.1 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `consumers-keyboard-final`: `fvm flutter test --concurrency=6 test/settings/posts_per_page_presets_test.dart test/core/search/following_topics/follow_topic_dialog_test.dart test/core/bookmarks/bookmark_group_name_dialog_test.dart test/core/tags/favorites` — PASS (86.9 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `kurumi`: `fvm flutter test --concurrency=6` — PASS (20.9 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `grid-probe-final`: `fvm flutter test --concurrency=6 test/core/posts/listing/post_grid_item_test.dart test/core/images/image_candidate_picker_test.dart` — PASS (20.8 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/130-adaptive-titles/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `30882d8eeb59eb5b24ef3b0a94f889ee8f3ef1b4171bee16be961611c9c4a3a3`.

Actual Posts Per Page Custom keyboard dialog and settings headers passed live without saving settings. Live Search Follow routes to the destination picker, not FollowTopicDialog; that dialog is covered by direct production-widget tests. 320dp/2x/both themes covered by widget tests. See 130-adaptive-title-audit.md for justified exceptions.

Detailed actual observations and provenance are retained in `130-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. At narrow width and large system text, inspect app bars, settings card headers, editable/searchable sheets and notice headers; title and actions must remain readable.
2. Open Appearance > Posts Per Page > Custom with keyboard: title, input and Cancel/OK stay available. Cancel.
3. Check FollowTopic dialog, shared sheets and light/dark themes. Intrinsic dialogs and scroll-flow headings should wrap normally.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
cf6cd9e3b2e4819bb2564a2bbfc7e803bed1791b test: separate grid sizing from real decode deadlines (#130)
aab442097b08017ef0aabd197d77c4213cbdd5b8 fix: adopt adaptive titles in constrained shared headers (#130)
```
