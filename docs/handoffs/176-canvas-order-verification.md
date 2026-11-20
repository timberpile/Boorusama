# #176 canvas, sorting, and swipe verification

## Single-image Works and Single sort follow-up

Pixiv Works offer Timeline once the viewer knows the Work has at least two
pages. A single-image Work stays in Single and the Timeline choice carries
through to the next eligible Group.

When a sort completes in Single, the viewer selects the first member of the
new order. The applied image remains visible during preparation. A prepared
first batch can be adopted even when the previously selected image is far
down the new order.

The affected Flutter suites passed 642 tests. The changed-file analyzer
reported zero errors, zero warnings, and 27 informational findings. Logs are
`first-image-affected.log` and `first-image-analyze.log` in the artifact
directory below. The widget tests cover stale Pixiv listing counts, Timeline
swipe carry, the sort transition at both motion settings, and subsequent member
navigation. Verification used the Flutter host runner.

The earlier implementation and evidence are recorded below.

## Canvas and transactional sorting revision

The local task branch is `feature/176-group-viewer-design`. The follow-up starts
at `e7056da44ebd67b99a57f650c83087d3bd5763ef`. Runtime and generated translation
input are at `74bd404be99628455027e3150a5da8ba87bf09bb`.

## Behavior

- The page counter uses the usable lower-right canvas corner. The bottom
  obstruction follows the viewer overlay and combines with the safe inset by
  taking the larger value. In Detailed the counter scrolls with the media.
- Related uses Latest and Oldest with the existing stored order keys. Series
  and Collections expose Ordered, Latest, and Oldest in Single and Timeline.
  A fresh Series opens its first Ordered member. Pixiv retains its Work cover
  handoff and author Page order.
- The active Single or Timeline presentation follows outer swipes across
  supported Groups, including when an ordinary Post sits between them.
- The sort trigger displays the pending indicator while preparation runs.
  Infinite Timeline keeps the shared membership cursor. Paginated Timeline
  prepares the indexed first page and retains indexed navigation after adoption.
  Adoption clears the target viewport checkpoint and starts at the top.
- Single searches a contiguous occurrence prefix, up to eight new batches
  per selection. Repeating the same paused sort resumes that prefix. A ready
  reorder retains the selected media widget, decoded image, and zoom.
- A saved Related order is committed after the target representation is ready.
  The storage guard checks authorization and the caller. The expected record
  is compared under the same repository lock as the write.
  Cancellation before admission stops the write. Cancellation after admission
  leaves the saved preference available on the next open.

## Source scope

- Viewer and reindexing live in the shared Group reading controller, media
  presenter, checkpoint, and mixed viewer. The canvas counter uses the shared
  media viewport and the native viewer's bottom obstruction.
- Timeline adoption uses GroupPostScope, the shared grid controller and scope,
  and the Danbooru Pool and Related galleries. The sort icon is shared across
  the header, menus, and overflow.
- BookmarkLibraryNotifier owns saved Related order and cover writes. Existing
  storage order keys remain in use. English localization supplies the retry
  message for a paused lookup.

## Evidence

The affected run passed 958 Flutter tests. Changed-file analysis completed with
zero errors, zero warnings, and 130 informational findings. The durable logs
are `committed-tests.log` and `committed-analyze.log`.

The affected scope includes the viewer, page view, listing/controller, Pool
and Pixiv Works suites; Group membership; Related metadata and bookmark
persistence; and the application Pool/Related and public refresh flows.

The focused regressions exercise the following behavior.

- A held Timeline request leaves the old rows and applied order visible in
  both page modes. Page-one request counts distinguish the grid read from
  saved-cover discovery. A late old page and a target page-two read verify
  ownership across adoption.
- Grid preparation waits for blacklist filtering, preserves filter choices,
  limits infinite empty-page continuation, and leaves a paginated empty
  first page with working Next navigation.
- Single retains identical selected widget and decoded image state across
  sampled frames of an eleven-position reorder, at both motion settings.
  The test also covers zoom retention and navigation to the new neighbor.
- A distant match pauses after eight new source batches and resumes to the
  same occurrence on explicit retry. A view change cancels a held sort.
- Outer swipes preserve Timeline and Single across a plain Post. Delayed
  Series metadata keeps the saved cover out of the viewer before the first
  actual Post appears.
- Bookmark persistence tests cover successful writes, request supersession,
  cancellation, a changed expected record, source failures, and reader
  access mismatch.

The host Flutter capture run produced 12 PNGs at 320×800, 414×915, and
844×390. The 320dp case uses 200% text. Captures cover Immersive, overlay,
Detailed, and the expired counter. The landscape overlay and 320dp Detailed
captures were visually inspected.

## Commands

```sh
./gen.sh i18n
fvm flutter test --no-pub --concurrency=6 --reporter=expanded \
  test/core/posts/details test/core/posts/details_pageview \
  test/core/posts/listing test/core/posts/pools \
  test/core/posts/post_grid_controller_selection_test.dart \
  test/core/content/group_members_provider_test.dart \
  test/core/bookmarks/related_bookmark_metadata_test.dart \
  test/core/bookmarks/pool_cover_native_persistence_test.dart \
  test/core/bookmarks/bookmark_unified_library_service_test.dart \
  test/application/pool_bookmark_flow_test.dart \
  test/application/public_group_refresh_flow_test.dart test/boorus/pixiv/works
fvm flutter analyze --no-pub --no-fatal-infos \
  $(git diff e7056da44 --name-only -- '*.dart')
fvm flutter test --no-pub --concurrency=1 --reporter=expanded \
  --dart-define=VIEWER_CAPTURE_DIR="$PWD/.worktrees/_artifacts/176-canvas-order/captures" \
  test/core/posts/details/mixed_post_details_page_test.dart \
  --name 'capture Pixiv Work shared Viewer modes'
```

Logs and captures are under `.worktrees/_artifacts/176-canvas-order/` in the
task worktree. ADB host discovery found no leaseable emulator, so the results
cover host-side Flutter behavior. Native gestures and authenticated live-site
behavior remain unverified. This branch is for local acceptance.
