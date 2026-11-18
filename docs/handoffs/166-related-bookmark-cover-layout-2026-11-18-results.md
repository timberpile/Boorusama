# Saved Related cover layout (#166)

Implemented the owner's 2026-11-18 rendering specification on
`bug/166-pool-bookmark-covers`. This supersedes any earlier proposal to resize
Masonry cards from image-loading callbacks.

Related cards reuse `PostGridImage` and the shared `RelatedGridCard` frame:
Standard fills its fixed cell with cover fitting; Classic fills it with contain
fitting. The Pool inset and unconditional portrait frame are removed for Related
only. Series and Collection retain their existing frame, inset and image fitting.

Masonry captures the actual selected media's known ratio before first layout,
or permanently captures `0.6` if it is unavailable. Contain fitting keeps the
whole image visible even when a later cover or quality has a different shape.
Listing-owned geometry survives lazy child disposal and media retry rebuilds.
Only a new explicit bookmark view/query resets the listing scope. There are no
decoded-size callbacks and no new requests to obtain dimensions.

`PoolBookmarkCover` retains optional thumbnail/sample/original ratios from the
selected Post, including static fallbacks for animated media. The native cover
codec, save/cover-only patch paths and receiver-local presentation cache preserve
these ratios. URL fallback selection uses the ratio of the media actually chosen.
Old covers remain readable without the new fields; invalid ratios are unknown.
Legacy full-media dimensions are not assumed to describe cropped thumbnails.

Receiver-local covers supply their own metadata. Existing sticky selection,
source authorization, blacklist checks, ownership and persistence guards remain
in place. Retained metadata can determine layout while visibility policy loads;
the image remains hidden until the existing visibility check permits it.
General release and migration policy are unchanged.

## Verification

Checked the final runtime/test tree committed with this report, based on
`9672fa855a274cbf378e8c130abcabf6a184b9f0`.

- Failing-before reproduction: selecting a Post with ratio `1.5` returned a cover
  with no resolved aspect ratio. The new regression passes with retained metadata.
- Final targeted command: **273 passed**, no skipped tests:

  ```sh
  fvm flutter test --no-pub --concurrency 6 --reporter expanded \
    test/core/bookmarks/public_group_cover_test.dart \
    test/core/bookmarks/related_cover_metadata_test.dart \
    test/core/bookmarks/bookmark_cover_thumbnail_test.dart \
    test/core/bookmarks/pool_cover_native_persistence_test.dart \
    test/core/bookmarks/pool_cover_backfill_test.dart \
    test/core/bookmarks/bookmark_cover_choice_test.dart \
    test/core/bookmarks/bookmark_local_group_thumbnail_test.dart \
    test/core/bookmarks/stored_bookmark_codec_test.dart \
    test/core/content/group_metadata_test.dart \
    test/core/content/group_envelope_cache_test.dart \
    test/core/posts/listing/grid_thumbnail_media_test.dart \
    test/core/posts/listing/post_grid_item_test.dart \
    test/core/posts/listing/related_grid_card_test.dart \
    test/core/posts/pools/pool_grid_item_badge_test.dart \
    test/core/backups/bookmark_backup_codec_test.dart \
    test/core/backups/mitemite/bookmark_mirror_engine_test.dart \
    test/application/public_group_viewer_flow_test.dart \
    test/application/public_group_refresh_flow_test.dart
  ```

- Coverage includes portrait/square/landscape and unknown ratios in all modes,
  fixed-cell bounds and fitting, first layout while policy loads, controlled
  image decoding, delayed/stale discovery, quality and selected-cover changes,
  actual offscreen disposal, receiver-owned covers, JSON/native/Hive restart
  persistence, quality/grid-size selection, source authorization, signed mirror
  reception, backup compatibility, and unchanged Series/Collection presentation.
- Changed Dart files formatted; `git diff --check` passed. Analysis of the 18
  changed Dart files: **0 errors, 0 warnings, 111 informational findings** (exit 1).
- Logs: `.worktrees/_artifacts/related-cover-layout-20261118/166-*.log`.

Replay this correction into `maintenance/pre-release-bugfix-preview-20261117`
and verify the combined candidate before publication. The #134 feature correction
stays on its own branch.

Full repository regression, native builds, live services, emulators and devices
were not exercised for this targeted correction. Previous full-suite results do
not qualify this new runtime candidate. Final Android acceptance remains with
the owner. No develop integration, issue closure, or branch deletion.
