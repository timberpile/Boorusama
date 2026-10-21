# Issue Publication and Pool Bookmark Refinements — 2026-10-21

This is a historical review record, not a parallel task tracker. GitHub issues are authoritative for subsequent status and scope. Keep this archive branch out of `develop`.

This supplements [the original review](2026-10-20-feature-and-bug-review-notes.md) and [the first follow-up](2026-10-21-feature-review-followup.md). The decisions below supersede conflicting older proposals. No application code, active feature branch, PR, or merge was changed.

## Authorized issue publication

The user explicitly authorized creating all already-agreed tickets. Eighteen new issues were created, with concise English descriptions and the reviewed labels. Existing #49 was revised, not duplicated; its current labels, assignment and implementation branch were preserved.

| Review item | GitHub issue |
| --- | --- |
| 1 | [#50 — Unify UI Labels and Icons](https://github.com/timberpile/Boorusama/issues/50) |
| 6 | [#51 — Format Topic Queries](https://github.com/timberpile/Boorusama/issues/51) |
| 8 | [#52 — Show Realbooru Video Badges](https://github.com/timberpile/Boorusama/issues/52) |
| 9 | [#53 — Fix Realbooru Image Prefetch](https://github.com/timberpile/Boorusama/issues/53) |
| 10 | [#54 — Find Pixiv Posts via Share](https://github.com/timberpile/Boorusama/issues/54) |
| 11 | [#55 — Undo Reversible Actions](https://github.com/timberpile/Boorusama/issues/55) |
| 12 | [#56 — Filter Cached Topic Posts](https://github.com/timberpile/Boorusama/issues/56) |
| 13 | [#57 — Add Post Original Quality](https://github.com/timberpile/Boorusama/issues/57) |
| 14 | [#58 — Remember Feed History End](https://github.com/timberpile/Boorusama/issues/58) |
| 15 | [#59 — Mark Pixiv as Experimental](https://github.com/timberpile/Boorusama/issues/59) |
| 16 | [#60 — Edit Topics with Tag Suggestions](https://github.com/timberpile/Boorusama/issues/60) |
| 18 | [#61 — Unify Bulk Download Notifications](https://github.com/timberpile/Boorusama/issues/61) |
| 19 | [#62 — Align Bookmark Downloads](https://github.com/timberpile/Boorusama/issues/62) |
| 20 | [#63 — Fix Scroll-to-Top Button Visibility](https://github.com/timberpile/Boorusama/issues/63) |
| 21 | [#64 — Refine Artist Page](https://github.com/timberpile/Boorusama/issues/64) |
| 22 | [#65 — Also Show Previews for Topics without Tracking](https://github.com/timberpile/Boorusama/issues/65) |
| 23 | [#66 — Modify Search from Posts](https://github.com/timberpile/Boorusama/issues/66) |
| 25 | [#67 — Fix View Options Bottom Spacing](https://github.com/timberpile/Boorusama/issues/67) |
| Existing issue | [#49 — Find on Other Profiles](https://github.com/timberpile/Boorusama/issues/49), revised to share its result interface with #54 |

The `performance` label is applied to #53 and #58. The archive-branch label catalog also records this cross-cutting label. No other existing issues were relabeled or assigned.

### Latest corrections

- **Review #24, profile icons: no issue.** The user considers it too small to track separately and explicitly rejects a dedicated icon cache. Keep the earlier source findings as context only; do not introduce a new cache subsystem.
- **Review #25 / GitHub #67:** investigate other sheets, panels and dialogs that consume the same navigation insets. Fix the shared cause and all confirmed affected consumers, not only View Options. Preserve real system/keyboard insets and avoid timeline jumps.
- Review #5 remains a design discussion, not a published implementation ticket. Review #2, #4 and #17 remain deferred; #3 is not planned and #7 was not a Following defect. Video startup prebuffering remains deferred.

## Review #5: current user requirements

- Use real Pool bookmarks alongside ordinary Post bookmarks in the same Bookmark Group. No separate Post/Series tabs or separate collection browser.
- Reuse the existing Danbooru Pool Gallery card rather than inventing another visual design.
- Persist a Pool reference and compact derived metadata, **not its individual members or a durable membership list**. Normal transient API responses and caches may still contain members while processing them.
- Store an aggregate set of member tags so Pools/Series can participate in local filtering. A small Series can be scanned once when bookmarked; do not crawl a pool with thousands of members.
- Do not add a dedicated **Bookmark Posts** action. Existing in-pool selection and bookmarking suffice; Select All retains its current loaded-post scope, without hidden full-pool fetching.
- For newest-upload sorting, use the newest member's upload date. For oldest-upload sorting, prefer the oldest member's upload date. The user permits a newest-date fallback if a clean oldest-date solution is not feasible.
- Automatic visual grouping is **Series only**, not arbitrary Collection pools. A collapsed Series displays the usual Pool card and the **whole Series member count**, independent of how many visible Posts it represents. Tapping opens the full Series.

These requirements revise earlier suggestions to store membership snapshots or add Bookmark All Posts. They also revise the old series design's visible-run-count badge. The active `feature/group-neighboring-series` branch was not changed.

## Existing components inspected

`lib/core/posts/pools/pool_grid_item.dart` already accepts a cover widget, title, nullable total, and tap callback. It displays the collection icon and total independently of the backing post list.

`lib/boorus/danbooru/pools/pool/src/widgets/pool_page_sliver_grid.dart` uses the Pool's `postCount` and existing detail navigation. This supports reusing the same presentation for explicitly bookmarked Pools and collapsed Series runs.

`lib/boorus/danbooru/pools/pool/src/types/danbooru_pool.dart` has Pool creation/update times and optional member IDs, but no aggregate member-upload date or aggregate tag set. Pool timestamps and narrative member order must not be mistaken for member upload extrema.

## Proposed bounded metadata strategy — not yet approved

Persist source identity, upstream Pool ID, category, cached title/cover/count, the aggregate tag set, a coverage indicator, observation time and optional oldest/newest member-upload dates. The stored data remains a reference with a summary, not a member snapshot.

For a small Series, fetch only member metadata within a fixed request/member budget. Union its tags and calculate both upload-date extrema in the same pass, then discard the member objects from this bookmark record. Do not download member media. A Series with ten posts is a straightforward example; the exact budget is still to be chosen.

For a large pool, do not paginate until completion. A bounded first page and already available metadata may produce a partial summary. Record `complete`, `partial`, or `unknown` coverage rather than calling a sample the full set. Network failure, inaccessible members, visibility rules and pool changes can also prevent completeness. Background filtering must not trigger a crawl or silently start network searches.

Large unindexed pools therefore cannot offer exact local tag filtering. This is an unavoidable information limit unless the server provides an aggregate or a direct query is intentionally made. The interface should disclose incomplete filtering, not claim either a complete match or a conclusive absence. Keep normal browsing of these entries available when no tag filter is active.

### Aggregate-tag semantics

A union implements **collection-wide** tag matching, not per-post conjunction:

- A Series whose first member has `red_hair` and second member has `blue_hair` has both tags in its union.
- A query requiring both tags can therefore match that Series even if no single member contains both.
- With complete coverage, `-video` rejects a Series if any indexed member is tagged `video`; it does not mean the Series contains at least one non-video image.
- With incomplete coverage, an absent tag is unknown. In particular, missing `video` in a sample is not proof that a negative `-video` condition is satisfied. Do not label such results verified matches.

The user requested a tag union; these semantics and the handling of unknown results still need explicit UX agreement. Reuse canonical tag handling, but do not apply aggregate tags as a replacement for per-post blacklist/rating checks. Covers and opened members must continue to honor source-profile visibility rules. An aggregate may become stale after member/tag changes; a refresh timestamp and bounded recomputation on an explicit refresh are preferable to accumulating tags forever. A Pool update timestamp alone may not detect retagging of member posts.

## Upload-date sorting without full indexing

Danbooru's documented query supports `pool:ID`, `order:created_at`, and `order:created_at_asc`, plus a result limit. Thus a candidate implementation can request one newest and one oldest accessible member, read `created_at`, and cache only those timestamps. Small fully scanned Series need no extra requests.

Examples, each with `limit=1`:

- `pool:123 order:created_at` — newest upload.
- `pool:123 order:created_at_asc` — oldest upload.

Official syntax reference: https://safebooru.donmai.us/wiki_pages/help%3Acheatsheet . This is documentation/source-based feasibility, not a live authenticated API test. Keep the current profile's access rules. Locally filtered extremes may require a bounded follow-up; do not make an unbounded scan to discover a visible extreme. On unsupported/failed queries, retain a known timestamp or mark the value unknown; never manufacture a date. Prefer the true extrema on Danbooru rather than using first/last Pool position or lowest/highest ID as a universal timestamp substitute.

Sort keys can be direction-specific: `newestMemberUploadAt` descending for Newest Uploads, `oldestMemberUploadAt` ascending for Oldest Uploads. Those lists need not be exact reversals, which follows the user's requested semantics. Date refreshes must not trigger one request per card on every rebuild.

## Same Series card, different underlying action targets

The same visible card and whole-Series count can represent either an explicitly saved Pool reference or a projection of adjacent saved Post entries. This must not create a saved Pool implicitly or claim that every member is bookmarked.

Example: three saved posts from a twenty-post Series collapse into the normal **Series · 20** card and open the complete Series. Removing the projected group must still affect only those three stored entries; selecting it must not silently target twenty remote posts. Removing an explicitly saved Pool reference must leave separately saved member Posts intact.

A candidate safe interaction is to expand projected runs into their actual Posts while entering selection mode; alternatively keep an accurate underlying-post selection count. This is still a UX proposal. Whole-Series gallery counts and selected-item counts describe different things. Keep the existing source boundary, adjacency and shared-Series checks; only the displayed card/count changes. Multiple Series memberships, an explicit bookmark plus a projected card for the same Pool, and unavailable metadata need deterministic, non-destructive behavior before implementation.

## Remaining design choices

1. The small-pool indexing budget and how partial/unknown tag coverage appears in filtered results.
2. Acceptance of collection-wide AND/negative-tag semantics.
3. Selection behavior for automatically collapsed Series while preserving the requested unified card presentation.

Do not create a second full-membership database, automatic synchronization job, new icon cache, or a Bookmark Posts action to resolve these questions.
