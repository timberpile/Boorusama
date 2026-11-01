# Local acceptance corrections — Issue #118

## Scope and commits

Branch: `feature/118-pixiv-following-artists`. Initial commit: `20ad8c537b6014b61c0fd0a0bed797a97d4519c5`. Final runtime/test candidate: `e1105e8c1df5911cacd68984220eccd8fa8877a8`. This report is a subsequent documentation-only commit; its final HEAD is listed in the aggregate handoff. The complete regression below checked this exact candidate; report-only updates do not change it.

Local corrections only. No push, merge, PR, issue closure or branch deletion was authorized or performed.

## Changes and diagnosis

Replaced the fixed privacy Column/ListView split with one CustomScrollView containing the shared #114 TimelineHeaderSliver and artist SliverList. Loading/error content uses slivers while refresh/retry and manual continuation remain available. Privacy/account isolation, card navigation and read-only behavior remain. Refresh explicitly awaits the provider future.

The production long-list test uses 60 artists, scrolls down repeatedly and reverses 40 px, then switches privacy and checks isolation and request counts. There is no Pixiv-specific scroll-direction listener.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/boorus/pixiv_following_page_navigation_test.dart test/boorus/pixiv_following_provider_test.dart test/boorus/pixiv_following_artist_card_test.dart test/boorus/pixiv_following_presentation_test.dart` — PASS; evidence `118-focused-qualified.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/pixiv/following/page.dart lib/core/posts/listing/src/widgets/timeline_header_sliver.dart test/boorus/pixiv_following_page_navigation_test.dart` — PASS; evidence `118-analysis-final.log/.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS; evidence `118-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; evidence `118-full-final.log/.json`.

The complete runner includes application tests, every tested package/CLI and repository tooling. Default concurrency was 6 physical cores. Scoped analysis: 0 errors, 0 warnings, 4 informational findings (details in its log). The exact build command and source state are recorded above. No old handoff pass is substituted for this candidate.

## Device evidence and remaining acceptance

Normal exact-source APK on emulator-5554 rendered the signed-in public artist list and exercised Public/Private selection. The live account contains only one public artist, so it cannot establish long-list hiding/reveal. The 60-artist production-style test is the long-list evidence.

Manual review: a populated Public and Private list; repeated down/slight-up cycles; privacy switches while scrolled; artist-card navigation/back; manual continuation, refresh, empty/error/retry. No remote follow/unfollow action was performed.

## Integration and evidence limits

The shared TimelineHeaderSliver is byte-equivalent to #114 commit `121c619b`; this branch contains that source rather than a separate direction-listener implementation. Individual branch verification does not verify a future combined develop candidate. That candidate needs the complete integration gate after any runtime/test/dependency changes.

Durable local logs, JSON provenance and private device evidence: `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`. Important development files were retained outside `/tmp`. GitHub claim metadata stayed local after automatic approval review rejected the attempted persistent issue comment under this local-only task; no comment was posted.

## Additional acceptance correction

Public/Private now uses its original scrolling list position and stays hidden on upward scrolling away from the beginning. Returning to offset zero restores the selector after both privacy switches. Refresh, retry, account isolation and read-only artist routing remain.

Focused final correction suite: 16 tests passed. The updated production long-list test asserts that slight upward scrolling does not reveal the selector and that returning to the top does. Complete final-candidate regression results are recorded in the aggregate follow-up report. No integration is authorized for this branch.

## Accepted layout refinement — 2026-11-01

Replace the privacy popup with the same horizontal Kurumi Public/Private segmented control used by Explore, retaining top-only visibility. Production tests verify both buttons share a row, direct privacy switching, scroll behavior, stale/account isolation and routing. Following suites: 16 passed; scoped analysis: no findings.

The aggregate `acceptance-layout-20261101` handoff records exact final commits and verification results. Previous complete passes predate these layout refinements. Changes remain local for review; no integration is authorized for this branch.

## Near-end automatic artist pagination — 2026-11-01

The page now owns a ScrollController and composes the existing InfiniteScrollListener. Scrolling within two viewport lengths of the end starts the next offset request. Each event reads current provider state, so loading, refresh, failure and exhaustion suppress automatic continuation even before a pending rebuild. Existing provider coalescing, offset validation, cancellation and stale-result handling are retained.

Manual Load More remains available, including short pages that do not require scrolling. A failed continuation stops automatic attempts until explicit Retry; that retry keeps the same offset. Public/Private buttons retain their top-only visibility and account/privacy changes cancel pending automatic requests.

The controlled production-page regression fails before the trigger is wired (`118-autoload-before-v2`). The final five-file suite passes 21 tests (`118-autoload-final`), covering near-end lead distance, repeated scroll events during a held request, failure/manual retry, exhaustion, short-page manual continuation, privacy/account cancellation, stale responses and existing narrow/enlarged/keyboard navigation. Analysis of the final source/test scope reports no findings (`118-autoload-analysis`). Changed Dart files were formatted with FVM.

Exact final commit and commands are recorded in the aggregate `accepted-integration-114-107-117-20261101` handoff. This is scoped local verification, without a new APK, device or live-account session. A later develop integration needs its complete combined-candidate gate. No #118 push or merge is authorized by this follow-up.
