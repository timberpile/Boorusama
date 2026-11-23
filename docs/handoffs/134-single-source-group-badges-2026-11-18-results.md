# Single-source timeline group badges (#134)

The owner reported a Danbooru site logo on Related thumbnails in ordinary Browse.
`SearchSeriesGrid` always represents one configured Danbooru source and is shared
by Browse, Search and Artist timelines. It no longer supplies a site icon for
Related or Series cards. Their group-kind icons, counts, layout, selection and
viewer navigation remain unchanged.

Bookmark cards and mixed-source presentation still supply their source icons;
no global badge suppression or context flags were added. The existing shared
badge tests continue to verify their source-icon slot and positioning.

## Verification

Checked the final source/test tree committed with this report, based on
`81ffe514178ff87914e600053449224b14a42573`.

- Failing-before regression: the standard-mode Related card supplied a `ClipRRect`
  source icon where a single-source card must supply none.
- **51 targeted tests passed**, no skips:

  ```sh
  fvm flutter test --no-pub --concurrency 6 --reporter expanded \
    test/core/posts/listing/related_timeline_grid_test.dart \
    test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
    test/core/posts/listing/related_grid_card_test.dart \
    test/core/posts/pools/pool_grid_item_badge_test.dart
  ```

- Coverage includes all three image-list modes, stable Masonry geometry,
  gallery-return counts, actor changes, grouping/selection, single-source Related
  and Series cards, and retained source badges on shared/mixed cards. Narrow width
  and enlarged text checks remain active.
- Changed Dart files formatted; `git diff --check` passed.
- Analysis of the three changed Dart files: **0 errors, 0 warnings,
  5 informational findings** (exit 1).
- Logs: `.worktrees/_artifacts/134-site-badge-20261118/`.

No full regression, native build, live-service, emulator or device test was run
for this scoped correction. #134 remains on its feature branch for owner review;
no develop integration, issue closure or branch deletion for #134 is authorized.
