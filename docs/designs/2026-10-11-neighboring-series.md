# Neighboring Series and Pool Bookmarks — Current Scope

Issue: [#68 — Bookmark Pools and Series](https://github.com/timberpile/Boorusama/issues/68).
Branch: `feature/group-neighboring-series`.
Reconciled during the 2026-10-24 branch review.

## Status and authoritative decisions

This branch contains a pure grouping projection and its tests, **not an
integrated feature**. The current issue and the
[2026-10-21 agreed scope](https://github.com/timberpile/Boorusama/blob/0d2cbfc6bd09c0d26789d24552ca496855791b53/docs/designs/2026-10-21-issues-and-pool-bookmarks.md#review-5-agreed-scope)
supersede the earlier proposal in this file. The
[historical proposal](https://github.com/timberpile/Boorusama/blob/03aa7860529ac1928e3e5874259870c9bc3a9646/docs/designs/2026-10-11-neighboring-series.md)
is retained in Git history, not as implementation instructions.

In particular, do not carry forward its prohibition of saved Pool references,
visible-run count badge, grouped selection model, or dedicated Bookmark All
Posts action. Those conflict with the later explicit decisions.

## Approved behavior

Save explicit Pool/Series references alongside individual Post bookmarks in the
same Bookmark Group. Reuse existing group selection/membership conventions and
add a visible Bookmark button to Pool and Series detail views. Do not introduce
separate type tabs or a separate collection browser.

Reuse the existing Pool Gallery card, including title, cover, category and
**whole-Pool member count**. Tapping opens the full collection using its source
profile. A projected run of three saved Posts from a twenty-post Series is a
normal Series card with count 20, not a claim that twenty Posts are bookmarked.

Persist a reference and bounded aggregate metadata, not member snapshots or a
durable membership list. Keep source identity, group membership, edits and
export/import compatible with existing data; never export credentials. Removing
a reference must not remove separately saved member Posts or downloaded files.
There is no dedicated Bookmark Posts action or hidden full-pool scan. Existing
in-pool selection retains its loaded-post scope.

Automatically group only adjacent Posts with confirmed common **Series**
membership, never arbitrary Collection pools. An explicit Pool reference and
individually saved Posts may coexist; a visual projection must not create a
stored reference implicitly.

**Selection mode disables visual grouping.** Restore projected runs to their
original Posts before resolving selection indices, counts and bulk operations.
An explicitly saved Pool remains one independent selectable reference and never
expands into an implicit selection of remote members.

## Bounded summaries, filtering and sorting

Use a fixed request/member budget and existing metadata to obtain cached
identity/title/cover/category/count, aggregate tags, coverage and observation
time, plus optional oldest/newest member upload dates. Process small collections
within budget; sample large ones without crawling to completion. Transient API
responses may contain members, but persisted summaries must not retain them.

Filter every Pool against its stored tag union, even when coverage is partial
or unknown. Required tags must be present and excluded tags must be absent.
Do not retain a nonmatching Pool because unindexed members might match, and do
not fetch while filtering. With no tag constraints, unindexed references remain
browsable. Document that matches concern indexed tags and that required tags
can occur in different members; incomplete coverage can miss remote matches
and cannot prove an excluded tag absent from every remote member. Aggregate
filtering never replaces per-post blacklist, rating or authorization checks.

Newest Uploads uses newest member upload descending; Oldest Uploads uses oldest
member upload ascending. A known-newest fallback is permitted when obtaining
oldest is not practical. Retain unknown when no legitimate date is available;
Pool creation/update time and narrative member order are not upload extrema.
Use bounded verified queries or already processed members, not per-card calls
on rebuild/sort. Cache only the resulting summary and respect source access.

## Retained grouping primitive

`groupNeighboringSeries` in
`lib/core/posts/listing/src/types/neighboring_series.dart` remains a compatible
presentation primitive. It accepts an already filtered, ordered Post list and
confirmed Series IDs scoped by normalized site, profile and auth context.
Unknown membership/origin stays ungrouped. It uses the longest common-Series
prefix with smallest-ID tie breaking, so `A, A+B, B` is not one three-post run.
It never reorders or drops Posts, and `firstIndex` retains source addressing.

`entry.posts.length` is the run's source-post count, **not** the card's total
Series count. Obtain the latter from confirmed Pool metadata. Pass
`enabled: false` in selection mode. Keep the original Post list as controller
truth; the projection does not resolve metadata, persist bookmarks, paginate,
manage selection, or preserve scroll anchors by itself.

Integrate at the display-entry boundary rather than hiding duplicate grid
items. Preserve filtering, source indices, raw-post pagination, viewer routing,
range selection and scroll restoration. Bound metadata work outside widget
builds, coalesce requests by source identity, and reject obsolete results.
Freeze already displayed entries during deferred resolution rather than making
visible tiles jump. Extending a tail run on append must preserve its anchor;
numbered pages remain independent. Bound underfilled-viewport auto-fetching.

## Verification and next implementation

The primitive and existing tests were reviewed statically. No FVM formatting,
analyzer, Dart/Flutter tests or Android/device checks ran in this review. No
runtime defect was identified in the pure projection; it is not wired into the
app. The existing tests cover order/indices, adjacency, shared membership,
source boundaries, invalid IDs, disabled grouping and page seams.

Read current `AGENTS.md`, Issue #68 and `docs/post_architecture.md` before
implementation. Reconcile this older branch with current develop in an isolated
worktree, preserving unrelated work. Implement reference persistence/codecs,
source-aware Pool navigation, bounded summaries and the shared card/selection
integration as the issue requires. Add consumer and migration tests covering
explicit references vs projected Posts, partial tag coverage including
exclusions, both upload-date sorts, missing/offline metadata, source collisions,
selection-mode expansion, removal/Undo, export/import and page/scroll stability.
Do not present the helper alone as completing #68 or merge the historical
maintenance archive into develop. Full final-candidate regression remains
required before any separately authorized integration.
