# #134 Global Related grouping preference

Issue: https://github.com/timberpile/Boorusama/issues/134
Branch: `feature/134-related-timeline-groups`
Base inspected: `964b882284b354b3944cd3df1a86463c1c5f4bd2`.

## Revised owner contract

This revision supersedes the temporary, default-ON Group Posts control in the earlier #134 handoffs.

- **Related grouping is OFF by default**, including existing installations without the new setting.
- Settings → Appearance → Image Grid and Timeline View Options both expose **Group Related Posts**. Both controls edit the same persisted global value; there is no per-timeline override or query/profile reset.
- **Series remains automatically grouped**, retaining its existing priority and rolling five-result lookahead. Disabling Related expands only Related families, preserving existing Series representatives and raw controller items.
- The preference applies across supported Browse, Search, Artist and Topic Feed timelines, including profiles with custom listing settings. Selection Mode and explicit family/Series searches continue showing raw Posts.

## Implementation

`Settings.groupRelatedPosts` is a global optional Boolean, with strict true parsing and a false fallback. It participates in ordinary settings persistence, equality, copy operations and Settings backups. It is separate from profile-overridable ImageListingSettings; no storage or backup version migration is needed.

The shared `RelatedPostsGroupingSetting` component is used by both entry points and stays outside listing override blockers. English and German resources and Settings search use the same label. Confirmed SettingsNotifier writes update mounted timelines; failed writes retain the existing value. Consumers observe the notifier directly so a deferred forwarding-provider flush cannot notify an outgoing options sheet during another route's build.

The shared grid binds the controller's presentation value to the global preference. The projection has an independent Related enable flag; its overall enable flag still handles raw selection/explicit-query display. Preference changes preserve frozen Series entries, even if delayed metadata could otherwise choose another cover.

Anchor capture runs before the preference changes the layout and accounts for pinned-header obstruction when invoked from the grid. Distant hidden members still map to their earlier representative and return to their remembered raw anchor on expansion. Already-raw views avoid unnecessary scroll restoration. No Post, Series or count request is added by changing the setting; the feed history gate remains explicit.

The existing Appearance result-layout row needed a bounded displayed selection at 320dp/200% text: its Infinite Scrolling value otherwise consumed the complete row width. The bound matches Timeline View Options and leaves the dropdown's choices unchanged. Actual Appearance tests cover the new global control at both normal and enlarged text with custom listing overrides active.

## Verification

Checked the final source/test working tree atop `964b882284b354b3944cd3df1a86463c1c5f4bd2`, committed with this report. Only documentation was completed afterward.

- **574 focused tests passed** with six workers (the detected available physical cores). Coverage includes legacy/malformed preferences, actual repository reopening, Settings backup, actual Appearance controls at 320dp with normal/200% text, global controls with listing overrides, query/feed reopening, viewer/Back, selection during a global update, frozen Series stability, distant-member scroll anchors and zero additional requests.
- Existing Settings, Search/Browse/Artist, cached-feed/history, View Options and nearby backup/Related consumers are included in the command below.
- `fvm dart format --output=none --set-exit-if-changed` on all 17 changed Dart files: passed, no changes.
- `fvm dart analyze` on the same files: exit 0, zero errors, zero warnings, one existing informational finding in `post_grid.dart`.
- `./gen.sh i18n`: validation and generation passed for the English/German resource updates.
- `git diff --check` and the handoff's local link check passed.

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/settings \
  test/settings \
  test/core/posts/listing/neighboring_timeline_groups_test.dart \
  test/core/posts/listing/neighboring_series_test.dart \
  test/core/posts/listing/related_timeline_grid_test.dart \
  test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
  test/core/posts/listing/search_series_index_test.dart \
  test/core/search/following_topics/topic_feed_grouping_test.dart \
  test/core/search/following_topics/topic_feed_test.dart \
  test/core/search/following_topics/cached_feed_sort_history_test.dart \
  test/core/search/following_topics/feed_series_cache_test.dart \
  test/boorus/danbooru_browse_grouping_test.dart \
  test/boorus/danbooru_artist_page_test.dart \
  test/application/view_options_insets_test.dart \
  test/core/backups/topic_feed_backup_codec_test.dart \
  test/core/backups/topic_feeds_source_test.dart \
  test/core/backups/topic_feed_import_service_test.dart \
  test/core/bookmarks/related_bookmark_metadata_test.dart
```

Only focused automated verification is included. No complete integration suite, emulator, APK, live-service or owner Android acceptance testing was performed. The complete local suite and owner acceptance remain outstanding before a separately authorized develop integration. Keep #134 open and retain its branch; #96 is untouched.
