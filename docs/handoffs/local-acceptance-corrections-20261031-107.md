# Local acceptance corrections — Issue #107

## Scope and commits

Branch: `feature/107-local-post-sorting`. Initial commit: `b0daf86e500e514552f9eb022458aa413a009500`. Final runtime/test candidate: `b740042a2430a86d21e25b5d6879e23b3436cd6c`. This report is a subsequent documentation-only commit; its final HEAD is listed in the aggregate handoff. The complete regression below checked this exact candidate; report-only updates do not change it.

Local corrections only. No push, merge, PR, issue closure or branch deletion was authorized or performed.

## Changes and diagnosis

Implemented accepted Variant A: cached search and chips in the first compact row; a single composable second row contains source/sort, active Cached indicator and timeline actions. The search/filter container uses themed surfaceContainer. Cached appears only for a committed local query/source/nondefault sort; the History badge is removed. The AppBar shows a compact relative successful-check time with the full date exposed by DateTooltip; the permanent Last checked row is removed. Meaningful progress/errors remain. The duplicate default Feed grid header is omitted; Newest, remote History behavior and cached-only request isolation remain.

The same shared floating-header correction from #114 is included verbatim; existing combined Bookmark controls consume it. Tests cover production two-row geometry, narrow/enlarged text, keyboard, draft/commit/reset, source ghosts and remote-request isolation. The full pass also includes `bookmark_timeline_toolbar_flow_test.dart`: 100 actual Bookmark posts, 1x/2x, 800px down / 32px up, both search and filters returning together while still far from the top, plus keyboard focus.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/core/search/following_topics/cached_feed_sort_history_test.dart test/core/search/following_topics/cached_feed_filter_bar_test.dart test/core/search/following_topics/topic_feed_initialization_test.dart test/core/search/following_topics/topic_feed_info_dialog_test.dart` — PASS; evidence `107-layout-final.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/core/posts/listing/src/widgets/timeline_header_sliver.dart lib/core/search/following_topics/src/pages/topic_feeds_page.dart lib/core/search/following_topics/src/widgets/cached_feed_filter_bar.dart lib/core/search/following_topics/src/widgets/feed_last_checked.dart test/core/search/following_topics/cached_feed_filter_bar_test.dart test/core/search/following_topics/cached_feed_sort_history_test.dart test/core/search/following_topics/topic_feed_info_dialog_test.dart test/core/search/following_topics/topic_feed_initialization_test.dart test/core/search/following_topics/topic_feed_test.dart` — PASS; evidence `107-analysis.log/.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS; evidence `107-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; evidence `107-full.log/.json`.

The complete runner includes application tests, every tested package/CLI and repository tooling. Default concurrency was 6 physical cores. Scoped analysis: 0 errors, 0 warnings, 8 informational findings (details in its log). The exact build command and source state are recorded above. No old handoff pass is substituted for this candidate.

## Device evidence and remaining acceptance

Normal exact-source APK on emulator-5554: empty and populated folder Feed verified using temporary local fixtures. Both rows rendered on a themed surface; no History badge or permanent Last checked row appeared. AppBar displayed a relative time with full timestamp accessibility text. Three downward scrolls hid the complete controls; an 80px / 40dp upward movement restored them below the AppBar. Committing 1girl displayed its chip and Cached; Remove All Selected Tags removed Cached. The temporary topic/folder were removed afterward. Automated layout/request evidence applies to this exact runtime/test commit. Manual review: populated and empty Feed, both rows, long source names, keyboard focus and clear/reset, active Cached appearance, compact timestamp/full tooltip, slight-up reveal of the complete Feed and Bookmark controls, refresh errors/rate limits, and remote History only when cached-only projection is inactive.

## Integration and evidence limits

The shared TimelineHeaderSliver is byte-equivalent to #114 commit `121c619b`; this branch contains that source rather than a separate direction-listener implementation. Individual branch verification does not verify a future combined develop candidate. That candidate needs the complete integration gate after any runtime/test/dependency changes.

Durable local logs, JSON provenance and private device evidence: `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`. Important development files were retained outside `/tmp`. GitHub claim metadata stayed local after automatic approval review rejected the attempted persistent issue comment under this local-only task; no comment was posted.

## Additional acceptance corrections

The flat Feed filter bar shares the titlebar/overflow dark translucent surface. Removed the lighter outer panel, rounded outer corners and margins below the titlebar. Cached appears only for committed local filtering/source/sort and now explains its local-only behavior in a localized tooltip. The compact successful-check stamp uses a clock icon and one-letter age (for example 7h); future clock skew clamps to zero. Full date tooltip and readable accessibility wording remain, as does minute-pulse updating. English and German labels are supplied; other locales retain normal translation fallback.

Final focused correction tests: 42 passed (cached controls, successful-check ages, Bookmark scroll/keyboard). Scoped analysis: no errors or warnings, 8 informational findings. Complete final regression is recorded in the follow-up report. This branch remains local and is not approved for integration.

## Accepted layout refinement — 2026-11-01

The AppBar last-check stamp now shrinks to its content and aligns right directly beside overflow, removing the expanding centered 112 dp action box. The cached filter row explicitly uses zero outer vertical padding. Shared TimelineToolbar default spacing matches #114 at 2 dp per side; all touch/control minima remain. Updated production tests verify the stamp-to-overflow gap and the narrow/enlarged/keyboard filter geometry. Focused Feed suite: 43 passed; scoped analysis: 0 errors, 0 warnings, 5 informational findings.

The aggregate `acceptance-layout-20261101` handoff records exact final commits and verification results. Previous complete passes predate these layout refinements. Changes remain local for review; no integration is authorized for this branch.
