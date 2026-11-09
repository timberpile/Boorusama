# Issue #162: shared timeline page prefetch handoff

- Issue: https://github.com/timberpile/Boorusama/issues/162
- Branch: `feature/162-unified-page-prefetch`
- Base implementation: #160, commit `2ad0873a0ed195c3db3d6f633818795afc3d58df`
- Published implementation: `84bf9697bf191497d0ae111d80eaf9dc3713a150`
- Related: #161 supplies correct Pixiv Explore continuation metadata; #160 is the independent thumbnail-cache change.

## Implementation

All shared `PostGrid` timelines use one `PostGridPrefetch` owned by the grid instead of the optional scroll-to-top button. The Pixiv Favorites `prefetchOnLayout` opt-in and legacy `InfiniteScrollListener` branch in `PostGrid` are removed. This preserves the existing two-viewport threshold, with a bounded three-page continuation cycle to fill short or empty layouts. Scrolling and refresh renew the budget; layout/viewport notifications alone do not.

The host checks destination activity, route, foreground lifecycle, attachment, pagination mode, errors, exhaustion, and scroll metrics. `PostGridController.fetchMore` accepts a `canStart` check re-evaluated at dispatch after debounce; an explicit/manual call can promote a pending automatic request without inheriting its stale guard. No network request already in flight is cancelled by this mechanism.

The cached Following feed's independent last-100-items trigger was removed. History-start state is set when a real history page is requested, including shared prefetch and manual continuation. Site-specific cursors, feed source rules, profile/auth isolation, and separate artist/pool pagination remain out of scope.

## Tests added or changed

- `test/core/posts/listing/post_grid_prefetch_test.dart` covers two-viewport triggers, coalescing, short/empty page bounds, failures, retry, refresh, paginated mode, inactive routes, foreground/background, viewport resize, disposal, and explicit promotion.
- `test/core/posts/listing/post_grid_prefetch_wiring_test.dart` covers a single host with and without a scroll-to-top control.
- `test/boorus/pixiv_favorites_page_lifetime_test.dart` checks sequential automatic continuation across empty Pixiv Favorites pages.

## Verification performed and limitations

Every affected code/test file was checked against the prepared Git blob object after importing onto a real GitHub commit ancestry. The original isolated patch workspace passed `git diff --check` and a combined patch-import check.

**Not run:** FVM format, analyzer, Flutter tests, full local regression, Android/Maestro, and independent review. This broad shared-controller change is **not** integration-ready. Keep the issue open.

## Required verification

Read current `AGENTS.md`, inspect affected consumers and use an isolated worktree. First format, analyze, and run relevant tests:

```sh
fvm dart format lib/core/posts/listing/src/widgets/post_grid.dart lib/core/posts/listing/src/widgets/post_grid_controller.dart lib/core/posts/listing/src/widgets/post_grid_prefetch.dart lib/core/search/following_topics/src/pages/topic_feeds_page.dart lib/boorus/pixiv/favorites/page.dart test/core/posts/listing/post_grid_prefetch_test.dart test/core/posts/listing/post_grid_prefetch_wiring_test.dart test/boorus/pixiv_favorites_page_lifetime_test.dart
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub "--concurrency=$workers" test/core/posts/listing test/boorus/pixiv_favorites_page_lifetime_test.dart test/boorus/pixiv_favorites_session_test.dart test/core/search/following_topics test/application
```

Audit other `PostGrid` consumers, `fetchMore` callers, and retained legacy flags before acceptance. Inspect the Following history dispatch lifecycle. Verify #161 + #162 combined for Pixiv Explore filtered/empty pages. Use the documented emulator lease and Maestro to test background/resume, inactive tabs, route changes during debounce, short pages, failures and retries, keyboard/resize, and Pixiv cursor correctness.

Commission an **independent review agent** with issue requirements, the actual branch diffs and verification evidence. Fix all valid findings on the owning branch and rerun affected checks; request re-review where substantive. Before any integration to `develop`, run `./scripts/run_regression_tests.sh` on the final combined candidate. No PR or merge without explicit approval.
