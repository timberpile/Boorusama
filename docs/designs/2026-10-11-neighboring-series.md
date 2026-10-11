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

## Scope and verification

First integration: ordinary Danbooru browse/search. Bookmarks, mixed Following
feeds, other engines, and persistent pool membership are follow-ups requiring
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
