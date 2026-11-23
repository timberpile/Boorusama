# Related timeline cover layout (#134)

Implemented the owner's 2026-11-18 rendering specification on
`feature/134-related-timeline-groups`. This replaces the earlier proposal to
resize cards after image decoding.

Related entries resolve the displayed representative Post through the existing
thumbnail resolver and render it with `PostGridImage`. Standard fills the fixed
cell with cover fitting; Classic fills the cell with contain fitting. Related
cards omit the Pool tile's inset so their image occupies the same cell as a Post.
Series and Collection rendering retain their existing defaults.

Masonry captures a finite positive resolved ratio (then valid Post metadata)
before its first layout, or permanently captures `0.6` when neither is known.
It uses contain fitting. Geometry belongs to the listing's family occurrence,
so changes to media, quality, metadata, or a recycled tile cannot recalculate it.
A new query/source/controller creates a new listing scope.

## Verification

Checked the final runtime/test tree committed with this report, based on
`fe02c45c6dc896694b557e9a06fe48b21e0aa71a`.

- Failing-before reproduction: four timeline card cases reported the old `0.6`
  geometry instead of the representative Post's known square ratio.
- Final targeted command: **117 passed**, no skipped tests:

  ```sh
  fvm flutter test --no-pub --concurrency 6 --reporter expanded \
    test/core/posts/listing/related_grid_card_test.dart \
    test/core/posts/listing/related_timeline_grid_test.dart \
    test/core/posts/listing/neighboring_timeline_groups_test.dart \
    test/core/posts/listing/neighboring_series_test.dart \
    test/core/posts/listing/search_series_index_test.dart \
    test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
    test/core/posts/pools/pool_grid_item_badge_test.dart \
    test/core/posts/listing/post_grid_item_test.dart
  ```

- Coverage includes portrait/square/landscape media in every mode, fixed-cell
  image bounds and fitting, unknown/invalid ratios, frozen geometry after media
  rebuilds and child disposal, selection and full-family navigation, grouping,
  Series precedence, and badges. Narrow-width/enlarged-text checks remain active.
  The grouping-toggle test now measures the actual first visible item below its
  pinned header; natural Masonry columns need not share the row at y=100.
- Changed Dart files formatted; `git diff --check` passed. Analysis of the six
  changed Dart files: **0 errors, 0 warnings, 8 informational findings** (exit 1).
- Logs: `.worktrees/_artifacts/related-cover-layout-20261118/134-*.log`.

Full repository regression, native builds, live services, emulators and devices
were not exercised for this correction. Final Android acceptance remains with
the owner. This feature correction stays on its own branch and is excluded from
the cumulative bugfix preview. No develop integration or issue closure.
