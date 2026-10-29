# Cross-branch findings

## AA01-A02-F0002 — Pixiv bookmark continuation lost without #113 grid fix

- **Kind / severity / confidence / lifecycle:** defect / medium / static-confirmed / open until #113 continuation fix is integrated.
- **Affected:** #117 `feature/117-pixiv-favorites` T004, with #113 `bug/113-collection-pagination` T001 as source of the focused remedy. Count this finding once.
- **Origin:** interaction: a new cursor source exposes an inherited GridController exhaustion bug. #113 does not introduce the bug.
- **Source:** #117 `e2929259b7725c484d11483d6ea48270079eb2f4`, #113 `a1bc1d42903861a46e7230349515946bae678357`, comparison/merge base `422aeae087c1108e655d85d1a3dac25120456cd6`.
- **Locations:** [Pixiv session 63–70](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/favorites/session.dart#L63-L70); [Pixiv parser 26–44](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/boorus/pixiv/posts/parser.dart#L26-L44); [baseline GridController 359–373 and 399–409](https://github.com/timberpile/Boorusama/blob/e2929259b7725c484d11483d6ea48270079eb2f4/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L359-L409); [#113 remedy](https://github.com/timberpile/Boorusama/blob/a1bc1d42903861a46e7230349515946bae678357/lib/core/posts/listing/src/widgets/post_grid_controller.dart#L381-L392).

### Expected versus observed source behavior

The Pixiv cursor may validly advertise more pages while all artwork in a current page is unavailable/restricted. `illustDtosToPosts` removes invisible or URL-less illusts; thus `PixivFavoritesSession` returns an empty list with `hasMore:true`. The #117 branch inherits `PostGridController` from develop, which ignores explicit `hasMore` and treats an empty parsed page as terminal on refresh and fetchMore. Later bookmarked artworks cannot be reached.

### Trigger and reachable failure path

1. API page contains only hidden/unrenderable illustrations with a valid next cursor. 2. The session advertises continuation yet yields zero post items. 3. The grid assigns `_hasMore = newItems.posts.isNotEmpty`, suppressing next fetch. The same happens on intermediate pages. Source code establishes this conditional failure; authenticated frequency is unknown.

### Evidence and safeguards checked

The #117 session/decoder preserve cursor metadata and are not responsible for the lost flag. In the #113 branch, `_canLoadMore` prioritizes `result.hasMore` and preserves a final nonempty page, addressing the failure. The #113 change has not been integrated into #117, and combined execution was not tested.

### Root cause and practical impact

GridController conflates rendered/filtered items and remote source continuation. Favorites may appear blank/truncated despite existing later items.

### Minimal recommended correction

Integrate #113 before #117, or apply equivalent focused GridController continuation handling in the final combined candidate. Do not compensate with eager cursor walking.

### Suggested local verification and regression checks

With FVM tests and an authorized Pixiv profile, exercise first/intermediate all-filtered pages with next cursors, last nonempty terminal page, retry, view state, profile/private switching and no stale old-account results. Run #113 + #117 suites and final regression.

### Assumptions and remaining uncertainty

Supported by source parser conditions and `PixivBookmarkPage` next cursor contracts; no live response was observed. This is a static-confirmed conditional path, not a measured incidence claim.

### History

Cycle 1 2026-10-29T17:38:27.906Z: opened on #117 source. Keep open until the combined branch contains #113 or equivalent and is reviewed.
