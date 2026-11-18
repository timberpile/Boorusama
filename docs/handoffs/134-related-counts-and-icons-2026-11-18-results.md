# Remaining Related timeline fixes (#134)

Continued the existing task worktree. The earlier local geometry correction
`e40b9530a` already reused the same `RelatedGridCard` / `RelatedGridGeometry`
implementation as #166; it was retained for publication, without another
geometry implementation or unrelated #166 cover changes.

Shared corrections `320da6948` and `8c8c31771` were replayed as `0f6196520`
and `2faf24aac`. The explicit-refresh replay retains this branch's pre-existing
cover/draft behavior; only count publication and its tests were added.

## Behavior

- Timeline Related cards observe authoritative totals discovered through normal
  Group summary/details/member loading and explicit Related bookmark refreshes.
  Observation itself starts no network requests. Existing summary snapshots are
  read only when already available; displayed subsets never substitute for totals.
- The shared cache is keyed by canonical Group identity and content-access key,
  excluding member order and occurrence. It lives for the provider container,
  retains at most 256 count entries and 256 read fences, and keeps no clients alive.
  Refresh clears the relevant count and suppresses obsolete snapshot fallbacks;
  generation/read tickets reject stale or evicted results. Authorization changes
  switch the observed key. Counts survive gallery disposal and ordinary navigation.
- Related badges use the white 16 dp `Symbols.photo_library` inside the existing
  24 dp badge. Unknown counts remain icon-only, including accessibility. Series,
  Collection, count typography, source icon and positioning retain their behavior.
- Individual Post thumbnails no longer render a Parent/Child icon. Only its
  presentation parameter/plumbing was removed; `Post.hasParentOrChildren` and
  grouping data remain intact. Other thumbnail overlays are preserved.
- Standard/Classic fitting and frozen Masonry geometry remain as verified in the
  preceding cover-layout report. Count and authorization rebuilds do not resize cards.

## Verification

Checked the final runtime/test tree committed with this report, based on
`2faf24aac` plus the two timeline observer/test changes.

**164 targeted tests passed**, no skips:

```sh
fvm flutter test --no-pub --concurrency 6 --reporter expanded \
  test/core/content/related_group_counts_test.dart \
  test/core/posts/pools/group_post_pager_test.dart \
  test/core/content/group_members_provider_test.dart \
  test/core/posts/pools/group_peer_refresh_test.dart \
  test/core/posts/pools/pool_grid_item_badge_test.dart \
  test/core/posts/listing/post_grid_item_test.dart \
  test/core/posts/listing/thumbnail_overlays_test.dart \
  test/core/posts/listing/related_timeline_grid_test.dart \
  test/core/posts/listing/related_timeline_grouping_toggle_test.dart \
  test/core/posts/listing/related_grid_card_test.dart \
  test/core/posts/listing/neighboring_timeline_groups_test.dart \
  test/core/bookmarks/related_bookmark_metadata_test.dart
```

The timeline regression opens the actual `RelatedGallery`, returns to a formerly
unknown card and observes the authoritative total without another member/summary
request. It also covers actor revocation/replacement, stale actor counts, unchanged
geometry, selection and family viewer mapping at narrow width and enlarged text.
Shared tests cover refresh, concurrent reads, canonical identity, retention,
zero/unknown totals, source revocation, icon semantics and other thumbnail badges.

All changed Dart files formatted; `git diff --check` passed. Analysis of the 18
newly changed Dart files: **0 errors, 0 warnings, 27 informational findings**
(exit 1). Existing non-fatal fixture hit-test messages remain in the logs.
Logs: `.worktrees/_artifacts/related-remaining-20261118/134-*.log` and the shared logs.

No full repository regression, native build, live-service, emulator or device
checks were run. This is targeted qualification, not develop integration or final
Android acceptance. Feature-only timeline changes stay out of the bugfix preview.
No develop integration, issue closure or branch deletion.
