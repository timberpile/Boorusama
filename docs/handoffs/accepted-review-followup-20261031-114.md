# Accepted review follow-up handoff — #114

Prepared 2026-10-31. Branch `feature/114-timeline-toolbar`.

Verified implementation/test candidate: `caa1ec196d748f2091b24a6bfd7511716dd4472c`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Visible settings text and settings-search catalog use the localized Keep Timeline Toolbar Visible / Timeline-Leiste sichtbar halten label. Default off means hide on down-scroll and reveal on a small reverse scroll away from the top; on pins the relevant toolbar. The shared header is transparent and keeps a stable measured render child through empty/error recovery.

Reviewed legacy settings/backup meaning, localized destination discovery, transparent rendering, sliver geometry and loading/error transitions. The shared TimelineToolbar/TimelineOptionSelector extraction remains presentation-only.

Owns common controls at 8be01654ebf69fbea50c3773d8f8f00b2beadaf2. #117/#118/#107 carry equivalent scoped prerequisites; integrate the shared changes once and resolve equivalent commits carefully.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1056.2 s, exact candidate `caa1ec196d748f2091b24a6bfd7511716dd4472c`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 53.5 s, build commit `caa1ec196d748f2091b24a6bfd7511716dd4472c`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks/src/widgets/bookmark_option_selector.dart lib/core/posts/listing/src/widgets/post_list_configuration_header.dart lib/core/posts/listing/src/widgets/timeline_header_sliver.dart lib/core/posts/listing/src/widgets/timeline_option_selector.dart lib/core/posts/listing/src/widgets/timeline_toolbar.dart lib/core/settings/src/search/settings_search_catalog.dart test/core/posts/listing/timeline_controls_test.dart test/core/posts/listing/timeline_header_sliver_test.dart test/core/settings/settings_search_catalog_test.dart` — PASS: 0 errors, 0 warnings, 4 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 caa1ec196d748f2091b24a6bfd7511716dd4472c` passed.
- Focused evidence `focused-final`: `fvm flutter test --no-pub --concurrency=6 test/core/posts/listing/timeline_controls_test.dart test/core/posts/listing/timeline_header_sliver_test.dart test/core/posts/listing/timeline_toolbar_widget_test.dart test/core/settings/settings_search_catalog_test.dart test/core/settings/settings_search_pane_test.dart test/core/settings/timeline_toolbar_settings_test.dart test/core/search/following_topics/cached_feed_filter_bar_test.dart` — PASS (80.1 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `network-recovery-fix`: `fvm flutter test --no-pub --concurrency=6 test/application/network_recovery_flow_test.dart test/core/posts/listing/timeline_header_sliver_test.dart` — PASS (36.3 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/114-timeline-toolbar/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `07623e3d69169b1b9d1b0337960185e3e5cbaa4faec5b51a53428a2edba791cc`.

Actual English/German settings-search navigation, persistence across restart and on/off scroll behavior passed on device. English and the original off setting were restored.

Detailed actual observations and provenance are retained in `114-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Search the exact English and German setting labels and open the real switch. Toggle on, restart and verify persistence.
2. With off: scroll down on a long timeline, then slightly upward away from top. With on: toolbar stays visible.
3. Check both themes, narrow width, enlarged text, empty/error recovery and selection.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
caa1ec196d748f2091b24a6bfd7511716dd4472c fix: retain floating toolbar layout across recovery (#114)
3ec0b0ccce07b5c4c0f0d177767173498db58eab fix: discover and render the floating timeline toolbar (#114)
8be01654ebf69fbea50c3773d8f8f00b2beadaf2 refactor: share composable timeline controls (#114)
```
