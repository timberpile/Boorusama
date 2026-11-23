# Local acceptance corrections — Issue #117

## Scope and commits

Branch: `feature/117-pixiv-favorites`. Initial commit: `70c66d41042bdc6a2ddf01545acf6df2fb2da4c8`. Final runtime/test candidate: `0d96a770f480f5766af68c890691fbdc5151a57a`. This report is a subsequent documentation-only commit; its final HEAD is listed in the aggregate handoff. The complete regression below checked this exact candidate; report-only updates do not change it.

Local corrections only. No push, merge, PR, issue closure or branch deletion was authorized or performed.

## Changes and diagnosis

Public/Private and ordinary grid controls share #114's floating header. A Favorites-only PostGrid prefetch host starts sequential cursor requests within two viewports of the end and after layout of short nonempty pages. Layout-only continuation is capped at three extra requests per cycle; refresh/user scrolling permits another cycle. Loading, errors, cancellation, exhaustion and empty initial results stop automatic continuation; manual Load More stays available. Other consumers retain their existing listener by default.

The ahead-layout image range is one viewport, capped at 1200 logical pixels, and uses the ordinary image widgets, authenticated Pixiv headers, quality settings, caching and request coordination. No bulk download of every fetched thumbnail is introduced. Production-style tests measure actual media request starts from the controlled client before offscreen tiles become visible, and cover short-page budgets, manual continuation, cursor retry, privacy/account changes, refresh and cancellation.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv_favorites_page_lifetime_test.dart test/boorus/pixiv_favorites_session_test.dart test/boorus/pixiv_auth_origin_test.dart test/core/posts/infinite_scroll_listener_test.dart` — PASS; evidence `117-focused-qualified.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/pixiv/favorites/page.dart lib/core/posts/listing/src/widgets/post_grid.dart lib/core/posts/listing/src/widgets/post_grid_prefetch.dart lib/core/posts/listing/src/widgets/timeline_header_sliver.dart test/boorus/pixiv_favorites_page_lifetime_test.dart` — PASS; evidence `117-analysis-final.log/.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS; evidence `117-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; evidence `117-full.log/.json`.

The complete runner includes application tests, every tested package/CLI and repository tooling. Default concurrency was 6 physical cores. Scoped analysis: 0 errors, 0 warnings, 8 informational findings (details in its log). The exact build command and source state are recorded above. No old handoff pass is substituted for this candidate.

## Device evidence and remaining acceptance

Normal exact-source APK on emulator-5554: signed-in Public has 2 posts; Private has 0. Privacy switching, decoded images and viewer return passed. Actual HTTP profiler capture: public Favorites GET started 1793460282015095 us, completed 1793460283957765 us, HTTP 200, elapsed 1942.670 ms. Headers, credentials, full private URLs and payloads were never logged. Both images were cached, so no pximg network requests occurred.

Remaining live acceptance: a genuinely populated account is required for long-scroll hide/reveal, cursor lead time, fast-scroll and cold-thumbnail request/image/scroll latency. The current account cannot establish those behaviors and no remote favorites were created. Controlled 28-test coverage proves the implemented bounds and request starts, not a live latency benchmark. Review quality changes/cache reuse and cancellation while switching account/privacy on a populated account.

## Integration and evidence limits

The shared TimelineHeaderSliver is byte-equivalent to #114 commit `121c619b`; this branch contains that source rather than a separate direction-listener implementation. Individual branch verification does not verify a future combined develop candidate. That candidate needs the complete integration gate after any runtime/test/dependency changes.

Durable local logs, JSON provenance and private device evidence: `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`. Important development files were retained outside `/tmp`. GitHub claim metadata stayed local after automatic approval review rejected the attempted persistent issue comment under this local-only task; no comment was posted.

## Additional acceptance correction

Public/Private now uses its original scrolling list position and stays hidden on upward scrolling away from the beginning. The existing floating titlebar is unchanged and tracked separately in GitHub #131. Favorites-only bounded cursor prefetch and its image cache extent remain; ordinary Pixiv Explore does not opt into them.

Focused final correction suite: 15 tests passed. The updated production long-list test asserts that slight upward scrolling does not reveal the selector and that returning to the top does. Complete final-candidate regression results are recorded in the aggregate follow-up report. No integration is authorized for this branch.

The privacy selector is a separate ordinary scrolling sliver. The post count/grid-configuration toolbar retains its existing floating reveal; the final focused test asserts both hidden privacy and revealed post controls after the same slight upward scroll. This keeps the correction scoped to Public/Private. Final split-toolbar focused suite: 15 passed.

## Final regression follow-up: cancelled share cleanup

The complete `117-full-final` run on `ba5444bfe90a8cfd66515481ba809e5a46407908` failed the existing cancelled-download regression. Dio's cancellation future can finish before its asynchronous partial-file deletion. Our separate existence check and deletion could then race Dio, replacing the cancellation result with `PathNotFoundException`.

A deterministic regression reproduces that replacement error before the fix (`117-cancel-cleanup-repro-v2`). Cleanup now attempts deletion directly and tolerates only `PathNotFoundException`; unrelated storage failures remain visible. This additional sharing correction is included because the complete branch gate exposed it. All 20 related sharing/cache tests pass (`117-share-cleanup-fixed`), and analysis of the two affected files reports no issues (`117-sharing-analysis`).

Earlier complete passes above predate the current correction and do not qualify this candidate. The aggregate acceptance-followup handoff records the exact final commit and the new complete `117-full-qualified` result. Current UI analysis has 0 errors, 0 warnings and 2 informational findings; the additional sharing scope has none. No new live Pixiv or device claim is made by this follow-up.

## Accepted layout refinement — 2026-11-01

Replace the privacy popup with the same horizontal Kurumi Public/Private segmented control used by Explore. Both privacy controls and titlebar contents stay at their original top-of-list positions; slight upward scrolling does not reveal either. Ordinary post count/grid controls retain their existing floating behavior. Preserve bounded Favorites prefetch, account/cursor isolation and cancelled-share cleanup. Updated production long-list, layout and privacy tests: 26 passed, including 320 dp/enlarged/keyboard; scoped analysis: 0 errors, 0 warnings, 1 informational finding.

The aggregate `acceptance-layout-20261101` handoff records exact final commits and verification results. Previous complete passes predate these layout refinements. Changes remain local for review; no integration is authorized for this branch.
