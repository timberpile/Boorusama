# #134 — One Related Card per Family and Global Related Preference

Issue: https://github.com/timberpile/Boorusama/issues/134
Implementation branch: feature/134-related-timeline-groups
Source inspected: origin/develop at 4542aaa44e5002f7d546fb4ec96bf4cb0523cee5 (includes #144) and the existing #134 branch one commit ahead, 2026-11-18.
Status: owner-approved design/technical handoff. These instructions supersede the older five-result/two-member Related contract in the initial #134 implementation. They are not a tested patch.

Preference revision, 2026-11-18: the owner replaced the temporary combined switch with a persisted global **Group Related Posts** preference, default **OFF**. Series remains automatically grouped. See [global preference implementation and verification](134-global-related-grouping-2026-11-18-results.md); the revised items below supersede the former toggle contract.

## Accepted UX contract

1. On ordinary Danbooru Search and Artist timelines, a single Post with **verified direct parent/child relationship evidence** is sufficient to display a Related card. Do not require another matching Post in the currently loaded results.
2. The first eligible raw Post owns the group's cover, stable timeline position and viewer occurrence. Every later raw Post belonging to that same direct family is represented by the **same existing card**, regardless of the distance or page boundary. Its raw result is retained for selection, source pagination and raw-index/Viewer mapping; only the duplicate display tile is suppressed.
3. **Series priority remains unchanged.** Series keeps its existing rolling five-result lookahead and may recur after long gaps. Related alone uses an unbounded already-seen-family registry. Do not merge recursive ancestor trees; parent/direct children/siblings use the existing #139 RelatedFamilyReference anchor.
4. Reuse the current Series/PoolGridItem card styling and distinct Related icon. Use the first grouped Post thumbnail. If an authoritative complete-family count is **already cached and access-valid**, show that one total beside the icon. **If unknown, show only the Related icon, no number, question mark, partial count, or X/total ratio.** Do not start family requests solely to obtain a count.
5. Card tap opens the complete accessible Related family through the shared mixed viewer and its normal member pagination. Do not build a partial inline viewer.
6. Provide **Group Related Posts** in global Appearance settings and supported Timeline View Options. Both switches change the same **persisted global** value, **OFF by default**. OFF expands Related families and restores their individual Related thumbnail icons while Series remains automatically grouped; switching does not refetch, change the query, modify Bookmarks, or alter raw controller items.
7. Preserve this global choice across queries, source/profile/controller changes, viewer/Back and Selection Mode. Selection Mode and explicit family/Series searches show raw Posts regardless of the preference. Hide the timeline switch where Related grouping is unsupported; keep the global setting available independently of profile listing overrides.
8. Preserve the current visible raw Post/representative as the scroll anchor as far as practical when toggling; no large unexpected jump or reset to top. At normal list top, keep normal scroll behavior.

## Evidence and relevant code

- lib/core/posts/listing/src/types/neighboring_timeline_groups.dart: currently runs groupNeighboringSeries twice, once for Series, then for Related with the same five-result window. Change the **Related pass only**.
- lib/core/posts/listing/src/types/neighboring_series.dart: has the existing Series rolling lookahead and asUngrouped projection; preserve this behavior and its tests.
- lib/core/posts/related/related_family.dart: RelatedFamilyReference.fromPost(post) returns an anchor for **any valid Danbooru Post**, including a Post with no known relationship. Thus it is **not itself proof** of relatedness. Require a positive/valid parentId and/or the existing Post.hasParentOrChildren evidence before creating a singleton Related card. Preserve source/profile restrictions.
- lib/core/posts/post/src/types/post.dart: exposes parentId and hasParentOrChildren.
- lib/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart: _posts is the raw controller list; _display is its projection; frozen entries and _lastFrozenFirstIndex preserve already built tiles. _syncProjection already detects refresh, replacement and relevant widget context changes. Reuse these rather than maintaining a separate persistent cross-route registry.
- The same grid currently passes total: _knownRelatedCount(family) ?? entry.posts.length to PoolGridItem. For this revised UX, pass an access-valid cached total only; when null, leave displayedCount null as well so the badge renders the icon alone. Keep the separate Series label/count behavior.
- Inspect the existing View Options sheet and reusable Kurumi settings/switch controls before wiring the toggle. Do not revert the narrow-screen/scaled-text layout improvements or redesign unrelated toolbar groups.
- docs/handoffs/134-related-timeline-verification.md on the implementation branch describes the **previous** implementation and its targeted tests. Preserve it as historical verification evidence; record the new implementation and verification separately.

## Narrow implementation model

The raw controller items are the single source of truth. On a projection pass:

- Compute/retain Series memberships first with the **existing** bounded Series algorithm, honoring frozen cards and existing metadata timing.
- Seed a **temporary**, projection-local map from (source/account scope, Related family anchor) to the first already-built Related entry. This may be reconstructed from the raw list and frozen displayed entries on every projection; it does not need storage/database or a long-lived mutable registry.
- Walk eligible, not-Series-claimed raw Posts in order. Unrelated Posts remain ordinary; the first related Post of a family creates a Related entry, subsequent ones append their raw indices to that entry instead of adding another visible card.
- Keep every raw index represented exactly once by the resulting display mapping (as a single Post, Series, or Related member). Do not steal a previously frozen ordinary, Series or Related tile after delayed metadata arrives.
- Previously rendered cards are immutable in identity/position/thumbnail. New matching Related members can extend their member-index lists and remain hidden as separate tiles.
- For a route/query/profile/sort/filter replacement, rebuild from its current raw source and clear the old session projection while retaining the global preference. A Related preference change rebuilds Related entries without clearing the raw list, refetching, or rearranging frozen Series cards.
- Do not use an O(n^2) scan of all prior members. Building the temporary family map is O(number of loaded raw Posts) for the pass; reused frozen entries must not double-claim indices.

This is a proposed algorithmic shape, not a drop-in code implementation. Retain existing source/security checks, actor-scoped metadata, continuation budgets and tests. If a stable immutable-first projection requires a small helper, prefer that over keeping multiple mutable registries in widget state.

## Series timing example

A child Post is presented as a Related card using a verified parentId. An asynchronous pool metadata lookup later reveals that it also belongs to Series 42. Do **not** move the already visible Related card into Series, because doing so would change its placement/identity and break scroll/viewer mapping. Series takes priority when grouping new, not-yet-fixed entries with already available metadata; frozen choices stay stable. This unavoidable timing limitation must be covered by a deterministic test.

## Verification for the local agent (short automated checks only)

- One eligible child or parent-with-children yields one Related card; an unrelated Danbooru Post remains ordinary (fromPost alone must not group it).
- Siblings/parent arriving arbitrarily far apart and across page boundaries collapse into the first representative; verify first thumbnail/identity, member raw indices and at-most-once display.
- Parent with its own parent and children preserves direct-family anchoring; no recursive family merge, no cross-profile/source/account aggregation.
- Series keeps its five-result window and priority, including delayed metadata and frozen Related/ordinary entries.
- Authoritative cached count renders icon + total; unknown count renders **icon only**, including a one-member displayed group. No family-count network request.
- Related defaults OFF. Both global and timeline switches persist the same preference; OFF expands only Related and preserves Series. Same raw source and no refetch; selection/explicit family searches remain raw, and the global choice survives query changes, viewer/Back and Selection Mode.
- Toggle at mid-scroll preserves a meaningful anchor, restores viewer/Back position, and works with narrow width and enlarged text.
- Pages collapsing to no newly visible cards still permit bounded automatic continuation and manual Load More. Preserve cancellation, refresh, errors and profile isolation.
- Verify source/Viewer navigation, no lost/duplicated raw indices, and the separate Series representation. Do not run long live/API/emulator suites; the owner performs Android acceptance.

No DB schema or public API changes, and no work on future #176 media-first/group Timeline viewer UX, are authorized under #134.
