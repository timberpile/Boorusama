# Neighboring series in the post feed

Base inspected: `develop` at `a46521eced78ae2f31a5c2517a43fc2e4e4a6072`.
Branch: `feature/group-neighboring-series`.

## Status

Design proposal with an initial grouping primitive, **not an integrated feature**.
The standalone interactive HTML mockup is delivered with the design review as
`series-feed-mockup.html`; it is not a Flutter screen or a live API client.

- [x] Inspect the current post grid, selection, Danbooru post conversion, pool
  repository, pool tile, and pool detail page.
- [x] Create the interactive mockup: grouped/ungrouped comparison, full-series
  navigation, local expansion, selection, separated runs, page seam, and failure.
- [x] Add the pure grouping projection and behavior-test cases.
- [ ] Run Dart formatting, targeted tests, and the complete repository suite.
- [ ] Resolve/cache confirmed series metadata efficiently.
- [ ] Connect projected entries to the grid, source indices, selection, viewer,
  scrolling, and pagination.
- [ ] Add the localized preference and Kurumi series-tile actions.
- [ ] Verify real Danbooru responses, filtering, accessibility, and device behavior.
- [ ] Follow-up: reuse confirmed-series grouping for existing bookmark-group
  timelines and add idempotent whole-series-to-post-bookmarks action (below).

## UX decision

Use a normal-sized grid tile, not a full-width banner or a horizontal carousel.
Two or more neighboring results in one confirmed series become one tile at the
first result's position. Its cover is the first **visible matching** post, with
a subtle stacked edge, a photo-library count badge, and the series title. It
uses the user's existing grid density, thumbnail settings, and theme.

The count is the number of grouped results: **20 posts in this feed**, not the
whole pool's size. A 28-post pool can therefore appear as a 20-post tile. Do not
substitute the pool's first image for the cover: it may not match the query or
may be blacklisted. Titles remain textual, not icon-only, and support enlarged
text and narrow tiles.

Tap opens the existing series/pool detail route in series order, using the
originating profile. Keep the normal filtering and authorization rules there.
A small context line explains that the full series is being opened and how many
posts came from the feed; this is deliberately not the current search result
subset. Back restores the feed position. Do not regroup inside a pool page.

The tile's Kurumi menu offers **Open series**, **Show 20 posts separately**, and
**Select these 20 posts**. Local expansion preserves that run's original order
and adds a collapse control. It is a presentation override for the current
search, not a global preference or a separate group record. Keep the existing
long-press/context-menu conventions; do not add another selection-mode button.

In active selection, tapping a group selects/deselects its underlying matching
posts. The toolbar says **20 posts selected**, not one item. Partially selected
runs use a mixed checkbox; tapping a partial run selects all its members.
Actions never silently operate on all posts in the full series. Range selection
must map entry ranges to source-post ranges. No ambiguous single-post quick
favorite/bookmark button should be attached to a collapsed group.

Add **Group series** to the existing grid settings, enabled by default for
supported Danbooru browse/search views. Use the existing preference storage
pattern rather than a second settings mechanism. The mockup's grouping-status
chip is explanatory and can be omitted from production if redundant.

## Grouping contract

Input is the de-duplicated, filtered, ordered list already intended for display.
A hidden/removed item contributes neither a cover nor a count; adjacency is the
order the user would otherwise see. Do not examine hidden thumbnails to choose
a nicer cover.

- Only confirmed Danbooru pool category `series` qualifies. Ordinary collections,
  copyright/artist tags, parent/child links, and similar upload times do not.
- Never group across normalized site, originating profile, or authorization
  boundaries. Unknown origins and unknown membership remain single posts.
- Group runs, not every matching pool across the feed. `A A X A A` becomes
  `[A x2] X [A x2]`; `A A X A` ends in a normal single-post tile.
- Every member must share one actual series. `A, A+B, B` is not a valid group of
  three. Starting at the next unconsumed post, choose the longest common-series
  prefix; smallest numeric pool ID breaks equal-length ties.
- Flattening entries must reproduce the original post list exactly, including
  order. The cover and entry key use the first source post. A key should include
  its origin and selected series ID, not the changing group count.

`groupNeighboringSeries` implements this projection only. The caller provides
confirmed series IDs and an origin/auth scope key. It retains `firstIndex`, the
actual member posts, and a nullable `seriesId`; a null ID is a singleton. It
performs no network access and makes no claim to classify arbitrary pool IDs.

## Fit with develop

Relevant existing components:

- `lib/core/posts/listing/src/widgets/post_grid.dart`: grid composition,
  post-index item builders, selection, and pagination controls.
- `lib/core/posts/listing/src/widgets/post_grid_controller.dart`: retain the raw
  post list as source of truth. Do not replace it with cover posts.
- `lib/core/posts/pools/pool_grid_item.dart`: reuse the established title,
  thumbnail, and photo-library count treatment; adjust only what a feed tile
  requires. Use Kurumi menu rows and the active theme.
- `lib/boorus/danbooru/pools/details/src/pool_detail_page.dart`: existing pool
  detail destination and ordered post presentation.
- `lib/boorus/danbooru/posts/post/src/converter.dart` and
  `src/danbooru_post_data.dart`: current post conversion/data does not retain
  pool membership. It cannot be obtained from a grid post without additional
  metadata plumbing.
- `lib/boorus/danbooru/pools/pool/src/data/pool_repository_impl.dart`: current
  cached lookup is per post. Do not call it for every rendered tile.

Introduce an explicit display-entry adapter at the grid/sliver boundary. Simply
changing `itemBuilder` cannot compact item count, and hiding duplicate tiles
would leave gaps or broken indices. Audit item count, masonry aspect ratios,
scroll-to-index, context-menu indices, custom builders, selection, and gallery
handoff together. Opt eligible views in; do not change all specialized galleries.

## Metadata, performance, and recovery

Before integration, inspect the booru client DTO and query options. Prefer
retaining pool IDs supplied by the posts endpoint and fetching unique pool
metadata in bounded batches. Verify this against the current client/site
contract; no batch endpoint or parameter has been assumed by this patch.
If necessary, extend the client/repository with a verified batched lookup rather
than shipping an N+1 per-post fallback. Cache titles, categories, and membership
by site/profile/auth scope, deduplicate in-flight requests, bound memory and
concurrency, and negatively cache successful empty results separately from
failures. Ignore responses from an obsolete search/profile generation.

Use a bounded page-preparation window. When metadata is unavailable, append
ordinary posts without blocking the feed or guessing. Freeze already displayed
runs for that generation; do not later collapse visible posts because a slow
request completed. New metadata can take effect on an explicit refresh/retry or
on a not-yet-displayed page. Errors belong to grouping, not to the post request.

Pagination and backend page size continue to count **raw posts**, not tiles.
In infinite mode, extend a confirmed tail run across page boundaries, retaining
its cover/key and the visible scroll anchor. A singleton tail may become a
series tile when the next page arrives. In numbered-page mode, group each page
independently. Coalescing must not turn a full backend page into an apparent
end-of-results. Check viewport underfill after layout; allow only a bounded
number of automatic fetches before requiring an explicit load-more action.

The primitive currently recalculates a projection; it does not manage frozen
entries or scroll anchors. At integration, memoize by source-list/metadata
revision and update the append seam, not every tile build. No decoding, metadata
lookups, sorting, or thumbnail preloading inside tile builders.

## Bookmark Browser follow-up: decisions preserved from prior chats

**Provenance:** The *Series Posts Grouping* discussion developed the older
*Series Posts Grouping Old* idea of grouping individually saved posts. This
section records those product requirements separately from implementation
suggestions. These are requirements for the **future bookmark integration**,
not a claim that the current feed branch implements them.

### Agreed product model (do not replace with a series bookmark entity)

- Extend the **same adjacent-series grouping experience** from Browse/Search
  to the posts shown inside an existing **Bookmark Group** timeline/browser.
  This is a follow-up to the initial feed integration, not a new bookmark type.
- Do **not** add a `Series` category to the Bookmark Browser, a dedicated
  series-bookmark repository, a `SeriesBookmark` record, or a separate saved
  series collection. Keep the existing post bookmarks and group memberships.
- A series entry in a bookmark timeline should look and behave like a normal
  bookmark-grid tile, with the subtle series/count affordance from the browse
  design. Tapping it opens the corresponding **series**, rather than treating
  it as a newly stored, synthetic bookmark. Preserve the source profile.
- Bookmark grouping is a **display-only projection** of the existing
  individually bookmarked posts. A user bookmarking a whole series is really
  bookmarking **every individual post in that series**; the viewer merely
  groups neighboring bookmarks automatically when displaying them.
- Apply grouping **after** the current bookmark target/group, site, search
  filters, blacklist/visibility rules and sort/shuffle have produced the
  displayed post order. Only adjacent qualifying posts in that exact order
  can merge. Never regroup by pool across intervening bookmarks, silently
  reorder bookmark results, create phantom posts, or store group positions.
- One saved series member is a normal bookmark tile. Two or more neighboring
  members of the same confirmed series form one tile. Count only **visible
  bookmarked posts in this run** (for example, `5 bookmarked posts`), not
  the entire pool's size. A series can legitimately appear in multiple runs.
- An individual bookmark stays individually removable, movable between
  existing groups, searchable, exportable, and selectable. Expanding the tile
  reveals the existing member bookmarks. Grid selection and bulk operations
  refer to these member bookmarks, never all remote series posts by accident.

### Whole-series bookmark action (existing records, not a new object)

- Expose a clear **Bookmark all posts in series** action from the series page
  or applicable series menu. It obtains the remote series members through the
  existing booru/profile identity and persists each eligible post as a normal
  bookmark in the selected/current bookmark group.
- This action targets the **whole series**, not merely the contiguous subset
  represented by a feed tile or the current search/filter results. Show the
  complete vs eligible/available count explicitly if they differ. Do not
  assume unavailable, inaccessible or unbookmarkable posts were saved.
- It must be **idempotent**, even if the series was partly bookmarked:
  existing bookmarks keep their stable identity, existing group memberships
  and any locally edited metadata; add only missing bookmark records and
  missing memberships in the requested target group. Never duplicate a post
  or overwrite its existing saved representation merely to add membership.
- A post already in the library but **not in the target Bookmark Group** is
  still missing from that group: add membership, not a duplicate bookmark.
  A post already in that group is a no-op. Bookmarks in unrelated groups
  remain untouched. Never infer completion from library-global counts alone.
- Reusing the existing bulk group-aware mutation code is preferred over a
  custom series persistence path. `BookmarkLibraryNotifier.addPostsToGroup`
  and `_addPostsToGroup` already distinguish existing post identities from
  newly created bookmarks and account for target-group membership. The
  convenience `addBookmarks` method skips globally saved posts and therefore
  is **not** sufficient for filling missing target-group memberships.
- Do not make a grouped tile's normal tap act as a bulk bookmark toggle.
  Tapping navigates; explicitly labeled actions mutate bookmarks. Avoid an
  ambiguous `Unbookmark series` toggle that could silently erase individual
  bookmarks a user saved before they chose the whole-series action.

### Partially bookmarked series: unresolved question and proposed UX

The older discussion explicitly raised the case where **some series posts
are already bookmarked** but did not settle the final UX. Preserve that as
an open decision, rather than presenting the proposal below as approved.

**Proposed default:** In the series view show per-target progress such as
`7/20 posts in this group`, with **Add 13 missing posts** as the primary
action. If all 20 are already in the target group, show **All 20 bookmarked**
without an additional write. If some are saved globally but not in this
group, include those as missing memberships, not as new bookmark records.
Recompute membership at commit time to tolerate concurrent changes.

Series bulk operations should report the number added, already present,
skipped, and failed. Where the existing rollback path can restore the
pre-operation state, reuse it; on error never remove bookmarks or memberships
that predated the action. Offer retry for missing items rather than blindly
replaying or reversing the entire series. If adding all may be expensive,
show the count before confirmation and use bounded fetching/progress.

**Still to settle during UX review:** whether the series view should later
offer a separately named **Remove this whole series from this group** action;
how offline/unresolvable series navigation should degrade (individual saved
posts must remain accessible); and how inaccessible, blacklisted or filtered
remote series members are counted and described during `Bookmark all`.
None of these questions justify a synthetic series bookmark entity.

### Integration points and acceptance criteria

- `lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart` currently
  transforms selected bookmarks into `Post`s, feeds them to `PostGrid`, and
  uses original post indices for details. Introduce the shared display-entry
  adapter there and maintain exact source indices when opening individual
  bookmarks or choosing/selecting/expanding a grouped tile.
- `lib/core/bookmarks/src/providers/bookmark_group_selectors.dart` defines
  the selected target, tag/site filtering and upload/bookmark-time/random
  sort. Group only *after* this projection; different sorts, searches and
  shuffled orders may produce different (or zero) grouped runs.
- `lib/core/bookmarks/src/types/bookmark.dart` already holds a saved post
  snapshot, and `bookmark_identity.dart` uses a normalized host plus stable
  post key. Reuse existing identities and `BookmarkGroup.bookmarkIds`;
  do not introduce another identity or a persistent series membership list.
- Reuse the feed's **confirmed series-only metadata resolver/cache** for
  saved post snapshots where an originating site/profile can be resolved.
  An old/offline bookmark whose source or membership is unavailable remains
  a normal bookmark tile; do not guess from tags or cross-site matches.
- Preserve auth/profile boundaries when looking up the series and opening
  its page. Never merge ambiguous origins, different sites, or similarly
  numbered series IDs from different sites. If profile resolution fails,
  keep the individual bookmark usable instead of presenting a broken group.
- Preserve existing bookmark view selection, range gestures, detail routing,
  undo/removal, group membership, export/import, and pagination behavior.
  No bookmark database migration is required merely to render groups.
- Add tests for: none/one/two/all series members saved; unrelated bookmark
  between members; filtered/sorted/shuffled results; two series with an
  overlapping member; partial membership in the active group vs global
  library; idempotent repeated Add missing; failure/rollback; removing one
  member without removing others; source/profile collisions; missing
  metadata/offline snapshots; selection/count/source-index stability;
  and opening the series then returning to the bookmark scroll position.

**Delivery order:** integrate Browse/Search first, then share its projection
and metadata resolver with Bookmark Group timelines and the explicit bulk
bookmark action. The bookmark behavior is part of the overall feature
requirements, but **not implemented by this initial commit**.
## Scope and verification

First integration: ordinary Danbooru browse/search. The agreed Bookmark Group
follow-up is specified above: **no separate series bookmark records/repository**;
individual post bookmarks remain the persistence model. Mixed Following feeds,
other engines, and persistent pool metadata are other follow-ups requiring
explicit origin and storage support. No database or bookmark migration is part
of this initial patch.

The new behavior tests cover adjacency, separated runs, unknown data/origins,
site/profile boundaries, multi-membership, invalid IDs, disabled grouping,
source indices/order, and an 8+12-post page seam. Integration needs additional
widget/controller tests for selecting/expanding runs, original viewer indexing,
blacklist/rating covers and counts, partial selection, manual/infinite paging,
underfilled pages, delayed failures, stale responses, and scroll restoration.

Use the complete local suite from `docs/engineering_guidelines.md`, plus narrow
width/enlarged-text UI checks. This environment has no FVM/Dart/Flutter SDK and
no complete local checkout; Dart formatting, Dart tests, analysis, and the
application/package/tooling suites have **not passed or been completed**. The
branch is an implementation start, not merge-ready. Browser prototype checks
are separate evidence and do not validate Flutter code.
