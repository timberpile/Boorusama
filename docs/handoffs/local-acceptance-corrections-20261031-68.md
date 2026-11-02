# Local acceptance corrections — Issue #68

## Scope and exact commits

Branch: `feature/group-neighboring-series`. Initial local commit: `d22b61f6bed5287d10cc8be63df6a7adab87fdc4` (the earlier reviewed origin was `8cdacc39e384f75d5f6d20a01451d3466912f48c`). Runtime, behavior tests and design reconciliation: `3f698fc2ce709696a7b9a785f34543201dc43838`. Final fully checked candidate: `0223414b39994e443fb0e780f584c1f3f4553bfd`; its only additional change repairs a real-I/O test cleanup race. The later documentation-only HEAD is listed in the aggregate report.

No push, merge, PR, issue closure or branch deletion. Related Posts grouping remains excluded.

## Diagnosis and correction

Read-only live `malberrybush` capture retained 120 raw posts and their ordered membership metadata. Duplicate 12398273 is raw index 16 and has no Series. Kinktober 2026 / Series 32092 contains all 29 members across raw indices 0..34, with unrelated results at 16..19 and 32..33. Later Bonktober69 / Series 27096 contains all 18 members across 91..110. Many intervening posts have no Series; the leading 29 card already represents its full Series, so neither the duplicate nor the unrelated gap justifies extending the five-result window.

The three bounded 40-ID membership requests returned 1, 0, 2 pool records (one was a collection and excluded); no 100-pool response truncation was observed. Source/profile, raw IDs/indices, confirmed membership and lookup results are retained in68-live-posts.json,68-live-pools.json and68-live-membership.json.

The verified failure is metadata admission before projection freeze. With the captured 120-post fixture and a deliberately held tail response, the old 40-post page admission freezes the later group at 15/18. The old-source reproduction fails exactly that expectation (`68-old-held-tail-repro`, not the earlier immediate probes which did not reproduce). Supported search-page metadata is now admitted before the controller exposes that page; the corrected held-response production test passes with 18/18. This resolves incomplete admission without changing rolling five-result semantics or allowing frozen tiles to reorder visibly.

`SearchSeriesIndex.loadPage` caps input at the supported 200-post page size and divides it into existing 40-ID admissions: at most 5 requests, or 2 for the default 60-post page. Requests run concurrently through the ordinary source capability and share the existing 10-second per-admission wait rather than accumulating serial waits. Pending requests coalesce, source/profile isolation and 512-entry cache remain, and unavailable metadata leaves raw posts visible/retryable. This deliberately adds a second default-page metadata lookup before first rendering; slow metadata can delay initial loading up to the bounded timeout. No claim of zero added latency is made. This trades bounded loading time for complete initial admission and stable rendering; there is no full-Series crawl or uncontrolled viewport request fan-out.

Artist Posts Newest and Popular now share the same route-owned index and SearchSeriesGrid presentation. Artist headers, sorting, profile context, raw selection, first-member thumbnail, partial X/total counts, full-Series navigation and bounded automatic pagination remain. Ordinary Bookmarks, explicit collection searches, cover quality, persistence and backup/import behavior are preserved by focused regressions. Both design documents were reconciled with Search plus Artist scope and page admission.

## Regression gate repair

The first complete run failed an existing Settings keyboard-focus check; an isolated retry subsequently passed without a behavioral change. A second run exposed a separate retry-test fixture defect: a one-second real Hive-open deadline can expire under load before the test captures its notifier. Its finally block then deletes the directory while the async owner is still opening/closing, producing a missing lock-file error. Commit 0223414 captures the rebuilt notifier before awaiting open, awaits its disposal in finally and uses a generous 30-second hang guard. Retry, creation, persistence and closure assertions are unchanged. No production repository behavior was changed to satisfy this test.

The stopped/failed runs remain recorded and are not passes. `68-full-qualified` passed the clean final candidate in 558.531s, including application, every tested package/CLI and repository tooling, at normal concurrency 6. No diagnostic print remained in the keyboard driver.

## Executed checks

- `fvm flutter test --no-pub --concurrency=6 test/application/pool_bookmark_flow_test.dart test/core/posts/listing/search_series_index_test.dart test/core/posts/listing/neighboring_series_test.dart test/boorus/danbooru_artist_page_test.dart test/core/bookmarks/pool_bookmark_persistence_test.dart test/core/bookmarks/pool_bookmark_source_policy_test.dart test/core/bookmarks/pool_bookmark_refresh_failure_test.dart` — PASS; `68-focused-final.log/.json`.
- `fvm flutter test --no-pub --concurrency=6 test/core/search/following_topics/following_topic_provider_test.dart` — PASS; `68-provider-lifecycle.log/.json`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib/boorus/danbooru/artists/artist/src/pages/artist_page.dart lib/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart lib/boorus/danbooru/posts/search/src/danbooru_search_page.dart test/application/pool_bookmark_flow_test.dart test/boorus/danbooru_artist_page_test.dart test/core/posts/listing/search_series_index_test.dart` — PASS; `68-analysis.log/.json`.
- `fvm flutter analyze --no-pub test/core/search/following_topics/following_topic_provider_test.dart` — PASS; `68-lifecycle-analysis.log/.json`.
- `fvm flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json --no-pub` — PASS; `68-build.log/.json`.
- `./scripts/run_regression_tests.sh` — PASS; `68-full-qualified.log/.json`.

Focused behavior/compatibility suite: 83 passed. Provider lifecycle suite: 4 passed. Runtime scoped analysis: 0 errors, 0 warnings, 18 informational findings; the additional lifecycle-test analysis found no issues. The normal APK was built from 3f698fc; 0223414 changes only the test fixture, so its runtime is byte-equivalent. Source state/build hashes are retained in68-build.json and68-final-normal-apk.json.

## Live acceptance and remaining review

Normal APK on emulator-5554, signed-in Danbooru profile: live Search displayed the leading Series 29 and the later Series 18. Opening the latter loaded the full 18-post Series. Artist Newest displayed Series 29; Artist Popular displayed Kinktober 2023 as Series 2/31. Long pressing that displayed group selected one raw post and removed the grouped tile during selection; Close exited selection. No Favorite/Bookmark/download mutation was invoked. Evidence:68-live-search-leading 29,68-live-search-later18,68-live-full-series18,68-live-artist-newest,68-live-artist-popular-series2of31,68-live-artist-raw-selection screenshots.

Review `malberrybush` again on the intended account/profile, including later pages and sort switches, partial counts, raw selection and full-Series navigation. Very slow/failed membership requests should leave ordinary posts usable; controlled tests cover held responses and bounded continuation. Live service contents can change from the captured 2026-10-31 fixture. Device work did not measure a controlled Search latency distribution; the bounded wait/request impact above is a source-level finding.

This correction does not introduce a new #114 dependency beyond the existing baseline. A future combined develop candidate requires its own complete gate after runtime/test/dependency changes. Durable local artifacts live under `/home/timber/code/Boorusama/.worktrees/_artifacts/local-acceptance-corrections-20261031/`, outside `/tmp`. No remote issue comment was posted.
