# #134 Raw Related icons and View Options alignment

Issue: https://github.com/timberpile/Boorusama/issues/134
Branch: `feature/134-related-timeline-groups`
Base inspected: `8882f703accace8b20b207c11349f7f69a3e1d56`.

## Corrections

- When global Related grouping is OFF, individual Posts with parent/child evidence show the existing `photo_library` thumbnail badge again. A valid parent ID is sufficient even if the generic relationship flag is absent. Unrelated Posts have no Related badge.
- When grouping is ON, individual thumbnails omit that badge; the Related group card retains its existing icon/count contract. Series grouping, viewer mappings, selection, and the global default remain unchanged.
- The Group Related Posts label in Timeline View Options aligns with the other setting labels, including at 320dp and 200% text, while remaining usable with custom listing overrides.

## Confirmed causes and implementation

Commit `0f6196520` removed the relationship input and icon from the shared `ImageGridItem` renderer entirely. Consequently, disabling grouping could expand the raw Posts but could not restore their badges. The thumbnail relationship input and former overlay icon are restored; the Post-aware adapter supplies relationship evidence only while `Settings.groupRelatedPosts` is false. This uses existing Post data and adds no metadata or count request.

The switch had four pixels of horizontal content padding. The adjacent `KurumiSettingsTile` controls explicitly use zero content padding, overriding their ListTile theme. Before the fix, rendered label positions were x=12 versus x=8 at both tested text scales. The switch now also uses zero padding and stays outside the profile listing override blocker.

## Verification

Checked the final source/test working tree atop the base above, committed with this report. Only documentation was completed after these checks.

- Before the fixes, the ten new focused cases produced exactly four expected failures: missing child/parent badges with grouping OFF, and a four-pixel label offset at both text scales. The six negative controls passed.
- **62 tests passed** in the four directly affected test files. They cover parent-ID fallback, no badge for unrelated/invalid-parent Posts, suppression while grouping is ON, actual Browse/feed icon changes without requests, and exact label alignment at 320dp with 100%/200% text and custom listing overrides.
- **71 nearby consumer tests passed**, covering thumbnail geometry, Related/Series card badges, cached counts, actual Appearance controls, View Options insets and Artist timelines. Total: **133 passing targeted tests**.
- `fvm dart analyze` on the seven changed Dart files: exit 0, zero errors, zero warnings, four informational findings in the existing PostGridItem test fixture.
- The PostGridItem gesture fixtures emitted 20 hit-test warnings while their assertions passed. The new icon and alignment cases passed without failures; no warning was suppressed.
- `fvm dart format --output=none --set-exit-if-changed` on the changed Dart files and `git diff --check`: passed. No generated inputs changed.

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/posts/listing/post_grid_item_test.dart \
  test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
  test/core/search/following_topics/topic_feed_grouping_test.dart \
  test/boorus/danbooru_browse_grouping_test.dart

fvm flutter test --no-pub --concurrency=6 \
  test/core/posts/listing/thumbnail_overlays_test.dart \
  test/core/posts/pools/pool_grid_item_badge_test.dart \
  test/core/posts/listing/related_timeline_grid_test.dart \
  test/core/settings/related_posts_grouping_settings_test.dart \
  test/application/view_options_insets_test.dart \
  test/boorus/danbooru_artist_page_test.dart
```

Only short targeted automated checks are included. No emulator, APK, live-service, complete integration suite or owner Android acceptance tests were run. Issue #134 stays open and the task branch is retained; develop and #96 are unchanged.
