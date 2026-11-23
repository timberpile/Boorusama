# Local acceptance corrections — Issue #106

## Scope and commits

Branch: `bug/106-live-undo-toast-insets`. Initial commit: `8c5576153e516c56f22b0bf3fceeefbca3a50533`. Final runtime/test candidate: `3c2edf7a07d6412ba207a518b55a90541854780d`. This report is a subsequent documentation-only commit; its final HEAD is listed in the aggregate handoff. The complete regression below checked this exact candidate; report-only updates do not change it.

Local corrections only. No push, merge, PR, issue closure or branch deletion was authorized or performed.

## Changes and diagnosis

Removed only the redundant vertical container padding around action toasts. A single-line Undo toast now uses its 48 dp action height; longer/enlarged messages can still grow. Ordinary success toasts and the accessible action target retain their contracts. The actual Bookmark production test now exercises the same live toast through consumed native keyboard heights 200, 360, 300 at 1x/2x. Root Search Undo/mutation coverage remains.

No additional keyboard offset was added: direct measurements of the starting implementation contradicted the reported overlap on this emulator, so applying another displacement would count the existing movement twice.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/application/bookmark_selection_keyboard_toast_test.dart test/application/timeline_selection_undo_insets_test.dart test/core/navigation/root_undo_toast_insets_test.dart test/core/navigation/undo_toast_insets_test.dart` — PASS; evidence `106-focused.log/.json`.
- `fvm flutter test --no-pub --concurrency=6` — PASS; evidence `106-kurumi-qualified-v2.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos packages/kurumi/lib/src/components/toast.dart packages/kurumi/test/toast_test.dart test/application/bookmark_selection_keyboard_toast_test.dart` — PASS; evidence `106-analysis-final.log/.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS; evidence `106-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; evidence `106-full-final.log/.json`.

The complete runner includes application tests, every tested package/CLI and repository tooling. Default concurrency was 6 physical cores. Scoped analysis: 0 errors, 0 warnings, 1 informational findings (details in its log). The exact build command and source state are recorded above. No old handoff pass is substituted for this candidate.

## Device evidence and remaining acceptance

Real root Search and nested Bookmark operations with Selection Manager and keyboard were measured. At720x1600/DPR2, keyboard top 1002 px and manager surface top 774 px: baseline toast 630..742 px (56 dp) and final 646..742 px (48 dp), each retaining a 16 dp gap above the manager. Undo action remains 48 dp. The final normal five-second APK captured the combined state and the actual Undo tap succeeded; later group selection confirmed all 3 temporary items restored. All fixtures were then removed, and All Bookmarks returned to the original No data available state.

Duration-only 60-second QA builds were geometry aids, not final normal-build acceptance. The user's overlap remains un-reproduced on this device/current baseline; this commit fixes excess toast height and strengthens non-overlap coverage, not an invented inset root cause. Remaining manual acceptance: reproduce the user's exact device/navigation/IME combination, keyboard animation, selection dismissal, ordinary success and Undo behavior. Artifacts106-baseline-combined,106-baseline-search-combined,106-final-normal-combined,106-cleanup-empty-all preserve the evidence. The earlier interrupted106-full is not a pass;106-full-final is the complete pass.

## Integration and evidence limits

Individual branch verification does not verify a future combined develop candidate. That candidate needs the complete integration gate after any runtime/test/dependency changes.

Durable local logs, JSON provenance and private device evidence: `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`. Important development files were retained outside `/tmp`. GitHub claim metadata stayed local after automatic approval review rejected the attempted persistent issue comment under this local-only task; no comment was posted.

## Additional acceptance correction — exact develop sizing and keyboard frames

Restored the exact develop Undo action style: zero minimum size, shrink-wrapped tap target, original 8x4 dp button padding and 4 dp outer toast vertical padding. The earlier forced 48 dp target is removed. Multi-line/enlarged messages still grow naturally.

A new first-frame regression proves a real positioning defect concealed by the previous settle-only tests. After a native keyboard height change from 200 to 360 dp, the old toast bottom remained at 480 dp while the manager top moved to 336 dp (1x); at 2x the corresponding values were 465/321. The full obstruction notifier included the keyboard and was published after layout, lagging the already moved controls.

The navigation scope now publishes controls-only padding. Scoped toast overlays observe the native view's keyboard inset themselves during the current frame, while OKToast's separate keyboard displacement remains disabled, so the keyboard is counted once. Root and nested hosts, resizing Scaffold bodies, navigation/viewer obstructions and actual Undo callbacks retain their existing policies. No speculative fixed offset was added.

The strengthened production test checks first opening/closing frames, changing native keyboard heights and settled geometry while the same ordinary/Undo toast remains visible, at 1x/2x. Focused 10-test keyboard/action suite passed, extra first-frame 2-test suite passed, complete Kurumi 168 tests passed, scoped analysis has no errors/warnings and 3 informational findings. Full final regression and exact current-source device/build evidence are in the aggregate follow-up report.

Before the frame fix, the exact Search selection -> Remove From -> tap Search sequence on emulator-5554 showed a stable 16 dp gap and the restored compact action. That settled screenshot establishes only stable geometry; it does not negate the confirmed frame-transition failure. The original user-device steady-state overlap remains a separate acceptance limit unless reproduced on that device.

## Native safe-area refinement

Final test review found that the old keyboard fixture changed viewInsets but retained bottom padding while the keyboard was visible. Modeling the native transition (bottom padding zero while the docked keyboard is open, restored on close) exposed 18 dp first-frame overlap on closing at both scales: toast714/manager696 and699/681. The initial453bd candidate's complete pass therefore does not qualify this refinement.

Application-control padding now excludes the native safe area as well as the keyboard. The toast adds both native keyboard and current native padding directly in the same frame. This avoids their opposite changes being delivered through deferred control measurement. Popup geometry remains based on the existing full bottom-padding properties. The strengthened realistic production10-test suite and complete168-test Kurumi suite passed; scoped analysis has0 errors,0 warnings and4 informational findings. New complete qualification and final APK provenance are recorded in the follow-up report.

Device work used the earlier453bd normal APK before this safe-area refinement. Its native screenshots must not be described as final-candidate UI acceptance. The original APK/profile/data were restored and the lease released. The final refinement is verified through controlled native-metric tests; the originally affected device remains a manual acceptance check.
