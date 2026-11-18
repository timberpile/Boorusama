# Remaining saved Related fixes (#166)

The saved cover-layout correction at `cecba9e19` is retained without
reimplementation. `RelatedGridCard`, cover aspect-ratio metadata and their
serialization paths are unchanged. The preceding cover-layout verification is
reused as requested; its full mode matrix was not rerun unnecessarily.

Shared commits `320da6948` and `8c8c31771` publish authoritative Related totals
from existing Group reads and explicit Related bookmark refreshes, and reserve
`Symbols.photo_library` for Related Group badges. #134 reuses those same patches
without importing the #166 cover/draft changes.

## Behavior

- Saved Related cards observe the total under their actual current read actor
  and canonical Group identity. No summary/member requests are started for a badge.
  Valid persisted totals remain a fallback until a live total is learned; explicit
  refresh suppresses the obsolete fallback until a new authoritative total arrives.
- The in-memory cache survives gallery disposal/navigation but ends with its provider
  container. Count entries and read fences are each bounded to 256. Read generations,
  publication ordering and authorization checks reject stale responses; unknown
  totals never become a count of loaded, filtered or displayed members.
- Publisher-owned received records are not updated for presentation counts. The
  received-record regression checks the identical library object and unchanged
  stored total while multiple occurrences observe refresh and actor changes.
- Related badges now use white 16 dp `Symbols.photo_library`, keeping the existing
  24 dp badge geometry, source icon, count typography and accessibility. Unknown
  Related totals are icon-only. Series and Collection icons remain unchanged.
- The Parent/Child thumbnail overlay and its presentation argument are removed
  globally from individual Posts. `Post.hasParentOrChildren` and grouping remain;
  all other thumbnail overlays preserve their behavior.

## Verification

Failing-before evidence in `before.log`: the actual Related Gallery returned to
an unknown saved count, and the Related badge lacked the required symbol.

Checked the final runtime/test tree committed with this report (parent
`8c8c31771`). **139 targeted tests passed**, no skips:

```sh
fvm flutter test --no-pub --concurrency 6 --reporter expanded \
  test/core/content/related_group_counts_test.dart \
  test/core/posts/pools/group_post_pager_test.dart \
  test/core/content/group_members_provider_test.dart \
  test/core/posts/pools/group_peer_refresh_test.dart \
  test/core/posts/pools/pool_grid_item_badge_test.dart \
  test/core/posts/listing/post_grid_item_test.dart \
  test/core/posts/listing/thumbnail_overlays_test.dart \
  test/core/bookmarks/related_bookmark_metadata_test.dart \
  test/application/public_group_viewer_flow_test.dart \
  test/core/content/group_source_registration_test.dart \
  test/core/content/group_access_isolation_test.dart
```

One additional received-record/occurrence/access regression passed:

```sh
fvm flutter test --no-pub --concurrency 6 --reporter expanded \
  test/core/bookmarks/public_group_cover_test.dart --plain-name 'Related counts update'
```

The actual-gallery regression learns total 2 while only one member is resolved,
then returns to the card without another request. Explicit bookmark-refresh tests
replace an older cached total with the producer's exact total, retain the existing
request count, and reject publication after authorization loss. Other tests cover
zero/unknown counts, refresh, delayed reads, cache eviction, source isolation,
multiple occurrences, retained Series/Collection badges and all other Post overlays.

Formatting and `git diff --check` passed. Analysis of all 19 newly changed Dart
files: **0 errors, 0 warnings, 52 informational findings** (exit 1). Existing
non-fatal hit-test messages remain in the test logs.
Logs: `.worktrees/_artifacts/related-remaining-20261118/166-*.log`, shared and refresh logs.

Replay only these new #166 corrections into
`maintenance/pre-release-bugfix-preview-20261117` and verify the combined candidate.
The #134 feature-only timeline changes remain on their issue branch.

Full repository regression, native builds, live services, emulators and devices
were not exercised. Final Android acceptance remains with the owner. General
release/migration policy is untouched. No develop integration, issue closure or
branch deletion.
