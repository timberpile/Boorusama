# Cross-branch findings

### AA02-A03-F0002 — Mixed Pool/Bookmark list ignores new score ordering

- Kind / severity / confidence / lifecycle: **risk / medium / high-confidence / open**
- Affected: issue #68 / T009 branch `feature/group-neighboring-series`; issue #107 / T014 branch `feature/107-local-post-sorting`
- Origin: **interaction**, not an independently failing existing target head
- Pinned T009 head/base: `771082d9c58363348d74b97a2da23732cdd921f0` / `482ae4b1e5fd1e34b344a5c61959a210b8527281`
- Pinned T014 head/base: `7a73544cb79c9f5e3c2337a08140833024a31591` / `422aeae087c1108e655d85d1a3dac25120456cd6`
- Locations: `lib/core/bookmarks/src/types/bookmark_grid_entry.dart:87–121` (T009), `lib/core/bookmarks/src/providers/bookmark_group_selectors.dart:11–20,202–214` (T014)
- Pinned evidence: [T009 mixed sort implementation](https://github.com/timberpile/Boorusama/blob/771082d9c58363348d74b97a2da23732cdd921f0/lib/core/bookmarks/src/types/bookmark_grid_entry.dart#L87-L121); [T014 new score sort cases](https://github.com/timberpile/Boorusama/blob/7a73544cb79c9f5e3c2337a08140833024a31591/lib/core/bookmarks/src/providers/bookmark_group_selectors.dart#L11-L20); [T014 Post-only comparator](https://github.com/timberpile/Boorusama/blob/7a73544cb79c9f5e3c2337a08140833024a31591/lib/core/bookmarks/src/providers/bookmark_group_selectors.dart#L202-L214)

#### Expected versus observed source behavior

Issue #107's new score ascending and descending modes should sort the bookmark grid by score (and define a predictable order for Pool entries). The T014 changed Post-only `selectBookmarks` comparator implements score sorting, but T009's mixed `selectBookmarkGridEntries` applies a **second** sort as soon as any Pool reference is included. The second sort recognizes only random, upload date and saved date; both new score cases fall into `savedAt`, overriding the previously sorted Post result.

#### Trigger and reachable failure path

After combining both branches without modifying that mixed-grid comparator, open Bookmarks with at least one Pool reference and multiple individual Post bookmarks, select Score Descending or Ascending. `selectBookmarkGridEntries` calls the correct Post score selector but then mixes Pool entries and sorts **all** by saved date, ignoring the selected score direction. Posts with conflicting score/date rankings visibly reverse. With no Pool references the early return at line 98 preserves correct score ordering, masking the defect in Post-only tests.

#### Evidence and safeguards checked

Checked the exact static enumeration of `BookmarkSortType` in T014, the T009 mixed grid's early return, random fallback and date-only comparator, and the Post-only score comparator/tie handling. The T014 unit test exercises only Post-only `filterBookmarks` / cover previews, not T009's mixed projection. T009 tests were authored before the new enum cases. No integrated worktree/build was available to confirm resultant runtime behavior.

#### Root cause and practical impact

Independent branches extended the same sorting concept through different layers; their individually valid fallback logic does not compose. A user selecting score sort sees a misleading date-sorted mixed library whenever Pool references exist. Medium UX correctness risk conditional on integration.

#### Minimal recommended correction

In the **combined** candidate, explicitly handle score ascending/descending in `selectBookmarkGridEntries`; choose and document a deterministic score rule/placement for Pool references that have no per-Post score, while keeping both regular Posts and group preview ordering consistent. Prefer a shared comparator/score extraction over duplicate logic. Do not simply skip mixed sorting: Pools still need a defined place.

#### Suggested local verification and regression checks

Create a mixed grid fixture (2 Posts with different scores and saved times + 1 Pool) and assert both score directions, sorted Post-only behavior, random and upload/date modes, and selection identity. Run FVM analyzer/tests after stacking/merging #68 and #107. Verify source/profile filters and group preview consistency.

#### Assumptions and remaining uncertainty

This is a **cross-branch projected failure**, not a claim that current `develop` exhibits it. Without an actual integrated revision, confidence is high rather than `static-confirmed`. If the integration implements a new explicit mixed-score comparator, mark this finding resolved at that commit.

#### History

- 2026-10-29T23:03:08.837Z: independently discovered by reconciling pinned T009 and T014 source, open pending combined implementation.
