# Accepted review follow-up handoff — #117

Prepared 2026-10-31. Branch `feature/117-pixiv-favorites`.

Verified implementation/test candidate: `8401736a88e9cba34909b9c5b10dea4cc45c6afa`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Pixiv Favorites contributes Public/Private controls through the shared composable timeline toolbar and Bookmark-style selector. Shared Favorites navigation/profile picking and existing authentication/session/cursor behavior are retained.

Reviewed token verification/refresh, profile and account keys, stale response ownership, duplicate/cursor handling, read-only service calls and existing Bookmark selector consumers. Privacy controls have no unsupported sorting or All mode.

Shared #114 controls 8be01654ebf69fbea50c3773d8f8f00b2beadaf2 are cherry-picked here as 9682ae9d7a8da5dd3a96520c74d7a505cf7d17f6.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1050.7 s, exact candidate `8401736a88e9cba34909b9c5b10dea4cc45c6afa`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 181.5 s, build commit `8401736a88e9cba34909b9c5b10dea4cc45c6afa`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/pixiv/favorites/page.dart lib/core/bookmarks/src/widgets/bookmark_option_selector.dart lib/core/posts/listing/src/widgets/timeline_option_selector.dart lib/core/posts/listing/src/widgets/timeline_toolbar.dart test/boorus/pixiv_favorites_page_lifetime_test.dart test/core/posts/listing/timeline_controls_test.dart` — PASS: 0 errors, 0 warnings, 2 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 8401736a88e9cba34909b9c5b10dea4cc45c6afa` passed.
- Focused evidence `focused-final-v3`: `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv_favorites_session_test.dart test/boorus/pixiv_favorites_page_lifetime_test.dart test/core/posts/listing/timeline_controls_test.dart test/core/search/following_topics/cached_feed_filter_bar_test.dart` — PASS (56.7 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/117-pixiv-favorites/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `cee5a191a1942afafec8c326d657f17296db05769098ee318684088c0032241f`.

Live configured account Public/Private/Public passed; Private was empty and could not prove live cursor pagination. Account switching, pending responses, token/session and pagination safeguards are covered by controlled tests.

Detailed actual observations and provenance are retained in `117-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Open Favorites and choose Pixiv. Compare the compact Public/Private popup with Bookmarks.
2. Switch privacy while loading and paginate a populated view: no duplicates, stale pages or cross-account results.
3. Exercise verified/manual token state, refresh, empty/error recovery and viewer return.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
8401736a88e9cba34909b9c5b10dea4cc45c6afa fix: reuse timeline privacy selector in Pixiv Favorites (#117)
9682ae9d7a8da5dd3a96520c74d7a505cf7d17f6 refactor: share composable timeline controls (#114)
```
