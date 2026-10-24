# UX-002: revised selection and action implementation plan

> **Historical, completed design plan.** Selection reached `develop` in `fd7ae8e`.
> The execution steps and former ticket paths below document the 2026-10-20
> implementation, not the present work queue. Use the
> [post architecture](../post_architecture.md#selection-and-bounded-mixed-origin-preloading)
> for current behavior and [GitHub Issues](../issue_workflow.md) for new tasks.

Date: 2026-10-20

Repository: `timberpile/Boorusama`

Reviewed develop commit: `3bf372bb01ba475659059b459ed3949b39d3cea1`

Status: implementation-ready planning revision; no runtime changes or execution verification in this review.

## 1. Authority, goal, and boundaries

Implement the existing **UX-002 — Unified Post Selection and Action System**, including the user's subsequent decision to reuse working **Long Press + Drag** wherever existing multi-selection is offered. The user tested the current gesture and approved it. Do not replace it with two separate long presses or build a new drag-selection engine.

The original UX-002 ticket is preserved in [Git history](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/docs/work/ready/UX-002-unified-post-selection-and-actions.md) together with this historical revision. The original single/multiple-post action requirements remain in scope; this is not merely a drag wrapper task. This revision supersedes outdated dependency, source-location, gesture, and lifecycle assumptions, not the rest of the approved UX-002 behavior.

The earlier documentation branch `docs/ux-002-existing-drag-selection-20261011` is historical context, not the current implementation base. At the reviewed develop commit, UX-002 still has blob `9ad25be1144571de124527ec530c8eed7a90b0a8`, without that branch's drag-selection extension. Some other tasks have migrated to issues, but UX-002 remains a legacy work item. Do not recreate or migrate it merely because the repository now prefers issues for new tasks.

Deliver one coherent implementation in an isolated task worktree. Preserve existing domain operations, navigation, profile boundaries, and UI conventions. Do not redesign every selection toolbar or introduce new selection modes into screens which currently have none.

## 2. What changed, and what has not

| Reviewed fact | Consequence for implementation |
| --- | --- |
| BM-008 was completed; bookmark actions already implement group-specific removal and Undo. | Treat BM-008 as an integrated dependency. Reuse its services and protect their semantics; do not rebuild its migration or reintroduce global deletion. |
| Following Topics now supplies the former pinned-search/following workflows. Its collection selection uses separate folder/topic ID sets. | Target `lib/core/search/following_topics/`, not obsolete Pinned Search/subscription page assumptions. Preserve recursive folder actions and independent duplicate Topics. |
| Post grids and Following Topics report active selection through `NavigationSelectionBridge`; destination activity/profile scoping now matters. | Retain the bridge and its active-owner semantics, and prevent offstage destinations from handling shortcuts or changing navigation chrome. |
| Kurumi context menus now support touch and mouse concurrently, keyboard opening, focus restoration, and Back handling. | Suppress only the conflicting touch-long-press entry point. Do not disable all menu triggers and inadvertently remove right-click or keyboard access. |
| The post grid still uses indexed selections and `ValueKey(post.id)`. | Introduce stable, origin-aware selection identity with a small index adapter. A different widget key alone does not make selection safe. |
| Header hiding, replacement selection AppBar, search scroll compensation, and hardcoded footer padding remain. | The layout work in UX-002 is still needed, including removal of obsolete search scroll jumps. |
| Generic/bulk action handling still differs from context actions; the origin compatibility gate can hide all engine actions. | The unified post-action work remains necessary. Preserve safe generic actions for mixed origins. |
| `selection_mode: ^0.0.6`, manual activation, and drag options remain in use. | Start from the existing library. Inspect the lockfile and resolved package source locally instead of relying on upstream master or assuming an upgrade is needed. |

These observations are source-based. The review did not run the app, demonstrate a new gesture failure, or validate every selection surface on a device.

## 3. Updated interaction contract

### 3.1 Mobile and mixed input

Retain the approved grid behavior: ordinary tap opens the viewer unless explicitly customized; unspecified/default Grid Long Press enters Selection Mode and selects the item. Existing explicit custom Grid Long Press actions continue to run outside Selection Mode. Preserve the approved explicit Select/Disabled settings semantics. Do not change Viewer gestures.

Once Selection Mode is active, the existing hold-and-drag gesture selects a contiguous range. Taps still toggle individual items. Preserve existing drag reversal, cancellation, indicators, haptics, and edge auto-scroll behavior through characterization tests before refactoring.

A hold must not both execute a custom action and change selection. A selection drag must not open a context menu, navigate, reorder cards, or activate a thumbnail quick action. Ordinary scrolling must remain possible without first exiting selection.

This work does **not** require entering Selection Mode and continuing the very first hold into a drag without lifting the finger. Do not build a new recognizer to satisfy an unrequested interaction. Do not introduce a two-long-press range gesture.

For non-post collection screens, preserve their existing normal-mode entry points and actions. Extend their active selection mode with the same drag interaction. Do not globally change `selectionOptionsProvider` from manual activation to an automatic mode.

### 3.2 Desktop and accessibility

Implement the original desktop contract explicitly: Ctrl/Cmd+Click toggles, Shift+Click selects a range, Ctrl/Cmd+Shift+Click adds a range, and Ctrl/Cmd+A selects loaded selectable items. Regular clicks in Selection Mode toggle items. Modifier selection must not also open a post.

Use a stable identity anchor. A non-range selecting operation sets the anchor to the item selected; consecutive range extensions retain it. If no valid anchor exists, a range request selects the target and establishes the anchor rather than guessing an unrelated index. Clear the anchor when its identity disappears or the selection scope changes. Shift replaces the range-selection result; Ctrl/Cmd+Shift preserves the pre-existing selection and adds the range. Cover shrink/reverse behavior in tests.

Right-click and Context Menu/Shift+F10 remain available, including on touch-capable desktop/Android devices with a mouse. Preserve the distinction between actions on the clicked post and actions on the current selection. Do not switch semantics solely according to the operating system.

Text inputs retain their own Ctrl/Cmd+A. Back/Escape first belong to an open dialog/menu, then to cancelling an active selection interaction or exiting Selection Mode, and only then to page navigation. Preserve Kurumi's focus restoration. Provide accessible labels/selected state and an existing explicit Select entry point; the gesture must not be the only route to selection.

### 3.3 Discoverability

Retain visible selection indicators and controls. Where an existing help/tooltip mechanism is available, include a short localized explanation that holding and dragging selects a range. This is a small discoverability improvement, not a new onboarding or preferences subsystem and not a reason to block the core implementation.

## 4. Selection state: one thin bridge, not a new framework

Use `selection_mode` for gesture recognition, hit testing, drag progression, and auto-scroll. Add only the application-level mapping/state that is missing. A suitable small adapter has:

- A stable set of selected entity keys and an optional range anchor key.
- The current ordered **selectable** entries for one collection, plus an index/key lookup rebuilt when that collection changes.
- A scope identity and dataset revision to reject stale selection/action updates.
- A bridge to/from the package's indexed selection and existing domain-specific actions.

Exact names and implementation style should follow nearby code. Do not keep two independent mutable sources of truth. Avoid a second drag controller, generic persistence layer, global selection singleton, or universal action registry for unrelated entities.

### 4.1 Identity rules

For posts, reuse established origin and stable post-key semantics, including engine-specific keys such as Pixiv page identity where supplied. `BookmarkIdentity.tryFromPost` is relevant existing code. Do not use the shared `UnbookmarkablePostIdentity()` sentinel as a unique selection key. Items without a stable identity need distinct scope-local row tokens; drop their selection on a replacement dataset unless identity can be proven.

`postViewerIdentity` is a viewer/Hero identity, not automatically the appropriate canonical selection identity. Keep account/profile resolution for execution separate from canonical post identity. Never equate numeric IDs from different sites.

For mixed collection rows, namespace keys by entity kind: for example folder versus Topic, or folder versus Bookmark Group. Independent Topics with identical query text remain independent because their Topic IDs differ.

### 4.2 Ordering, virtualization, and mutation

A range is inclusive and follows the displayed collection's logical order, forward or backward. It is not a rectangle in screen coordinates, including in masonry grids. Loaded but offscreen items remain eligible; a widget does not need to be mounted for its identity to be selected.

Exclude progress indicators, headers, placeholder rows, and non-selectable system cards from the selectable index space. In the Bookmark Group browser, All and the protected Default system card must not become movable merely because a drag crosses them.

Selection alone must not fetch every matching remote page. Normal pagination may append content. An append that preserves the existing ordered prefix can extend the range's available entries; do not automatically select the new items unless the range actually reaches them. If a refresh/reorder/removal changes existing ordering during a drag, cancel the transient drag, restore the pre-drag committed selection, then reconcile surviving keys. Never let old indices address newly positioned items.

Preserve stable selected identities on an ordinary reorder or same-scope refresh where possible. Clear selection and anchor on query, filter, collection/folder, or source-profile changes that replace the scope. Remove selected keys for deleted entries. Preserve an active empty mode when it was entered explicitly; zero selection must not break Close/All/None or enable invalid actions.

The existing bookmark refresh gate and identity remapping must be integrated, not left competing with a second remapping listener. Late post-frame callbacks may not overwrite a newer selection or a different scope.

### 4.3 Navigation lifecycle clarification

Selection belongs to the route's collection, not the globally active profile or the navigation shell. Disposal/pop or a changed collection scope clears it. A temporarily covered route or an unchanged kept-alive destination can retain its committed selection; cancel an in-flight drag on deactivation, suspend shortcuts, release its active chrome ownership, and reconcile IDs before it becomes interactive again. This refines the old generic 'leaving the page' wording for the new retained navigation architecture; it does not add persisted selections across restarts.

Retain `NavigationSelectionBridge`, `NavigationScrollBoundary`, destination profile scopes, and existing activity ownership. A hidden route must neither keep the navigation bar in a selection state nor handle the active route's keys. Closing a menu must not dispose the underlying selection. No selection action may switch the global active profile as a side effect.

Avoid re-resolving an entire dataset, calling network APIs, or rebuilding every thumbnail on every drag movement. Rebuild ordering maps on dataset changes and update selection/capability state only as required.

## 5. Keep input and action responsibilities separate

### 5.1 Post actions

Implement the original shared single/bulk post action definitions and execution paths. Reuse existing download, bookmark, favorite, browser, and site-specific services. Availability derives from the actual selected posts, their resolved origins/accounts, permissions, and selection cardinality—not merely the active profile.

The selection controls stay visible even when no post-specific action is available. Safe generic actions remain available for mixed-origin selections. An engine action must not silently run on only a supported subset while appearing to affect all selected posts.

Take an immutable selection/action-target snapshot before asynchronous dialogs or execution. Validate applicable origins and capabilities for that operation; later taps or refreshes must not retarget it. Missing/changed targets require explicit failure/reconciliation, not falling back to the current index or global profile. Failed or cancelled operations leave a recoverable selection. Remove the old unconditional dismissal after every bulk action; apply the completion policy from UX-002.

### 5.2 Domain operations that must be retained

**Bookmarks:** reuse BM-008 Add/Remove-from-one-group semantics, protected Default Group, last-membership removal, and Undo. Preserve the origin-aware bookmark download path. Do not add Delete Everywhere, duplicate storage/migrations, or a separate single-selection deletion policy.

**Following Topics:** keep existing folder-to-descendant Topic expansion and deduplication by Topic ID for the actions that already use it. Range selection chooses visible rows; a selected folder's action expansion remains the existing domain rule, not extra invisible row selection. Preserve existing confirmations, `expectedOrganization` validation, profile eligibility, and independent duplicate queries. Do not rewrite tracking, scheduling, feeds, or cache management.

**Bookmark Group/folder browser:** preserve move semantics, protected special cards, and folder-cycle checks. Do not route these actions through the post action registry.

## 6. Current surface coverage

| Surface | Reviewed state | Required work |
| --- | --- | --- |
| Normal/search/favorite/site-specific post grids using `PostGrid` | Existing package drag integration; indexed identity; old layout/action paths | Shared post adapter, input/action integration, header/toolbar work, regression checks across consumers |
| Bookmark post grids | `PostGrid`, custom item/action builders, existing refresh identity recovery | Integrate without losing source-aware actions, refresh gate, or Undo |
| Topic Feed post grids | `_CachedFeedGrid` in `topic_feeds_page.dart` uses post-grid infrastructure and live history updates | Cover custom builders and content mutations; retain feed/activity coordination |
| Bookmark Group/folder browser | Separate folder/group ID sets; selection for move; no package drag integration in reviewed code | Reuse range adapter over selectable folders/groups; skip All/Default special cards |
| Following Topics/folder list | Separate ID sets; recursive actions; conditional batch-progress row | Reuse range adapter over actual displayed selectable order; preserve actions and route bridge |
| Feed overview and Feed member management | Reviewed pages expose per-item actions, not existing collection multi-selection | Do not invent new bulk-selection modes under this task |
| Other existing multi-select surfaces, including download/tag/backup-related controls if present | Not exhaustively characterized by this remote review | Inventory locally; integrate missing compatible range behavior or verify existing behavior. Document each applicable surface and any semantic limitation. |

Single-choice destination/profile pickers are not multi-selection surfaces. Hierarchical or tri-state selection trees need their current cascading/disabled semantics inspected; do not silently flatten them into ordinary post selection or omit them without recording their treatment. The inventory is part of completion, not permission to limit implementation to the first two screens.

## 7. Layout and Kurumi integration

Preserve existing page headers, search controls, filters, and navigation in post Selection Mode. Put Close, count, All/None, and cardinality/capability-aware actions in the bottom selection area as approved in UX-002. Preserve existing non-post selection layouts unless a narrowly necessary change is needed for input consistency.

Remove the replacement Post Grid selection AppBar and header hiding together with `RawSearchPageScaffold._onMultiSelectChanged`'s obsolete height-compensation jump. Check top- and bottom-positioned search UI. Maintain the user's scroll position on entry/exit.

Reserve the actual footer height rather than retaining the old 72/36-pixel assumptions. Account for system insets, keyboard, and the existing main navigation layout without double padding or overlap. Retain Kurumi toolbar text fitting/scaling, `AnchorHoverGroup`, and performance scopes.

`KurumiContextMenu.triggers = false` disables more than touch long press: it also bypasses automatic keyboard and pointer triggers. Prefer a narrow, backwards-compatible touch-long-press policy or an adapter that explicitly retains secondary-click and keyboard opening. Keep default behavior unchanged for unrelated Kurumi consumers. Do not install a global keyboard listener to override modal precedence.

## 8. Implementation sequence

1. **Baseline and inventory.** Re-read current HEAD, existing issue claims, repository instructions, and resolved dependency code. Record the actual selectable surfaces and characterize the working drag behavior before editing it.
2. **Stable state bridge.** Implement the smallest ordered identity/index adapter and tests for mixed origins, typed collection keys, offscreen items, scope changes, and mutation reconciliation. Establish one authoritative selection state.
3. **One real post-grid slice.** Wire touch, modifiers, and menu precedence through actual grid widgets; preserve existing custom gestures and desktop/keyboard menus. Validate the slice before spreading it to every caller.
4. **Post action and layout integration.** Share single/bulk action execution, retain BM-008 services, remove header/scroll compensation, and add the responsive measured bottom controls. Preserve navigation ownership.
5. **Collection rollout.** Add existing drag interaction to Bookmark Group/folder and Following Topics rows, then complete the local inventory of other multi-select surfaces. Keep entity-specific actions unchanged.
6. **Regression and qualification.** Complete the acceptance matrix, relevant package/consumer checks, device tests, and full-suite qualification. Record evidence against the exact checked candidate.

Use small commits on one task branch. Parallel implementation is not required; do not have independent agents modify the shared adapter, Kurumi trigger API, and grid integration without first agreeing on the boundary.

## 9. Acceptance and verification matrix

All items below are implementation acceptance checks, not results claimed by this review.

- [ ] Existing active-mode hold-and-drag behavior is preserved, including reversal and edge auto-scroll; ordinary scrolling remains available.
- [ ] Default/custom/Select/Disabled Grid Long Press semantics work; no duplicate selection, download, favorite, or menu callback occurs.
- [ ] Desktop range/additive selection, missing-anchor handling, Ctrl/Cmd+A focus guards, right-click, keyboard menu opening, and Back/Escape precedence work with actual widgets.
- [ ] Mixed-origin equal numeric IDs, engine-specific stable keys, missing-key rows, and equal folder/topic IDs cannot alias selections.
- [ ] Offscreen loaded entries, masonry order, cross-row ranges, progress-row insertion, non-selectable cards, normal append, reorder, removal, and stale refresh callbacks are handled safely.
- [ ] Query/filter/profile/folder changes clear stale targets; same-scope refresh/sort reconcile IDs; zero-selection mode remains usable.
- [ ] Hidden retained destinations release chrome/key ownership; returning reconciles safely; pop/disposal clears state; dialogs do not accidentally clear selection.
- [ ] One/many/mixed-origin post actions share execution and obey capabilities; selected snapshots remain stable across awaits; failed actions retain recoverable state.
- [ ] Bookmark group-specific removal, final-membership deletion, protected Default, and Undo pass; global delete is absent.
- [ ] Following folder actions preserve existing recursion, ID deduplication, confirmations, and source-scoped execution.
- [ ] Headers, search, filters, and navigation remain available for post selection; entry/exit does not jump scroll; the final item is reachable above the footer.
- [ ] Narrow layouts, enlarged text, bottom/top search position, keyboard, and both pagination modes do not obscure actions or content.
- [ ] Every existing applicable multi-select surface is accounted for; no new selection mode is introduced into a single-choice or per-item-only screen.

Use controller/unit tests for identity and reconciliation, real-widget tests for gesture/focus/layout interactions, and a small device acceptance pass for touch/auto-scroll and platform Back. Do not infer integration correctness merely from the package configuration. Use controlled timing/completion rather than arbitrary sleeps.

Because this changes shared selection infrastructure across features, plan a complete local regression pass as required by `AGENTS.md`. Run the full Kurumi package suite plus consumers if its menu API changes. `./scripts/run_regression_tests.sh` is the current complete application/package/tooling runner. A green application-only run is not a complete pass. Full verification still does not authorize integration or publication.

## 10. Source map for the implementing agent

The following links are pinned to the reviewed commit. Re-check local HEAD before implementation.

### Workflow and existing requirements

- [`AGENTS.md`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/AGENTS.md)
- [`.agents/skills/design-change/SKILL.md`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/.agents/skills/design-change/SKILL.md)
- [`docs/engineering_guidelines.md`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/docs/engineering_guidelines.md)
- [`docs/work/ready/UX-002-unified-post-selection-and-actions.md`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/docs/work/ready/UX-002-unified-post-selection-and-actions.md)
- [`docs/work/done/BM-008-default-bookmark-group-and-membership-undo.md`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/docs/work/done/BM-008-default-bookmark-group-and-membership-undo.md)

### Post input, layout, and actions

- [`lib/core/posts/listing/src/widgets/post_grid.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/posts/listing/src/widgets/post_grid.dart)
- [`lib/core/posts/listing/src/_internal/raw_post_grid.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/posts/listing/src/_internal/raw_post_grid.dart)
- [`lib/core/posts/listing/src/widgets/default_selectable_item.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/posts/listing/src/widgets/default_selectable_item.dart)
- [`lib/core/posts/listing/src/widgets/sliver_post_grid_image_grid_item.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/posts/listing/src/widgets/sliver_post_grid_image_grid_item.dart)
- [`lib/core/posts/listing/src/widgets/default_multi_selection_actions.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/posts/listing/src/widgets/default_multi_selection_actions.dart)
- [`lib/core/search/search/src/widgets/raw_search_page_scaffold.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/search/search/src/widgets/raw_search_page_scaffold.dart)
- [`lib/core/settings/src/providers/settings_provider.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/settings/src/providers/settings_provider.dart)
- [`pubspec.yaml`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/pubspec.yaml)

### Bookmarks and identity

- [`lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart)
- [`lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart)
- [`lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart)
- [`lib/core/bookmarks/src/types/bookmark_identity.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/bookmarks/src/types/bookmark_identity.dart)
- [`lib/core/posts/post/src/types/post_viewer_identity.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/posts/post/src/types/post_viewer_identity.dart)

### Following Topics, menus, and navigation

- [`lib/core/search/following_topics/src/pages/following_topics_page.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/search/following_topics/src/pages/following_topics_page.dart)
- [`lib/core/search/following_topics/src/pages/topic_feeds_page.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/search/following_topics/src/pages/topic_feeds_page.dart)
- [`lib/core/search/following_topics/src/pages/topic_feed_management_page.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/search/following_topics/src/pages/topic_feed_management_page.dart)
- [`packages/kurumi/lib/src/components/context_menu.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/packages/kurumi/lib/src/components/context_menu.dart)
- [`lib/core/navigation/navigation_interaction_scopes.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/navigation/navigation_interaction_scopes.dart)
- [`lib/core/navigation/navigation_chrome_controller.dart`](https://github.com/timberpile/Boorusama/blob/3bf372bb01ba475659059b459ed3949b39d3cea1/lib/core/navigation/navigation_chrome_controller.dart)

## 11. Planning deliverables and limitations

This plan and the companion handoff are provided as Markdown artifacts. This review did not modify the remote repository, claim UX-002, create a runtime feature branch, build the app, or run Flutter/device tests. The local implementation agent should copy the documents into `docs/designs/`, update the existing UX-002 file to link this revision and record BM-008 as completed, then follow the current legacy work-item claim procedure.

Do not mark implementation criteria complete from this source review. Preserve unrelated work and do not push, merge, open a PR, release, or migrate tickets without separate authorization.
