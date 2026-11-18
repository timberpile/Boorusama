# #134 Topic Feed grouping

Issue: https://github.com/timberpile/Boorusama/issues/134
Branch: `feature/134-related-timeline-groups`
Base: `db86266f51b0d03ae39e1c07ef74f8dc6f16e667`, including `origin/develop` at `8155acbfa281a983029de53b659e5f760222e5ec`.

## Behavior

Topic Feeds use the same grouped grid, cards and projected viewer as Danbooru Search, Browse and Artist Posts. Related uses the first verified direct-family representative across the loaded raw timeline; Series retains priority and the rolling five-result lookahead. Raw controller items remain intact, Selection Mode shows raw Posts, and the existing filter toolbar's View Options exposes the session-only Group Posts switch.

Mixed feeds resolve access and metadata per Post. Group identity includes the source and actor; a missing saved profile cannot silently borrow another account on the same site. Unknown Related totals show only the icon and never request count metadata.

For overlapping membership `A(S,R), B(S), ..., C(R)`, the projection contains a Series card for A+B and a Related card represented by C. Both group viewer entries remain reachable and every raw index belongs to exactly one displayed entry. Frozen entries retain their first representative when later pages extend a family.

The grouping toggle remembers the visible raw Post and maps it to the representative even when that representative is far away. Disabling grouping restores the remembered raw Post if it remains available. This is transient controller presentation state.

## Metadata and history

- Cached feed opening and grouping toggles perform no Post or Series metadata requests. Older caches can show Related immediately; Series becomes available after a successful Refresh backfills its metadata.
- Refresh enriches incoming Posts and retained Posts with missing metadata through the existing bulk Series capability. Requests are deduplicated by owning actor and bounded to 200 IDs per batch with one ten-second deadline for the complete enrichment operation.
- Membership distinguishes absent/unknown, confirmed empty and known Series. Only explicitly returned valid Post results replace metadata. Missing IDs, failed batches and late responses preserve matching prior cache entries. Completed batches survive a timeout; metadata failure does not discard a successful Post refresh.
- Optional feed-local cache entries contain compact Series IDs, titles and nullable totals, plus Post/source/actor binding. Existing Post snapshot codecs and backup versions are unchanged. Malformed optional records are ignored individually. Retention and source removal trim metadata; profile credential/network changes invalidate the affected metadata while retaining Posts.
- Definition exports and backups omit Series cache data. Refresh commits metadata within the existing guarded feed transaction.
- Only Load older posts opens history. Grid prefetch and both raw/projected viewer pagination respect that gate. Explicitly fetched history pages receive best-effort enrichment before admission, with metadata kept only in the session. Cancellation and source/profile changes reject stale responses.
- A metadata-only cache refresh rebuilds the open projection, including when refresh starts and finishes between frames. If history is active, cache updates remain behind Show updated posts to preserve the current session.

## Verification

Checked the final source/test working tree atop the base above, committed with this report. Only documentation was completed afterward.

- The following focused command passed **343 tests**, with no failures or skips, using the six available physical cores. It covers cache/refresh/history, actual narrow and enlarged-text feed pages, overlap and mixed actors, raw/representative anchoring, selection, OFF through viewer return and history append, Search/Browse/Artist consumers, Related counts, profile mutation and backup consumers.
- `fvm dart format --output=none --set-exit-if-changed` on all 28 changed Dart files: passed, zero changes.
- `fvm dart analyze` on those same 28 source/test files: exit 0, zero errors, zero warnings, 23 informational findings. No informational findings remain in the newly added files.
- `git diff --check`: passed. i18n generation was refreshed after synchronizing develop; this change adds no strings or generated inputs.

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/search/following_topics/feed_series_cache_test.dart \
  test/core/search/following_topics/topic_feed_grouping_test.dart \
  test/core/search/following_topics/topic_feed_test.dart \
  test/core/search/following_topics/feed_post_snapshot_test.dart \
  test/core/search/following_topics/following_topic_repository_test.dart \
  test/core/search/following_topics/search_refresh_service_test.dart \
  test/core/search/following_topics/feed_history_session_test.dart \
  test/core/search/following_topics/cached_feed_sort_history_test.dart \
  test/core/search/following_topics/topic_feed_initialization_test.dart \
  test/core/search/following_topics/following_public_access_test.dart \
  test/core/search/following_topics/local_copy_public_access_test.dart \
  test/core/posts/listing/neighboring_timeline_groups_test.dart \
  test/core/posts/listing/neighboring_series_test.dart \
  test/core/posts/listing/related_timeline_grid_test.dart \
  test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
  test/core/posts/listing/search_series_index_test.dart \
  test/boorus/danbooru_browse_grouping_test.dart \
  test/boorus/danbooru_artist_page_test.dart \
  test/boorus/danbooru_series_membership_test.dart \
  test/booru_config_notifier_test.dart \
  test/core/backups/topic_feed_backup_codec_test.dart \
  test/core/backups/topic_feeds_source_test.dart \
  test/core/backups/topic_feed_import_service_test.dart \
  test/application/view_options_insets_test.dart \
  test/core/bookmarks/related_bookmark_metadata_test.dart
```

No complete integration suite, emulator, APK, authenticated live-service or Android acceptance tests were requested or performed. Owner Android acceptance and the complete local suite remain required before a separately authorized develop integration. Issue #134 remains open and its task branch is retained. Issue #96 is unchanged.
