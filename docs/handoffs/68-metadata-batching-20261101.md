# Issue #68: whole-page Series metadata batches

Branch: `feature/group-neighboring-series`.
Runtime/test commit: `dc92912f311fa821ee3c22b6036623929d2dde75`.
Parent: `9e603a0fea21f186c78fefd30358bb067ea92d93`.

## Result

Series membership metadata is separate from post pagination. Each admission now
covers up to the supported 200 loaded post IDs, regardless of the configured
post page size. Danbooru's Pool response limit is 1,000 records rather than 100.
The API input-ID maximum is not asserted to be 200: this is the largest useful
admission for a supported loaded page. No extra posts are fetched to fill it.

The existing ten-second timeout, coalescing, source/account isolation and
512-entry cache remain. A response containing 1,000 Pools may be truncated, so
it fails the admission rather than caching incomplete membership; ordinary
posts remain visible and retryable. No metadata pagination or full-Series crawl
was added. Saved-reference member sampling remains independent.

The rolling lookahead, original indices, stable projection/anchors, ordinary
Bookmarks, explicit Series searches, full-Series navigation, persisted covers
and backup contracts retain their existing behavior. This follow-up does not
address the previously reported Artist-page disposed-WidgetRef finding.

## Verification

FVM Flutter 3.47.2; ordinary test concurrency: six physical cores.

```sh
fvm flutter test --no-pub --concurrency=6 \
  test/core/posts/listing/search_series_index_test.dart \
  test/core/posts/listing/neighboring_series_test.dart \
  test/boorus/danbooru_series_membership_test.dart \
  test/application/pool_bookmark_flow_test.dart test/core/bookmarks \
  test/core/backups/bookmark_backup_codec_test.dart \
  test/core/backups/bookmark_export_scope_test.dart \
  test/core/backups/bookmark_import_service_test.dart
```

Passed: 681 tests, exit 0. Includes a 200-ID admission, coalescing, source
isolation, retry/disposal, more than 100 returned Pools, saturated responses,
held metadata/tail freezing, rolling/cross-page grouping, selection, bounded
pagination, cover quality, persistence and backup consumers. Two application
assertions initially retained the old 40-ID limit; they were corrected and the
entire affected scope passed again.

Scoped `fvm flutter analyze --no-pub --no-fatal-infos` over all six changed Dart
files: exit 0, zero errors, zero warnings, 19 informational findings in existing
code. FVM format check: all six files unchanged. Final diff review and
`git diff --check`: passed.

Live read-only verification on 2026-11-01: `/posts.json` with `malberrybush` and
limit 200 returned 200 posts. One `/pools.json` request for those 200 IDs with
limit 1,000 returned HTTP 200, five Pools including three Series. This proves
endpoint acceptance, not current-source device UI acceptance. The API limit's
primary-source links are in the updated design document.

Durable local logs/provenance: `.worktrees/_artifacts/metadata-and-details-followup-20261101/`
(`68-final-focused`, `68-analysis`, `live-metadata.json`). The design/handoff
updates following these checks change no runtime or test candidate.

## Acceptance limits

No new APK/device verification or complete repository regression was run for
this scoped follow-up. Earlier full-suite/device evidence applies only to its
recorded candidate. Before integration, run the complete local suite on the
final integration candidate. On device, recheck `malberrybush` at 60 and 200 posts
per page: grouping/counts, scrolling near boundaries, selection and Load More
must remain stable. Human acceptance and the separate Artist finding remain
pending. Nothing was pushed, merged, closed or deleted.
