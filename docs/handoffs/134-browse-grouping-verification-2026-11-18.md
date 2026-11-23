# #134 Browse grouping follow-up

Branch: `feature/134-related-timeline-groups`. Refs #134.
Checked source: the follow-up commit containing this report, based on
`e6ccbfbee62eee4dee4281bec6312ae0154b25a7`.

## Cause and correction

The owner confirmed that Danbooru Browse had neither grouped Posts nor Group
Posts in View Options at that parent commit. `DanbooruBuilder.homeViewBuilder`
renders `LatestView`, which still constructed a plain PostGrid. Only Search and
Artist instantiated SearchSeriesGrid, whose session enables the switch. Both
missing behaviors therefore had the same unconnected Browse entry point.

Earlier shared-grid tests and the generic headless View Options host did not
exercise Danbooru's real Browse builder. The new regression mounts that actual
builder and LatestView. Before the correction, both width cases failed because
the grouped grid was absent.

Browse now owns a SearchSeriesIndex, waits for the existing bounded whole-page
Series membership admission, and uses SearchSeriesGrid. Metadata admission checks
that the view and profile are still current. Mobile trend-tag and applied desktop
query changes update the projection's session using existing query notifiers.
The owned index/notifiers are disposed with the view. No new settings, strings,
family-count requests, or changes to Series priority/lookahead are introduced.

## Short automated checks

The final targeted combination passed **51 tests** with:

```sh
fvm flutter test --no-pub --concurrency=6 --reporter expanded \
  test/boorus/danbooru_browse_grouping_test.dart \
  test/core/posts/listing/neighboring_timeline_groups_test.dart \
  test/core/posts/listing/neighboring_series_test.dart \
  test/core/posts/listing/related_timeline_grid_test.dart \
  test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
  test/core/posts/listing/search_series_index_test.dart \
  test/application/view_options_insets_test.dart
```

The five new Browse cases use an explicit Android platform variant, 320px and
1280px viewports, and 200% text. They cover Related/Series cards, the real View
Options switch, OFF/ON without new Post or membership requests, mobile/desktop
query resets, raw explicit-family queries without metadata admission, and a
controlled pending membership response before the first tiles are fixed.
After removing an unused test import, the five Browse cases were rerun on the
final files. Focused `fvm dart analyze` on the changed production/test files
reported no errors, warnings, or informational findings. Dart formatting,
`git diff --check`, and changed-document relative-link checks passed.

Durable logs: `.worktrees/_artifacts/134-browse-20261118/` in the primary workspace.
The earlier #134 verification reports remain unchanged as historical evidence.

## Limits

No emulator/device, live API, APK build, exhaustive repository suite, or develop
integration was performed. Android acceptance remains with the owner. Retain the
feature branch and open issue; publication is limited to that branch.
