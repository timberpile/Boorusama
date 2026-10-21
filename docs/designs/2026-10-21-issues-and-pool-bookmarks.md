# Issue Publication and Pool Bookmark Refinements — 2026-10-21

This is a historical review record and agreed design reference, not a parallel task tracker. GitHub issues are authoritative for subsequent status and scope. Keep this archive branch out of `develop`.

This supplements [the original review](2026-10-20-feature-and-bug-review-notes.md) and [the first follow-up](2026-10-21-feature-review-followup.md). The decisions below supersede conflicting older proposals, including the earlier partial-index handling and the Series branch's visible-run-count and selection rules. No application code, active feature branch, PR, or merge was changed.

## Previous issue publication round

The user explicitly authorized creating all already-agreed tickets. Eighteen new issues were created in the first publication round, with concise English descriptions and the reviewed labels. Existing #49 was revised, not duplicated; its current labels, assignment and implementation branch were preserved.

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

### Disposition of the other review topics

- **Review #24, profile icons: no issue.** The user considers it too small to track separately and explicitly rejects a dedicated icon cache. Keep earlier source findings as context only.
- **Review #25 / GitHub #67:** investigate other sheets, panels and dialogs consuming the same navigation insets. Fix the shared cause and confirmed affected consumers, not only View Options. Preserve real system/keyboard insets and avoid timeline jumps.
- **Review #5:** the final user clarification resolves partial-index filtering, selection-mode ungrouping and the Pool/Series Bookmark button. The agreed outcome is now ready for an implementation issue under the user's existing publication authorization.
- Review #2 (viewer transition), #4 (local profile icons) and #17 (Android SAF download locations) remain deliberately deferred. #3 is not planned; #7 was not a Following defect. Video startup prebuffering remains deferred.

## Review #5: agreed scope

- Save real Pool/Series bookmarks alongside ordinary Post bookmarks in the same Bookmark Group. No separate Post/Series tabs or separate collection browser.
- Reuse the existing Danbooru Pool Gallery card, including title, cover, category indication and whole-Pool member count. Tapping opens the full remote collection under its originating profile.
- Add a visible **Bookmark** button to Pool and Series detail views. Use the existing Bookmark Group selection and membership conventions for the Pool reference itself, independently of member-post bookmarks.
- Persist a Pool reference and compact derived metadata, **not its individual members or a durable membership list**. Transient API responses and ordinary caches may contain members while processing them.
- Keep references editable, groupable, removable and exportable/importable. Preserve source identity and profile isolation; never export credentials. Removing a Pool reference must not remove separately saved Posts or files.
- Do not add a dedicated **Bookmark Posts** action. Existing in-pool selection and bookmarking suffice. Select All retains its loaded-post scope without hidden full-pool fetching.
- For Newest Uploads, use the newest member's upload date. For Oldest Uploads, prefer the oldest member's upload date. The user permits a known-newest-date fallback where a clean oldest-date solution is unavailable.
- Automatic visual grouping is **Series only**, not arbitrary Collection pools. A collapsed Series displays the usual Pool card and the **whole Series member count**, independent of how many visible Posts it represents.

This supersedes earlier suggestions to store membership snapshots, add Bookmark All Posts, or require a separate Series library. The active `feature/group-neighboring-series` branch is not modified by this review; its earlier design must be reconciled with these decisions before integration.

## Existing components inspected

`lib/core/posts/pools/pool_grid_item.dart` accepts a cover widget, title, nullable total, and tap callback. It displays the collection icon and total independently of the backing post list.

`lib/boorus/danbooru/pools/pool/src/widgets/pool_page_sliver_grid.dart` uses the Pool's `postCount` and existing detail navigation. Reuse that presentation for explicitly bookmarked Pools and collapsed Series runs.

`lib/boorus/danbooru/pools/pool/src/types/danbooru_pool.dart` has Pool creation/update times and optional member IDs, but no aggregate member-upload date or tag set. Pool timestamps and narrative member order must not be mistaken for member upload extrema.

## Bounded metadata and local filtering

Persist source identity, upstream Pool ID, category, cached title/cover/count, an aggregate tag set, an indexing coverage indicator, observation time, and optional oldest/newest member-upload dates. This remains a reference with a summary, not a member snapshot.

For small Series, fetch member metadata once when bookmarking within a fixed request/member budget. Union the tags and calculate both upload-date extrema in the same pass, then discard member objects from the bookmark record. Do not download member media. Ten posts is an example of a small Series, not a mandatory final threshold.

For large Pools, use a bounded sample and already available metadata. Do not paginate until completion. Record `complete`, `partial`, or `unknown` coverage; failures, inaccessible members and remote changes can also prevent completeness. The exact budget is a bounded implementation choice, not a reason to delay the feature design.

**Final user decision: filter every Pool against its currently stored tag set, even when indexing is incomplete.** Do not keep a nonmatching Pool visible merely because an unindexed member might contain a requested tag. Filtering itself must not fetch more pages or trigger a remote search.

For positive required tags P, excluded tags N and stored tag union T, use the normal local rule: P is a subset of T, and N has no intersection with T. Thus:

- A required tag missing from T excludes the Pool, even if an unindexed member might contain it. This may miss remote matches.
- A forbidden tag present in T excludes the Pool.
- A forbidden tag absent from T does not exclude the Pool, even with partial coverage. This is a known-data filter, not proof that the remote collection lacks that tag.
- With no active tag constraints, partial or unindexed Pools remain normally browsable. Unknown/empty summaries do not bypass active positive filters.
- Multiple required tags may occur in different members. For example, red hair in one member and blue hair in another puts both tags in the collection's union. This is collection-wide matching, not per-post conjunction.

**Document this limitation in both feature documentation and concise user-facing filter help.** Suggested explanation: “Pool filters use indexed member tags. Large or partially indexed Pools may not reflect every member.” Keep coverage metadata available without making every filter interaction show a blocking warning. An incomplete index must not create a special always-visible results group.

Use canonical tag handling, but never use this approximate aggregate as a replacement for per-post blacklist, rating or authorization checks. Covers and opened members still honor the source profile's visibility rules. Store observation time and recompute within budget when explicitly refreshed; do not accumulate stale removed tags forever or introduce automatic synchronization. A Pool update timestamp alone may not detect member retagging.

## Upload-date sorting without full indexing

The previous investigation identified Danbooru's `pool:ID`, `order:created_at`, and `order:created_at_asc` queries with a result limit as a candidate for fetching one newest and one oldest accessible member, then caching only the timestamps. Small fully scanned Series need no extra date requests.

Examples, each with `limit=1`:

- `pool:123 order:created_at` — newest upload.
- `pool:123 order:created_at_asc` — oldest upload.

Official syntax reference: https://safebooru.donmai.us/wiki_pages/help%3Acheatsheet . This remains documentation/source-based feasibility, not a live authenticated API test. Keep the current profile's access rules. Locally filtered extremes may require bounded follow-up; never crawl the whole Pool for a visible extreme. On unsupported/failed queries, retain a known date, use the agreed fallback, or mark the value unknown. Do not manufacture a date or substitute first/last narrative position.

Sort keys are direction-specific: newest member upload descending for Newest Uploads, oldest member upload ascending for Oldest Uploads. These lists need not be exact reversals. No per-card network requests on rebuild or sorting.

## Series grouping and selection

The same card and whole-Series count can represent either an explicitly saved Pool reference or a projection of adjacent saved Post entries. A visual projection must not create a Pool bookmark implicitly or imply that all remote members are bookmarked.

Three saved posts from a twenty-post Series collapse into the normal **Series · 20** card. Tapping opens the complete Series.

**Final user decision: disable visual grouping while selection mode is active.** Expand projected runs into their original Posts before resolving selection targets. Preserve their order, filters and origin; selected counts and bulk operations refer only to actual selected entries. Leaving selection mode may restore the projection.

An explicitly bookmarked Pool remains one independently selectable reference in selection mode; it must not expand into an implicit selection of remote members. Removing it leaves separately saved member Posts untouched. Existing post-only operations must not silently download, bookmark or delete an entire Pool.

Keep source boundaries, adjacency and confirmed common-Series membership. Explicit Pool bookmarks and independently saved Posts may coexist. Handle duplicate projections, missing metadata and multiple Series memberships deterministically without deleting or silently reassigning stored entries.

## Review conclusion

The requested product behavior is settled. Metadata budget, codec changes and component wiring remain implementation details. No new icon cache, full-membership database, synchronization job, separate type tabs or Bookmark Posts action is required.
