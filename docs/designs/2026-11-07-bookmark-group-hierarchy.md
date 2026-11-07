# Unified local Bookmark Group hierarchy

Issue: [#158](https://github.com/timberpile/Boorusama/issues/158). Approved product direction, 2026-11-07. This document specifies the implementation target, not existing runtime behavior.

Implementation: [stage 02a](../plans/content-architecture/02a-bookmark-hierarchy.md). Delivery and continuation: [local-agent handoff](../handoffs/158-bookmark-hierarchy-insertion.md).

## 1. Baseline and precedence

The dependent branch is `feature/158-unified-bookmark-hierarchy`, based on `maintenance/155-unified-bookmark-storage` at `f6deb27590a38a812c532c939085742886cdda3f`. Its runtime/test candidate is `6b390c611b5dc4b4dcf8356172635fd698356678`; the later two commits add only the [#155 handoff](../handoffs/155-unified-bookmark-storage.md). That handoff reports complete regression and independent Astra High approval of the exact runtime candidate, with explicit native-test limits. These are predecessor evidence, not verification of #158.

Current source has already implemented the ID-only `Bookmark` interface, typed records, a shared durable uint32 allocator, indexed library mutations, a shared storage journal, active organization generation v2, and backup v10. Do not repeat or undo that work. Local organization still has `CollectionFolder`, `BookmarkGroup.folderId`, and a separate folder list. The v10 codec still transfers that organization. The new hierarchy is not yet implemented.

The original rollout reference is `maintenance/content-architecture-design` at `fdb68f657284e1f76701c83683aa0228484d09c8`. Its plan documents are not inherited by the #155 branch. Read them from that reference; do not merge the entire older planning branch to obtain documentation.

This approved addendum supersedes only the earlier local folder/group separation, the placement/search decisions for that local browser, and the missing hierarchy stage. It does not change remote Content Group identity, source loading, Work/Page separation, or the deferred Related viewer. Runtime evidence takes precedence over outdated descriptions of what #155 has implemented. Preserve all unrelated requirements in the original contract.

## 2. Scope and boundaries

Use one nestable local `BookmarkGroup` model. Each ordinary group may contain direct Bookmark memberships and child groups. A former folder becomes a group with initially no direct Bookmark memberships. There is no persistent `isFolder`, optional folder-to-group conversion, or second group type.

Keep these concepts separate:

- A local `BookmarkGroup` organizes the user's library and is identified by its existing UUID.
- A `Bookmark` is a saved record with a local integer ID, including Post, native Content Group, Related, and supported legacy records.
- A remote `ContentGroupBookmark` is one saved item, not a local child folder. Recursively displaying local groups never expands a saved Pool, Work, Related Family, or Gallery into its remote members.
- `All` is a library-wide read view, not a writable group or persisted parent. Home is navigation, not an implicit Bookmark target.

Favorites Sync remains additive/non-destructive under #132 and targets one explicit group's direct memberships. Do not implement mirror sync, ownership locks, server writes, or recursive destructive synchronization. #144's folder-sync feature remains separately owned; coordinate its changed organization contract rather than implementing it here. Following Topics may still use the shared `CollectionFolder` utilities. Remove them from Bookmark's canonical model, not globally from unrelated features.

## 3. Data and view contracts

These are field contracts for adapting the existing classes, not a request for parallel repositories or a broad new framework.

```text
BookmarkGroup (adapt existing)
  id: String                         // stable local UUID; names are not identity
  name: String                       // user-facing display name
  parentGroupId?: String             // one parent; null means Home
  position: int                      // sibling order, independent of content sorting
  bookmarkIds: Set<int>              // direct saved-record IDs only
  addedAt: Map<int, DateTime>        // exact direct-membership dates in UTC
  systemRole [derived from id]        // preserve the existing Default identity

BookmarkGroupTree (derived, immutable)
  groupsById: Map<String, BookmarkGroup>
  childrenByParentId: Map<String?, List<String>> // ordered direct children
  ancestors(groupId) -> List<BookmarkGroup>
  subtreeIds(groupId) -> Set<String> // includes group itself
  validate()                         // identity, parent existence, cycles, placement

BookmarkGroupViewMode
  structure                          // child cards above direct bookmarks
  allBookmarks                       // local subtree bookmarks, deduplicated

BookmarkGroupViewPreferences (local settings contract)
  modesByGroupId: Map<String, BookmarkGroupViewMode>
                                      // per device, keyed by stable UUID

BookmarkView (adapt existing validated constructors)
  kind: BookmarkViewKind             // all, group, subtree
  groupId?: String                   // required for group/subtree, absent for all
  // .group(id) remains direct; add .subtree(id); .all() remains library-wide.

BookmarkSubtreeProjection (derived, not persisted)
  groupId: String
  includedGroupIds: Set<String>
  bookmarkIds: Set<int>              // union using canonical local integer IDs
  earliestAddedAt: Map<int, DateTime>
  latestAddedAt: Map<int, DateTime>
```

Use validated constructors and immutable values, keeping existing equality/selector conventions. Include the view kind in provider/cache keys. `BookmarkTarget.group(id)` remains a direct write target. Neither an aggregate `BookmarkView` nor a `BookmarkGroupViewMode` authorizes recursive mutation.

Do not persist descendant memberships or child-ID arrays alongside `parentGroupId`. Parent pointers are authoritative; indexes are derived. Validate a finite acyclic forest using iterative traversal, including deeply nested imports. Reject self-parenting, missing parents, moving into a descendant, and invalid placement before committing. Names need not be unique: existing group names and folder/group name collisions must survive conversion without merging unrelated nodes.

Default retains the nil UUID and its existing root placement, protection from rename/delete/move, direct membership semantics, and orphan/import policy. Do not infer its role from the name. It does not become the parent of the root hierarchy. Preserve special Home entries and the distinction between Default and All. Children, where permitted by the existing system-group policy, do not alter Default's direct membership behavior.

### Display mode persistence

Every group remembers its explicit mode across app restarts. Rename and move preserve it. Use the existing suitable local settings/misc-data mechanism; no new database layer. Keep this preference out of Bookmark transfer, full backups, and sync, including any generic settings export that might otherwise capture it.

Default to Structure when there is no preference. With no children, hide the mode control and show the ordinary direct-bookmark timeline, but do not erase the saved preference. If children appear again, the previous preference applies. Group deletion cleans up its local preference after successful persistence; Undo may restore it. Import Replace must not accidentally apply a deleted node's preference to an unrelated new identity.

## 4. Unified Group screen

Use one Group route/screen rather than separate folder-only and bookmark-only pages. Retain Kurumi components, theme surfaces, density, typography, navigation, and source/selection behavior. The interface is intended for one-handed thumb use, not a desktop tree-control redesign.

### Header

- Keep standard Back in its leading location, the group title, a compact view-mode control, and existing appropriate overflow actions.
- Make the title a discoverable, accessible navigation control (a small dropdown indicator is appropriate). It opens a Kurumi ancestor menu containing Home and the path of ancestors. The current group can be shown as the selected context, not a route-pushing duplicate.
- Picking an ancestor returns directly to that level. Do not accumulate a history loop by pushing another copy of an ancestor route. Normal Back goes up one group level, then exits at Home according to existing navigation ownership.
- Remove the permanent breadcrumb row from the normal Group browser. The clickable title replaces its ancestor-jump function.
- Place the Structure / All Bookmarks switch in the Header, not in its own row. It must communicate the current mode and offer a clear action/tooltip/semantics label. Do not hide the only mode control solely in overflow.
- Remove the separate group-name filter and its Header search button from this browser. Keep Bookmark content/tag search and unrelated app search intact.
- Hide mode switching for groups without children. The Header must still fit at narrow width and enlarged text without reducing targets to tiny icons or introducing custom title-fitting rules contrary to Kurumi.

The picker is a separate compact surface. Its existing Back/path and Add Group header row remains; removing the normal browser breadcrumb does not remove the picker's orientation header.

### Structure

The vertical order is:

```text
Kurumi Header: Back | clickable group title | mode | overflow

Immediate child-group cards
Immediate child-group cards (more rows as needed)

Compact spacing / subtle semantic divider
Rounded Bookmark search field and selected-tag chips
Existing timeline sort / source filter / count / grid controls
Direct Bookmark timeline (Posts and saved remote Group cards)
```

Only immediate local children appear as cards. Their previews may describe their own contents using the existing safety policy, but they are not search results for the parent's content query. Search, autocomplete, source filters, counts, sorting, shuffle, and Bookmark selection below the cards operate on direct memberships only. Do not filter or reorder the child cards when a Bookmark tag query is entered. Navigating into a child changes the local group context, not a source API query.

Reuse the existing rounded search surface, controls, and grid. Separate the child-card block from the timeline with ordinary semantic spacing and, if needed, one subtle divider. Do not add a large section banner, second AppBar, fixed breadcrumb, or a third scope switch. A localized scope-specific search hint (for example, "Search bookmarks in this group") may make the boundary explicit without another row.

If the direct-membership set is genuinely empty, show a compact local empty state below the child cards. Do not show an unusable toolbar solely to reserve height. If a query or filter reduces an existing direct-membership set to zero, keep the active search/filter controls and a clear no-results state so the user can recover. Do not decide true emptiness from the filtered result count. Navigation and Add Group remain reachable in both cases.

### All Bookmarks

Do not show local child-group cards. Show the usual Bookmark timeline over the deduplicated union of this group and all descendants. The search hint can say "Search this group and subgroups". A saved remote Group remains one item. A Work and a separately saved Page remain distinct Bookmarks.

Autocomplete, count, filtering and sorting must use exactly the same scope as the visible result grid. For Added/Newest use the latest applicable membership date inside the subtree; Added/Oldest uses the earliest. Memberships outside the subtree must not change that order. Reuse existing fallback/tie-breaking behavior; never replace missing historical dates with the current time. Content upload dates remain independent of membership dates.

Preserve the query when switching the view mode within the same group and immediately reevaluate it in the new scope. Keep navigation state and scroll restoration keyed by group UUID and mode; do not leak an offset from Structure into a different flattened list. For navigation between different groups, retain the established query lifecycle rather than inventing global cross-group filtering. Clear or revalidate selection when scope changes.

## 5. Scroll contract

This is a single scroll surface. Child cards are normal scrolling slivers before the timeline region. Search and timeline controls retain their existing floating hide/reveal behavior, but only within their own section.

| Position/action | Required outcome |
| --- | --- |
| At the top | Child cards precede search/controls and direct Bookmarks. Nothing from the child section is pinned under the Header. |
| Scroll downward into content | Cards leave the viewport naturally; search/controls hide as in the existing timeline. |
| Reverse upward deep inside the timeline | Search/controls reveal beneath the current navigation Header, without overlapping it. |
| Continue upward to the child section | The floating controls meet their natural position below the cards and continue downward with the timeline section. They must not remain attached to the Header over the returning cards. |
| At the top again | Exactly one copy of the search/controls is below the cards; no phantom gap, jump, or duplicate hit target. |

Compose through `PostGrid` / `RawPostGrid` and their existing sliver seams. The conceptual order is a normal child-group `SliverGrid`, the existing measured `TimelineHeaderSliver`, then the mixed Bookmark grid. Keep one vertical controller and lazy grids. Do not nest independent vertical scrollables, shrink-wrap the entire Bookmark library, or duplicate the toolbar in a positioned overlay.

`MeasuredFloatingHeader` and `TimelineHeaderSliver` already own measurement, snapping, reduced motion and AppBar overlap. Prove the section-boundary behavior in a focused harness before changing their renderer. If a narrow correction is required, prefer an opt-in or correctly generalizable section constraint with tests for existing consumers. Do not solve it using fixed pixel thresholds, per-frame full-tree setState, duplicated SafeAreas, or an estimated card-section height.

Keep search and toolbar visibility settings independently meaningful. A keep-visible preference, if honored by the current consumer, applies within the timeline section, not above the subgroup block. Respect reduced motion, live chip wrapping, text scale, rotation, keyboard insets, pull-to-refresh, selection and viewer return. Groups changing while scrolled must not strand the toolbar or invalidate hit testing.

The deferred app-wide Header tasks (#146-#148) are not part of this issue. Preserve current route/Header ownership and change only what is required for this Bookmark screen and a tested shared fix.

## 6. Thumb-friendly Bookmark picker

Reuse one content/navigation state for anchored and modal presentations, including Post, saved-record, remote-group and batch entry points where applicable.

### Row geometry and behavior

- The leading/body portion toggles **direct** membership in that row's group, or performs the existing target-selection action for a destination picker.
- The trailing navigation area is a separate full-height target. Start at 80 logical pixels; larger supported widths may grow toward 96. The visible chevron remains compact, but its entire region is interactive. At a 280-pixel popup, 80 pixels is intentional, not a tiny icon-sized target.
- Use a minimum row height around 56-60 logical pixels, allowing growth for enlarged text. Preserve a usable body region and adapt the presentation rather than shrinking navigation to a glyph-sized target.
- Give both actions separate semantics, keyboard/focus, hover/pressed feedback and hit tests. Use a subtle divider when needed. Do not wrap the entire combined row in a toggling gesture detector or MergeSemantics that erases the two actions.
- In RTL, follow leading/trailing conventions and directional icons. The trailing navigation action stays in the same column across rows.
- Navigation remains available on empty/leaf ordinary groups so a subgroup can be created there. Entering a leaf does not silently add a Bookmark.
- Inside a group, provide a compact selectable row for the current group ("Save here" / the appropriate direct-membership removal state), so it remains a target without returning to its parent. It must use the same mutation and feedback path, not a special shadow membership.
- Retain existing successful selection/dismissal behavior. Navigation alone never dismisses the picker, alters memberships, or changes Recent.

Membership selection/checkmarks indicate only direct memberships. A saved Bookmark in a descendant must never make the parent's direct-membership checkbox appear selected. Any retained subtree indication is visually and semantically distinct, not a second selected state. Preserve the pinned Recent section and its actual manual-mutation ordering; use the same split actions for a Recent row if it permits navigation. Keep the frozen `SavedBookmarkPickerRequest` path, including readable unaddressable records and missing profiles.

### Back and creation

Keep the existing top row: Back/path on the left, Add Group on the right. Do not swap them and do not add a duplicate bottom Back row. Creation targets the current local group as parent; Home creates a root group.

Android system Back, the system back gesture, keyboard Escape, and the visible Back control all use the same hierarchy decision when the picker owns that action: go up exactly one level; only at Home dismiss the picker. No custom horizontal swipe recognizer is needed.

Respect deeper UI ownership first: a naming dialog, transient child overlay, or the IME may consume Back before the picker hierarchy. One event must not both close a child surface and navigate/dismiss the picker, nor bubble to the underlying viewer/page. A cancelled predictive gesture must not commit navigation. Test the anchored popup specifically: a PopScope on an unrelated enclosing route is not proof that an overlay intercepts Back correctly. Outside-tap dismissal keeps its existing meaning and never toggles membership.

If an open group's identity disappears or its parent changes, resolve against current library state and fall back to the nearest surviving ancestor/Home. Never issue a mutation against a stale/deleted target.

## 7. Organization operations and mutation safety

Preserve ordinary add/remove/copy/move, rename, duplicate, delete confirmation, Default policy, and Undo for every saved-record kind. Keep navigation/view-state changes out of the mutation queue.

A parent is not a membership container for all descendants. Adding directly to a parent does not remove child membership. Moving a child group changes only its parent/order, not any membership dates. A selected ancestor plus descendant must not cause a duplicated recursive operation. Validate the whole intended hierarchy before a write and use the existing serialized journal/coordinator for multi-row operations.

The safe default for deleting a non-leaf group preserves its children by promoting them to its parent. Apply the existing explicit direct-membership deletion/orphan confirmation to that group's own memberships. Do not silently erase the subtree or move its direct bookmarks elsewhere. An explicit recursive deletion, if retained from an existing flow, requires an accurate preview and separate confirmation; do not add a new destructive product mode just for this issue. Undo must restore parent/order and only the memberships actually changed, without overwriting concurrent newer edits.

In All Bookmarks, remove/move operations must resolve source memberships explicitly, reusing the existing All-view selection pattern scoped to this subtree. Passing the displayed parent groupId to the current direct-removal API is wrong when the item only belongs to a child. Removing from one chosen child must not remove duplicates from other children or outside the subtree. Global deletion is not a fallback for ambiguous scope.

Keep local-group card selection and saved-Bookmark selection distinguishable. A mixed screen is not permission to apply Post download/delete operations to a local group. Use existing typed selection keys and mutually exclusive action scopes where needed. Mode changes or navigation must exit/revalidate selection rather than applying a stale action to a new scope.

## 8. Migration and transfer

### Preserve both real input formats

#155 has already produced active organization v2 stores and v10 backups. Do not assume they never existed merely because the feature is not on develop. Test both legacy-to-current and already-unified-v2-to-hierarchy upgrades. Preserve existing IDs, payloads, tombstones, the allocator high-water mark, source identity uncertainty, memberships/dates, loaded Details, and Related-only order.

Convert every former folder, including empty folders, into a BookmarkGroup with initially empty direct memberships. Existing group `folderId` becomes its parent reference. Former folder `parentId` maps to the new parent group's ID. Preserve existing group UUIDs. Reuse folder UUIDs when they do not collide with a group/reserved UUID; otherwise preflight a stable, explicit folder-ID remapping and apply it consistently to every parent and saved reference. Do not deduplicate groups by name/path. Same-named siblings remain distinct. Journal the mapping before writes so restart cannot allocate different identities.

Preserve the previous relative placement as far as possible, with deterministic tie resolution when formerly separate folder/group sibling positions collide. Do not retain a permanent folder-first runtime type flag. Preserve legacy selector/template references with an explicit alias/migration path where their `group-folder:` versus group node prefixes differ. Empty converted groups and ordinary groups with duplicate display names must survive repeated import/export.

Keep legacy Hive fields/codecs readable. Do not repurpose a field index with incompatible meaning or declare an existing v2 generation to mean a different structure. Extend the existing migration/recovery mechanism to a distinct hierarchy generation (normally the next local generation, v3), not an in-place multi-box rewrite. Resolve any pending old journal before planning the hierarchy migration. Preflight, stage, validate, durable-sync, then activate once; no partially writable mixture of old folder and new parent representations. Keep recovery input until safe cleanup under the established policy. Unknown or inconsistent active versions fail safely without wiping data.

### Backup versioning

Use an explicitly versioned hierarchy transfer format. The safe default for this issue is **writer v11**, with readers for v4-v10 plus v11, because the existing v10 reader accepts groups/folders and would not necessarily reject an ignored new parent field. A silent parentGroupId extension to v10 could flatten organization in an older reader. Do not ship it. Local storage-generation numbers are independent of backup versions.

v11 keeps the #155 tagged Bookmark array and direct integer membership references, adds the unified parent hierarchy, and has no canonical separate Bookmark folders array. Validate every parent/cycle/member/date and unsupported record before allocating or mutating. Treat external numeric IDs as transfer IDs only. Preserve #155's behavior for unknown legacy records and intentionally unaddressable Posts; hierarchy changes must not synthesize a source ID or dedup key.

For imported v4-v10 organization, convert through the compatibility planner before preview/apply. Keep the existing merge/update/copy/full-replace distinction and cancellation safety. A per-group membership Update does not recursively replace descendants. Explicit full category Replace restores the supplied hierarchy. Copying a selected subtree remaps local group IDs and parents consistently, preserving independent memberships and dates according to the existing copy contract. Selecting an ancestor for export may include descendant nodes, but must not flatten their memberships into the ancestor or accidentally include unselected ancestor contents. Preserve empty structural nodes needed to reconstruct the selection.

Preview and apply must share the same normalized hierarchy and conflict decisions. If an input parent is outside a selected partial import, resolve it explicitly using the import placement policy; never leave a dangling parent or guess by name. Extend scoped export/template selectors, profile-hint remapping, source-integrity checks, rollback and cold-reopen tests. The new view preference is not transferred.

## 9. Performance contract

Use canonical `BookmarkLibraryState.byId`, membership indexes and committed deltas introduced by #155. Avoid the Post-only compatibility maps when determining a subtree. Deduplicate by local integer ID, including opaque/unaddressable saved records, not thumbnail URL or guessed ContentIdentity.

Build child adjacency once per relevant hierarchy snapshot. Walk only the requested subtree and merge direct membership sets; do not scan the full library for every child card, rebuild the tree per item, or eagerly materialize all descendant unions for all groups. Keep a bounded/lifecycle-scoped projection cache for active views. Relevant hierarchy or membership changes invalidate it; unrelated UI preferences do not.

Apply filters/sorting to the derived IDs using the existing metadata/tag indexes. Reuse the current scoped autocomplete pipeline; typing must not rescan/decode the complete stored library. Maintain lazy card/timeline rendering and existing thumbnail caching/safety budgets. No additional remote metadata/member queries are justified by navigating local groups or switching modes; ordinary visible thumbnail loads continue under the existing policy.

Measure existing large-library workloads on the same host before/after and test algorithmic counters rather than strict wall-clock unit-test limits. Deep trees, many shared memberships, repeated navigation, and repeated source/filter changes must remain bounded. Document any retained compatibility projections and their cost rather than silently duplicating storage.

## 10. Acceptance

The implementation plan defines exact verification phases. Acceptance requires lossless/recoverable migration from both old and #155 storage; v4-v11 transfer tests; consistent scoped search/autocomplete/actions; mode persistence; narrow/enlarged keyboard layouts; correct anchored/modal system Back; and the complete scroll transition through the subgroup boundary.

Require an independent **Astra High** final review of the whole #158 candidate because this combines persistence, import and custom scrolling. Fix findings, retest, and obtain re-review of the final SHA. Delegate bounded fixtures, localization, and mechanical consumers to cheaper subagents only where their contracts are fixed. No weaker substitute or self-review may be reported as this independent approval.

Normal Android UI/Back evidence is required in addition to storage probes. The #155 synthetic native campaign does not prove the new screen. Follow emulator leases and use Maestro with isolated, backed-up fixture data. This specification publishes no runtime implementation, new test pass, independent review or merge approval.
