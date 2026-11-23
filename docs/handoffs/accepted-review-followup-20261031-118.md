# Accepted review follow-up handoff — #118

Prepared 2026-10-31. Branch `feature/118-pixiv-following-artists`.

Verified implementation/test candidate: `31f9455184c43aa30222d4a440aef12f3ff9fee0`. The final handoff commit changes documentation only; the separate final branch index records that exact resulting HEAD.
Merge base with local develop: `422aeae087c1108e655d85d1a3dac25120456cd6`. Local develop remained `de5928283aa39f0d67d6a834e42d4fa5e9369b86`; primary checkout remained detached at `405ef9ee9c7f0821d3601866373884015c5323f5`.
State: prepared for user review; acceptance and integration remain pending.

## Result and review

Pixiv Following consumes the shared compact timeline selector with Public/Private options. Navigation says Following within Pixiv; the page says Pixiv Following and removes the redundant profile subtitle. Read-only artist cards, supplied previews and user Search routing remain.

Reviewed account/privacy request ownership, pending responses, offset reset, bounded supplied previews and artist navigation. No follow/unfollow writes, unsupported All option or extra preview fetching were added.

Shared controls originate at #114 commit 8be01654ebf69fbea50c3773d8f8f00b2beadaf2, cherry-picked here as 085ce5f63e13b2ebb41172dc4e165690fa9cac8e.

## Verification

- Complete local gate: `./scripts/run_regression_tests.sh` — PASS, 1159.5 s, exact candidate `31f9455184c43aa30222d4a440aef12f3ff9fee0`. Application, every local package/CLI, both shell suites and Python tooling ran; two existing go_router skips remain.
- Android build: `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS, 122.6 s, build commit `31f9455184c43aa30222d4a440aef12f3ff9fee0`.
- Non-runtime changes after that build: none.
- Scoped final analysis: `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/navigation_capabilities.dart lib/boorus/pixiv/following/l10n.dart lib/boorus/pixiv/following/page.dart lib/core/bookmarks/src/widgets/bookmark_option_selector.dart lib/core/posts/listing/src/widgets/timeline_option_selector.dart lib/core/posts/listing/src/widgets/timeline_toolbar.dart test/boorus/pixiv_following_page_navigation_test.dart test/core/navigation/engine_navigation_capabilities_test.dart test/core/posts/listing/timeline_controls_test.dart` — PASS: 0 errors, 0 warnings, 1 informational findings. Informational findings are not described as lint-clean.
- Changed Dart files formatted with FVM. `git diff --check 422aeae087c1108e655d85d1a3dac25120456cd6 31f9455184c43aa30222d4a440aef12f3ff9fee0` passed.
- Focused evidence `focused-final`: `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv_following_page_navigation_test.dart test/boorus/pixiv_following_provider_test.dart test/boorus/pixiv_following_presentation_test.dart test/boorus/pixiv_following_artist_card_test.dart test/core/posts/listing/timeline_controls_test.dart test/core/search/following_topics/cached_feed_filter_bar_test.dart test/core/navigation/engine_navigation_capabilities_test.dart` — PASS (51.1 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.
- Focused evidence `navigation-final`: `fvm flutter test --no-pub --concurrency=6 test/core/navigation/engine_navigation_capabilities_test.dart test/boorus/pixiv_following_page_navigation_test.dart` — PASS (44.5 s). Earlier dirty-state focused runs are superseded by the complete clean committed-candidate pass above.

Raw command, HEAD, tracked diff, exit status and elapsed time are stored in `<primary checkout>/.worktrees/_artifacts/accepted-review-followup-20261031/118-pixiv-following-artists/` as phase `.json`/`.log` pairs. Interrupted/superseded/failing earlier runs are retained and are not counted as final passes. Native VM finalizer diagnostics occur in some passing Flutter tests; they are reported separately from exit status. Existing native-hook “File modified during build” and Android toolchain support notices also remain; no unrelated toolchain upgrade was introduced.

## Actual Android checks and limits

Device: `emulator-5554`, exclusively leased and controlled with Maestro. Installed normal APK SHA-256: `a95d0290c448279d77fef01565c4928a29734ff2e2a6872b9f27b9dcc3c7a128`.

Live Public rendered an artist card and user routing worked; Private was empty. Only one configured account was exercised live. Multi-account, pending-request, pagination and error isolation are controlled production-test coverage.

Detailed actual observations and provenance are retained in `118-device-observations.json`.

Task fixtures and settings were restored: task-created local groups/posts/topic/feed were removed, settings restored, the original device APK reinstalled with matching installed APK hash, original Safebooru (Danbooru) profile selected and lease released. No remote account mutations or recipient sends occurred. Share/copy checks changed the clipboard and ordinary QA searches remain in local search history; existing history was not cleared.

## User review checklist

1. Open Menu > Pixiv > Following: title Pixiv Following, no profile subtitle; global Following Topics remains distinct.
2. Switch Public/Private, including while loading. Scroll a populated account; change accounts and check that old results never appear.
3. Tap an artist and return: user Search and privacy state must be correct.

## Delivery boundary

All task changes are committed locally. No PR, push, develop integration, issue closure, branch/worktree deletion or release was performed. This isolated branch pass does not prove a later combined develop candidate; merging sibling changes or rebasing runtime code requires verification of that resulting candidate. User acceptance is still outstanding.

## Correction commits

The prior branch implementation is retained except for the accepted corrections described above. These are the correction checkpoints since the starting handoff:

```text
31f9455184c43aa30222d4a440aef12f3ff9fee0 fix: align Pixiv Following controls and navigation labels (#118)
085ce5f63e13b2ebb41172dc4e165690fa9cac8e refactor: share composable timeline controls (#114)
```
