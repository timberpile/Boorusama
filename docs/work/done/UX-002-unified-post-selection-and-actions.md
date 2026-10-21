# UX-002 — Unified Post Selection and Action System

> **Archive disposition (2026-10-21): Completed on `develop`.** Unified post and collection selection was integrated by commit [`fd7ae8e`](https://github.com/timberpile/Boorusama/commit/fd7ae8e63b9ecd1472167e6b9f95542f22efe170). The pending integration, worktree, and manual validation notes below are historical, not a live task status.


Priority: Normal

Affected features: Post Grid, Post Context Menus, multi-selection, Bookmark actions, Downloads, Booru-specific actions, gestures, desktop input, navigation

Dependencies: BM-008 (completed and integrated; reuse existing membership and Undo services)

## Current implementation claim

- Agent/session: Codex, 2026-10-20 local UX-002 implementation.
- Branch: `feature/ux-002-unified-selection`.
- Worktree: `.worktrees/ux-002-unified-selection`.
- Initial implementation base: `7d58c7d86786fe3f891cb2810f615fc9adef07d5`. Reconciled local integration base: `9be0d3e65`.
- Binding revision: [selection plan](../../designs/2026-10-20-ux-002-selection-plan.md) and [handoff](../../designs/2026-10-20-ux-002-local-agent-handoff.md).
- Initial reconciliation: historical `docs/ux-002-existing-drag-selection-20261011` contains only a planning amendment, no implementation claim. Preserved without replaying its older work item. The initial develop base added the APK updater after the planning baseline; selection sources were unchanged. The final integration also incorporates the portable-link feature at `9be0d3e65`.
- Scope includes existing active-mode hold-and-drag across all applicable existing multi-select collections; no new selection modes or drag engine.
- Latest runtime candidate: `a2ba69565`; see the authorized local integration revision below. Subsequent feedback supersedes earlier action-layout and completion observations in this record.
- Status: the two combined-candidate search-layout failures are fixed and the complete local regression gate passed on `a2ba69565`. Native continuous hold-and-drag acceptance remains open, so the work item stays in progress.
- Local integration was explicitly reauthorized after the scroll-driven navigation revision. The earlier merge hold is lifted; no push, PR or release is authorized.

## Problem

Post actions currently follow two largely separate interaction models.

For a single post:
- Long Press normally opens a context menu.
- The context menu exposes Download, Bookmark Management, Favorite, View in Browser, View Tags, Select, and various site-specific actions.
- The user must first choose Select to enter multi-selection mode.

For multiple posts:
- The user enters a separate selection mode.
- A different bottom toolbar appears.
- Only a subset of the single-post actions is available.
- Single-post and multi-post actions are implemented through separate UI structures.
- Engine-specific action availability is handled inconsistently across different selection contexts.

Additionally, the current selection mode replaces or hides significant parts of the ordinary page UI.

For example, the Post Grid currently hides its normal sliver headers while selection mode is active. Search pages also hide their normal search region. This makes filters, navigation, and sorting unavailable or causes unexpected layout changes.

The desired experience is simpler:

**Selecting one or more posts should use the same selection model and the same underlying action implementations.**

Selection controls should appear in the bottom toolbar without replacing the normal page navigation.

The new design must work on mobile, desktop, and with existing user-configured gestures.

---

## 1. Approved Interaction Model

### 1.1 Mobile

Normal behavior:

- Tap a Post Grid item: open the Post Viewer.
- Long Press a Post Grid item: activate Selection Mode and select that post.
- Tap additional items while Selection Mode is active: toggle their selection.
- Long Press while Selection Mode is already active: retain selection behavior rather than invoking an unrelated site-specific gesture.
- Exit Selection Mode using the bottom toolbar's Close action or Android system Back.

When only one post is selected, expose actions applicable to that individual post.

When multiple posts are selected, expose applicable bulk actions.

Do not require opening a context menu and selecting a separate `Select` command before the first post can be selected.

Retain the existing `Select` entry in the grid overflow menu as an alternative way to enter Selection Mode.

### 1.2 Desktop

Desktop input should follow familiar multi-selection conventions.

| Input | Behavior |
| --- | --- |
| Left Click | Open Post Viewer |
| Ctrl+Click (Windows/Linux) | Toggle selection of the clicked post |
| Cmd+Click (macOS) | Toggle selection of the clicked post |
| Shift+Click | Select a contiguous range from the selection anchor |
| Ctrl/Cmd+Shift+Click | Extend the current selection with a range |
| Right Click | Open post context menu |
| Ctrl/Cmd+A | Select all currently loaded/visible posts |
| Escape | Exit Selection Mode |

Requirements:

- Ctrl/Cmd+Click must be able to start Selection Mode directly.
- Shift+Click should use a predictable selection anchor.
- Mouse selection must not inadvertently open the Post Viewer.
- Modifier keys should not interfere with ordinary scrolling.
- Right Click must retain the desktop context menu.
- The context menu should retain Select as an alternative entry point.
- In Selection Mode, ordinary clicks may toggle individual items, consistent with mobile behavior.
- Modifier-based range selection should work with grid ordering and pagination.
- Use the platform-appropriate modifier key on each OS.
- Do not intercept Ctrl/Cmd+A while a text input is focused.
- Do not steal Escape from a dialog, popup menu, or other modal control that should handle it first.

Selection All applies to currently loaded items represented by the grid controller, not automatically to every matching remote post across unrequested pages.

The keyboard and modifier behavior must be implemented and verified explicitly; do not assume the `selection_mode` dependency already provides it.

### 1.3 Touchscreen/Desktop Interactions

Desktop platforms with touchscreens should support touch selection where appropriate without compromising mouse behavior.

Do not infer mouse gestures solely from the operating system when the pointer device type is available.

---

## 2. Configurable Long-Press Gestures

### 2.1 Current Behavior

Boorusama supports per-profile customizable gestures.

The configuration distinguishes:
- Image Grid gestures
- Image Viewer gestures

Image Grid Long Press may be configured to perform actions such as Download, Share, Toggle Bookmark, View Tags, Open Source, or an engine-specific action.

Currently:

- If an explicit Long Press action is configured, it executes directly.
- Otherwise, Long Press normally opens the existing context menu.
- Users can still enter Selection Mode using `Select` in the grid overflow menu.
- Desktop Right Click opens the context menu independently.

These user configurations must not be silently discarded.

### 2.2 New Behavior

Introduce a centralized gesture-dispatch mechanism.

The following rules are approved:

| Grid state/configuration | Long Press |
| --- | --- |
| No explicit custom action | Enter Selection Mode and select the post |
| Explicit `Select` action | Enter Selection Mode and select the post |
| Existing explicit custom action | Execute the configured action |
| Explicit `Disabled` action | Perform no Long Press action |
| Selection Mode already active | Selection interaction takes precedence |

Add `Select` as a configurable Grid Long Press action.

If necessary, introduce an explicit `Disabled` value to distinguish intentionally disabling the gesture from accepting the default behavior.

Currently, null/unspecified gesture configuration also represents the old `None` behavior. Since those cases are indistinguishable in existing saved configurations, document the new default clearly:

**An unspecified Grid Long Press action now means Select.**

Preserve all existing non-null customized actions.

Do not automatically replace user-configured Download, Favorite, Bookmark, or other actions with Select.

Update the gesture settings labels so the default behavior is understandable, for example `Default (Select)`.

### 2.3 Gesture Scope

Only change Grid Long Press behavior.

Do not change Image Viewer Long Press, Swipe Down, Double Tap, or other Viewer gestures as part of this work.

Do not change explicitly customized Grid Tap behavior.

Do not remove Desktop Right Click menus.

The gesture dispatcher should prevent a single gesture from simultaneously:

- Running a custom Booru action
- Starting Selection Mode
- Opening a context menu

Existing nested GestureDetectors and context-menu triggers must be reviewed to avoid gesture-arena conflicts.

---

## 3. Selection Toolbar Redesign

### 3.1 Preserve Existing Page UI

Activating Selection Mode must not hide or replace the existing page's normal interface.

Preserve, where applicable:
- AppBar and title
- Navigation controls
- Search bar
- Selected tags and filters
- Sorting controls
- Grid configuration controls
- Profile-specific controls
- Page navigation and status information

In particular:

- Stop hiding all Post Grid sliver headers when selection activates.
- Stop hiding the ordinary Search Region solely because selection is active.
- Remove the dedicated replacement Selection AppBar for Post Grid pages.

Avoid sudden scrolling, top padding changes, or layout jumps when entering or exiting selection mode.

This change should apply consistently to Bookmark grids and ordinary Booru post listings.

### 3.2 Bottom Toolbar Layout

Move all selection controls into the existing bottom action area.

The toolbar must contain:

**Selection controls**
- Close Selection Mode
- Selected count
- Select All / Select None

**Post actions**
- Contextually available actions for the selected post(s)
- Overflow/More for less frequently used actions

Conceptual arrangement:

    [ X ]  3 selected            [ Select All / None ]
    ------------------------------------------------
    [ Download ] [ Bookmarks ] [ Favorite ] [ More ]

The exact layout can adapt to platform and width.

Requirements:

- The toolbar is visible in Selection Mode even if no post-specific action is currently available.
- Selection count is always visible.
- Select All/None is accessible without replacing the top AppBar.
- The action row handles varying numbers of available actions.
- Less common actions may move into overflow.
- Buttons have sufficient touch targets.
- Bottom safe areas and system navigation bars are respected.
- Desktop layouts should not waste excessive vertical space.
- Small mobile screens and enlarged system text must not cause overflow.
- The toolbar should not cover the final Post Grid items; maintain appropriate bottom spacing.

Retain existing haptic feedback and selection indicators where appropriate.

### 3.3 Selection State

Selection should be tracked by stable post identity rather than relying exclusively on transient grid indices.

This is particularly important in Bookmark Groups containing posts from multiple Booru profiles.

Two posts from different sources may have the same upstream numeric post ID. They must not be treated as one selected item.

Use canonical origin-aware identifiers or the relevant established post identity abstraction.

Behavior requirements:

- Refreshing or reordering must not accidentally transfer selection to the wrong post.
- Sorting should preserve the selected identities where practical.
- Changing the search query or active filters should clear the selection to prevent accidentally acting on hidden posts.
- Leaving the page must dispose or clear its Selection Mode state.
- Actions must operate on the actual selected posts, not stale indices.
- The toolbar must update when an operation removes posts from the current view.
- Empty selection must remain recoverable through Select All or a new item selection, without broken actions.

Avoid re-resolving entire datasets unnecessarily on every selection state change.

---

## 4. Unified Post Action Architecture

### 4.1 One Logical Action System

Replace the unnecessary split between single-post context actions and multi-post actions with shared action definitions.

The same underlying action implementation should be callable from:

- A single-post selection
- Multiple selected posts
- Desktop context menus
- Relevant existing single-post entry points
- The Post Viewer, where applicable

The UI presentation may differ, but business logic should not be duplicated merely because the selection contains one rather than several posts.

Introduce a reusable action registry or equivalent structured abstraction.

A conceptual action definition should include:

- Stable action identifier
- Label and icon
- Selection cardinality support
- Per-post capability/permission checks
- Optional requirements such as authentication
- Action execution callback
- Optional destructive/confirmation behavior
- Suitable toolbar or overflow placement

The specific Dart interface may follow existing repository conventions. Avoid excessive abstraction if existing action services can be reused directly.

### 4.2 Action Cardinality

Actions must declare which selections they support.

Examples:

| Action | One post | Multiple posts |
| --- | --- | --- |
| Download | Yes | Yes |
| Bookmark Management | Yes | Yes |
| Favorite | Yes, where supported | Where bulk operation is supported |
| Share | Yes | Only when implemented safely |
| View in Browser | Yes | No |
| View Tags | Yes | No |
| View Comments | Yes, where supported | No |
| Edit Tags/Rating | Where supported | Only when a valid bulk operation exists |
| Danbooru Favorite Groups | Where supported | Where supported |

These are capability examples, not a requirement to implement new unsupported server-side bulk APIs.

Single-post-only actions should become available when exactly one post is selected.

Actions unavailable for the selected count should be hidden or disabled as appropriate, rather than remaining clickable and failing.

### 4.3 Booru/Profile-Specific Capabilities

Action availability can depend on:
- Booru engine
- Specific site/profile
- Authentication
- User permissions
- Post type
- Post data availability
- Current selection count

Evaluate capabilities for the actual selected posts and their resolved profiles.

Do not assume that all posts in a Bookmark Group come from the globally active profile.

A Bookmark Group can contain posts from multiple Booru installations, potentially even installations using the same engine type.

Common actions such as Download or Bookmark Management should remain usable for mixed-origin selections where a safe origin-aware implementation exists.

Engine-specific actions should only appear when they are valid for the entire relevant selection.

**Do not silently execute an action on only a supported subset of posts while presenting it as an action on the whole selection.**

If partial or per-profile execution is desired in the future, it must be a distinct, explicit UX decision.

### 4.4 Mixed-Origin Selection

The current post-grid implementation checks origin compatibility before providing certain engine-specific multi-selection actions. For incompatible selections, this can result in no engine-specific toolbar actions.

Replace this all-or-nothing UI behavior with capability-based action availability.

Expected behavior for a mixed Danbooru + Rule34 selection:

- Generic actions that support both posts remain available.
- Bookmark membership actions remain available.
- Download uses each post's appropriate origin/configuration.
- Unsupported engine-specific actions are omitted or disabled.
- The bottom selection controls never disappear merely because engine-specific actions are unavailable.

Do not change the currently selected global Booru profile as a side effect of acting on a mixed-origin selection.

Avoid new network requests solely to determine routine action availability when existing profile metadata can answer the question.

### 4.5 Shared Execution Logic

Where possible, refactor existing code rather than duplicating it.

Potential action sources include:
- Download notifier and bulk download services
- Bookmark Management services
- Favorite actions
- Tag-list/navigation actions
- Browser navigation
- Engine-specific action builders

The registry should provide consistent availability decisions and dispatch to established services.

The single-selection path and bulk-selection path must not develop separate Bookmark deletion or membership semantics.

Respect BM-008:

- Add and Remove operate on one selected Bookmark Group.
- The global Delete-from-all-groups action is not reintroduced.
- Removing the final membership deletes the Bookmark and supports Undo.
- Default Group remains a protected system group.

### 4.6 Action Completion

Define consistent behavior after execution.

Recommended defaults:

- Non-destructive actions may leave Selection Mode active, allowing another action.
- Operations that change the visible dataset must reconcile selection using stable post identities.
- Explicit Close always exits Selection Mode.
- Failed actions should preserve a recoverable selection state and display suitable feedback.

Do not unconditionally dismiss Selection Mode for every action merely because an older bulk handler did so.

A popup or dialog being dismissed must not automatically destroy the underlying selection unless the action explicitly requires it.

---

## 5. Desktop Context Menus

Desktop Right Click remains supported.

The desktop context menu and selection toolbar should reuse the same underlying action implementations.

The context menu may continue presenting actions for the clicked post directly, while the bottom toolbar presents actions for the selected collection.

Do not remove contextual features that have no suitable bulk equivalent.

If the user right-clicks an unselected post while other posts are selected, the context menu must clearly operate on the clicked post unless it explicitly advertises acting on the selection.

Avoid accidental use of a previous selection as the implicit target of unrelated right-click actions.

Retain the `Select` context-menu action as an alternative way to enter or extend Selection Mode.

---

## 6. Integration with Existing UI

Inspect the following areas and their callers:

**Post Grid and Selection**
- `lib/core/posts/listing/src/_internal/raw_post_grid.dart`
- `lib/core/posts/listing/src/widgets/post_grid.dart`
- `lib/core/posts/listing/src/widgets/post_grid_item.dart`
- `lib/core/posts/listing/src/widgets/default_image_grid_item.dart`
- `lib/core/posts/listing/src/widgets/default_selectable_item.dart`
- `lib/core/posts/listing/src/widgets/sliver_post_grid_image_grid_item.dart`
- `lib/core/widgets/default_selection_bar.dart`
- `lib/core/widgets/multi_selection_action_bar.dart`

**Existing Actions and Context Menus**
- `lib/core/posts/listing/src/widgets/default_multi_selection_actions.dart`
- `lib/core/posts/listing/src/widgets/general_post_context_menu.dart`
- `lib/core/posts/listing/src/widgets/default_post_list_context_menu_region.dart`
- `lib/core/posts/listing/src/widgets/post_grid_config_icon_button.dart`
- `lib/core/bookmarks/src/widgets/bookmark_multi_selection.dart`
- `lib/core/bookmarks/src/widgets/bookmark_context_menu_section.dart`
- `lib/boorus/danbooru/posts/listing/src/danbooru_multi_selection_actions.dart`
- `lib/boorus/danbooru/posts/post/src/context_menu.dart`

**Search Layout**
- `lib/core/search/search/src/widgets/raw_search_page_scaffold.dart`

**Gestures and Profiles**
- `lib/core/configs/gesture/src/pages/booru_config_gestures_view.dart`
- `lib/core/configs/gesture/src/types/actions.dart`
- `lib/core/configs/gesture/src/types/gesture_config.dart`
- `lib/core/configs/gesture/src/types/post_gesture_config.dart`
- `lib/core/configs/config/src/providers/booru_config_ref.dart`
- `lib/core/configs/manage/src/providers/current_booru_providers.dart`
- `lib/core/boorus/defaults/src/booru_repository_default.dart`

**UI Components**
- `packages/kurumi/lib/src/components/context_menu.dart`
- `packages/kurumi/lib/src/components/selectable_item.dart`

**Relevant Existing Dependency**
- `selection_mode` package

Inspect how gesture recognizers, selection state, origin resolution, and action handlers currently interact before restructuring them.

Use existing components where reasonable.

---

## 7. Acceptance Criteria

The checks below record automated behavior coverage plus the specific emulator checks listed in the implementation evidence. They do not assert native desktop or continuous native drag acceptance; those remaining gates are recorded separately.

### Selection and Input

- [x] Mobile Long Press selects the pressed post when no explicit custom action is configured.
- [x] A single selected post enters the same selection mode as multiple selected posts.
- [x] Tapping further posts toggles their selection.
- [x] Existing explicitly configured Long Press actions continue working.
- [x] `Select` can be configured as a Grid Long Press action.
- [x] An explicit Disabled option is available if required.
- [x] Image Viewer gestures remain unchanged.
- [x] Desktop Ctrl/Cmd+Click toggles post selection.
- [x] Desktop Shift+Click performs range selection.
- [x] Desktop Ctrl/Cmd+Shift+Click supports additive range selection.
- [x] Desktop Ctrl/Cmd+A selects currently loaded posts when appropriate.
- [x] Desktop Right Click retains the context menu.
- [x] Escape and Back exit selection mode correctly.
- [x] Gestures never accidentally trigger two conflicting operations.
- [x] The existing grid-menu Select action remains available.

### Layout and Navigation

- [x] Existing AppBar remains visible in Selection Mode.
- [x] Search and tag-filter widgets remain visible.
- [x] Sorting and grid configuration remain accessible.
- [x] Selection controls are moved to the bottom toolbar.
- [x] The upper replacement Selection AppBar is removed from Post Grid pages.
- [x] The bottom toolbar displays Close, selected count, and Select All/None.
- [x] Post actions appear in the same bottom action area.
- [x] The toolbar is responsive and does not cover grid content.
- [x] Entering or leaving selection does not cause unnecessary scroll jumps.
- [x] Narrow screens and enlarged text are supported.

### Shared Actions

- [x] One common action-dispatch architecture serves single and multi-selection.
- [x] Single-post-only actions are available for a single selected post.
- [x] Multi-post actions use the same underlying services where applicable.
- [x] Site/profile permissions are evaluated for selected posts.
- [x] Mixed-origin selections retain compatible common actions.
- [x] Unsupported engine-specific actions do not run on incompatible posts.
- [x] Bookmark Management follows BM-008 semantics.
- [x] Failed actions display feedback without corrupting selection state.
- [x] Selection is stable across sorting and safe during refresh/filter changes.

### Regression

- [x] Normal tapping still opens posts.
- [x] Post Viewer navigation remains functional.
- [x] Existing Download behavior remains correct.
- [x] Existing Bookmark Management behavior remains correct apart from approved BM-008 changes.
- [x] Existing Favorite and engine-specific actions remain accessible.
- [x] Custom gestures are not overwritten.
- [x] Desktop context menus remain functional.
- [x] Normal search, filtering, and sorting remain usable.
- [x] Bookmark Groups with multiple profiles remain supported.

---

## 8. Verification Plan

### Gesture Tests

Cover:

- Default mobile Long Press
- Explicit Long Press Select
- Explicit custom Download
- Explicit engine-specific custom action
- Disabled Long Press
- Selection Mode already active
- Long Press with no resolvable Booru profile
- No duplicate callback execution
- Viewer gesture settings unchanged

Test gesture behavior with the actual Post Grid widgets, not only a pure gesture-dispatch function.

### Desktop Input Tests

Cover:

- Left Click opening Viewer
- Ctrl+Click and Cmd+Click
- Shift+Click range selection
- Ctrl/Cmd+Shift+Click
- Right Click
- Select from context menu
- Select from grid overflow
- Ctrl/Cmd+A
- Ctrl/Cmd+A with focused search text field
- Escape with and without an open popup
- Selection across grid reordering

Use widget tests with simulated keyboard and mouse events, plus device testing where available.

### Selection UI Tests

Cover:

- One selected post
- Many selected posts
- Zero posts selected while Selection Mode remains active
- Select All and Select None
- Narrow screen and large text scale
- Bottom safe area
- Search with selected tag chips
- Sorting while selection exists
- Changing filters while selection exists
- Infinite-scroll pagination
- Paginated grids
- Bookmark Group grid
- Mixed-profile Bookmark Group
- Normal Booru feed/search grid

Verify that ordinary page headers remain visible and usable.

### Action Tests

Cover:

- Single-post Download from selection
- Multi-post Download
- Single-post Bookmark Management
- Multi-post Bookmark Management
- Bookmark Remove and Undo using BM-008 semantics
- Single-post View Tags
- Single-post View in Browser
- Favorite actions with supported and unsupported engines
- Mixed Danbooru/Rule34 selection
- Two profiles of the same engine with different permissions
- Unsupported actions hidden or disabled
- Action failure and retry
- Selection state after changes to the visible dataset
- Desktop context menu and toolbar sharing execution logic

Test actual service dispatch, not only visibility of buttons.

### Tooling

- Format modified Dart files with `fvm dart format`.
- Run focused widget/unit/integration tests.
- Analyze the affected files and modules.
- Run broader Post Grid, Search, Bookmark, and site-specific regression tests where justified.
- Exercise mobile behavior through Maestro with an exclusive emulator lease.
- Validate desktop-specific interactions through supported desktop/widget-test tooling.
- Report any platform behavior that could not be verified directly.

---

## 9. Implementation Strategy

A suggested sequence:

1. Inspect current Post Grid, gesture, selection, and context-menu behavior.
2. Introduce shared action definitions and origin-aware capability evaluation.
3. Reuse existing action services for single and multi-selection.
4. Introduce a centralized gesture dispatcher.
5. Add explicit `Select` and Disabled semantics to Grid Long Press settings.
6. Implement desktop modifier selection.
7. Move selection controls into the bottom toolbar.
8. Preserve existing AppBars, search controls, and filters during selection.
9. Replace old context-menu-to-selection mobile interaction.
10. Integrate Bookmark actions from BM-008.
11. Add tests and verify mobile/desktop regressions.

These are implementation stages within one work item, not separate required tickets.

Prefer incremental changes with tests over a large all-at-once rewrite.

The agent should avoid introducing an unnecessary generalized UI framework. The goal is to unify logical actions, not to replace Flutter's existing widget architecture.

---

## 10. Out of Scope

Do not implement:

- New server-side bulk APIs
- New account permissions
- Bulk actions that are unsupported by the underlying Booru engine
- Automatic execution on unsupported subsets of a selection
- Changing Image Viewer gesture defaults
- Removing desktop context menus
- Changing unrelated navigation shells
- Cloud or cross-device selection persistence
- A new global Bookmark deletion command
- Changes to Following Feed organization
- Unrelated search and filtering features

Do not expand the work into redesigning every existing Post Viewer toolbar. Reuse the common action logic there where practical, but prioritize the Post Grid and Selection Mode experience.

---

## 11. Dependencies and Workflow

BM-008 is completed and integrated. This implementation reuses its group membership, protected Default, final-membership removal and Undo services.

Use a dedicated branch and worktree.

Follow:
- `AGENTS.md`
- `docs/work/README.md`
- `docs/development_workflow.md`
- `docs/engineering_guidelines.md`

Claim the work item according to repository conventions.

Record agent/session, branch, worktree, progress, verification, and remaining limitations.

Do not modify the user's primary checkout. Do not integrate, push, or open a PR without explicit authorization.

## Definition of Done

Post selection works naturally on mobile and desktop.

Long Press selects by default on mobile while preserving configured gesture overrides. Desktop supports standard modifier-based selection and retains right-click context menus.

The normal page navigation and filters remain visible in Selection Mode, while selection controls and contextually available Post actions live in a responsive bottom toolbar.

Single-post and multi-post actions share underlying implementations and are safely capability-aware across different Booru engines and profiles.

## Implementation evidence (2026-10-20)

### Surface inventory and treatment

| Surface | Treatment |
| --- | --- |
| Normal/search/favorite and engine-specific PostGrid consumers | Shared ordered identity/index adapter; existing package drag, modifier dispatch, scoped shortcuts, shared actions and bottom controls. |
| Bookmark post grids | Same adapter; preserve the details/library refresh gate and remove the competing delayed identity remapper. Committed query/source changes clear selection; sort/refresh retain surviving identities. Existing source-aware bookmark downloads and membership Undo remain. |
| Cached Topic Feed posts | Custom item builder uses the same post-card/input path; shared source/capability-aware action selection replaces its separate mixed-source toolbar. Live updates reconcile stable identities. |
| Bookmark Group/folder browser | Typed folder/group keys in displayed order. All/Default cards are outside selection index space. Existing move/cycle protections remain; move targets are captured before destination dialogs. |
| Following Topics/folders | Typed folder/topic keys in displayed order; batch-progress row excluded. Folder recursion, Topic ID deduplication, confirmation and source ownership remain in domain services. |
| Downloads | Existing Select mode gets package hold-drag, stable task IDs, filtered scope clearing, scroll-controller attachment and touch-menu precedence. |
| Tag list | Existing Select mode keeps package drag; filtered rows and action targets share stable tag keys. Ranges and All cannot select filtered-out tags. |
| Advanced backup source selection | Existing explicit Select mode gets the same package drag and stable source IDs. |
| Bookmark export scope, ZIP import preview, transfer import source choices | Existing independent checkbox collections use a controlled package range projection. No additional visible selection mode; release returns Back ownership to the dialog. Hidden folder choices are retained. |
| Follow-to-multiple-folder picker | Range applies to the displayed independent folder destinations, preserving choices in other folders and existing nested navigation. The separate single-destination picker remains single-choice. |
| Export selection tree | Ranges cover independent source leaves and leaf siblings within a collection. Cascading/tri-state parent controls remain explicit, preserving dynamic "including future" membership; folders are not flattened. |
| Import recommendation/change trees | Per-item import action/conflict selectors, not an existing collection multi-selection mode. Preserve disabled/conflict/preflight semantics and tree navigation. |
| Feed overview/member management | Per-item operations only; no new bulk selection mode. |
| Layout customization, profile/destination pickers, warning acknowledgements and boolean settings | Reorder/configuration, single-choice or individual form controls; not collection bulk selection. Preserve their established gestures and semantics. |

### Significant implementation decisions

- Keep pinned `selection_mode` 0.0.6 and its recognizers, haptics, range reversal and auto-scroll. The controller adapter normalizes registration to indices, retains loaded unmounted selections, and reconciles identities once per dataset change. It uses the package's registration/drag hooks, with that dependency documented in source.
- Canonical post keys reuse `BookmarkIdentity` (including engine-provided stable page keys). Unknown rows get separate local tokens; replacements cannot transfer those selections. Collection kinds namespace equal entity IDs.
- A prefix append can continue a drag; reorder/removal cancels it, restores the committed selection and reconciles survivors. Deferred build notifications never perform delayed remapping or overwrite later selections.
- Grid Long Press defaults to Select. Explicit Select, Disabled and custom actions are distinct; viewer gestures and the global manual-selection default stay as configured. Kurumi gets a narrow touch-long-press policy that retains secondary-click and keyboard triggers.
- Generic actions share definitions/execution between clicked-post menus and selection. Immutable snapshots resolve each source/account, preflight all bulk sources, reject changed account resolution and retain selection after completion/failure. Single-only actions are presented through More. Existing favorite, bookmark and engine services provide the underlying operations.
- Selection headers/search/filter controls remain mounted. The footer participates in layout to reserve its real height, accounts for actual keyboard overlap and search position, and avoids the former scroll-compensation jump and fixed 72/36-pixel padding.

### Checked runtime candidate

- Base: `7d58c7d86786fe3f891cb2810f615fc9adef07d5`, freshly verified against `origin/develop` before implementation.
- Implementation: `4639a2b6e` and `e609f8adb25de020ce578b9675aade3e4d780a39`.
- Runtime candidate tree: `298e54b2898d07230419705175c2a557e84d1aaa` at `e609f8adb`. Subsequent changes to this record and the copied design documents are documentation only.
- Pinned Flutter: FVM 3.47.2. Ordinary test concurrency: 6, detected with `python3 scripts/physical_core_count.py`.
- Fresh worktree setup used `fvm flutter pub get`, the CLI package's `fvm dart pub get`, and `./gen.sh` for missing generated output. Changed localization inputs required `./gen.sh i18n`. Dependency versions were not upgraded.

### Automated verification

Final command: `./scripts/run_regression_tests.sh`, exit 0 on runtime candidate `e609f8adb25de020ce578b9675aade3e4d780a39`. All 4,181 application tests and 1,469 package/CLI tests passed; PR policy and Android release-script checks passed; all 72 Python tooling tests passed. `go_router` retains two existing `skip: true` tests (`routing_config_test.dart:142` and `go_router_test.dart:4743`), which were not changed. No failing test was skipped for UX-002. The FVM runner used detected concurrency 6 with no `TEST_CONCURRENCY` override.

Package results from that same complete run:

| Package | Passed | Existing skips |
| --- | ---: | ---: |
| booru_clients | 102 | 0 |
| boorusama_cli | 254 | 0 |
| cache_manager | 59 | 0 |
| coreutils | 191 | 0 |
| dtext | 59 | 0 |
| extended_image | 47 | 0 |
| filename_generator | 31 | 0 |
| flutter_sqlite3_migration | 45 | 0 |
| foundation | 65 | 0 |
| go_router | 436 | 2 |
| i18n_cli | 32 | 0 |
| kurumi | 132 | 0 |
| retriable | 16 | 0 |

Passing Flutter runs also emitted occasional Dart VM finalizer diagnostics and expected image/network errors from fixtures. The final result above records the assertions and command exit status; these diagnostics were not suppressed.

| Command / scope | Actual result |
| --- | --- |
| Before-change post-card characterization | 7 tests passed, including existing active hold-drag, cross-row reversal and ordinary scrolling. |
| `cd packages/kurumi && fvm flutter test --no-pub --concurrency=6` | 132 passed. Touch suppression retains right click, Context Menu, Shift+F10 and focus restoration. Also included in the complete runner. |
| Controller/input/bookmark focused run | 68 passed. Stable post/page/unknown keys, typed entity collisions, lazy rows, append/reorder/removal, scope changes, committed query clearing and membership Undo. |
| Navigation lifecycle/bookmark focused run | 45 passed. Editable Ctrl+A, modal Escape, inactive destination ownership, retained selection, header-relative edge auto-scroll and dialog Back ownership. |
| Export/picker consumer run | 22 passed. |
| Narrow layout/export-tree run | 21 passed. Top/bottom search, both pagination modes, 320 logical pixels, doubled text, open keyboard; explicit versus dynamic tree membership. |
| Broad keyboard/download/bookmark/feed/media-key consumer rerun | 237 passed after the focus and scroll-controller corrections described below. |
| Refresh/post-selection targeted run | 33 passed, including actual bookmark refresh retaining selected identities. |
| Final shared selection/post-flow/tag-flow run | 18 passed. Row replacement closes its clicked-post menu; same-scope refresh gates actions; filtered tag copy uses the visible stable key. |
| Final standalone Danbooru toolbar/post-card run | 26 passed. Empty account actions remain visible and disabled; one-post and overflow menus have distinct targets; Linux/macOS modifier dispatch and Escape retain real focus-path ownership. |
| Final native modal/profile and post-flow run | 16 passed. The real rating sheet retains the selected source profile while another profile owns the surrounding navigator. |
| Changed-file `fvm dart analyze` | 0 errors, 0 warnings, 33 informational style/deprecation notices. New shared selection/action files also analyzed separately with no issues. |
| `fvm dart format` on changed Dart files | Passed; 60 changed Dart files formatted. |
| `git diff --check` and relative Markdown file-link validation for the three task documents | Passed. |
| `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub` | Passed on the final runtime candidate. Gradle/AGP/Kotlin future-support warnings remain; no toolchain upgrade was attempted. |
| `fvm flutter build linux --debug --no-pub` | Blocked during CMake configuration: `ffmpeg_kit_flutter_new_min` requires unavailable `json-glib-1.0`. Native Linux execution was not performed. |

### Findings corrected during verification

- Selection updates during build and eager keyboard geometry reads caused framework/layout exceptions. Reconciliation now updates indices immediately but defers notifications, and keyboard overlap is measured after layout.
- An autofocus selection wrapper became a directional-navigation dead end. Shortcuts now bubble from real descendant focus; the wrapper cannot become a traversal target. Standalone card tests explicitly provide that descendant focus.
- Downloads initially shared a controller between horizontal filters and the vertical task list. The task list now has its own controller.
- Refresh temporarily clears the post controller's filter map. Scope reconciliation now compares committed filters after refresh, retaining same-scope identities while immediately disabling stale action targets.
- Disposing an old row could remove replacement geometry. Cleanup now drops only dead callbacks after layout while retaining loaded selections.
- Old feed tests expected generic actions to disappear with incompatible native payloads. The revised contract keeps safe Download/Bookmark actions and hides native-only actions; tests assert that behavior and unchanged global profile.
- Danbooru's old standalone toolbar fixture lacked source/bookmark providers. It now supplies them, retains disabled empty-selection account actions, and selects the actual overflow control when a single-post More control also exists.
- Navigator-owned rating sheets lost the invoking grid's provider scope. The sheet now receives an explicit source scope and immutable posts; a two-profile widget regression verifies the result. Native single-post menu callbacks also reject changed account resolution.

An early broad affected/application run was interrupted after failures had exposed the layout/focus/controller issues. The first complete runner finished its application stage with 4,167 passes and 13 failures (11 standalone Danbooru fixture/compatibility failures and two unfocused desktop Escape fixtures); it did not proceed to packages. A subsequent complete attempt was stopped when the modal source-scope defect was found. The final candidate is verified separately; none of those earlier runs is reported as a pass.

### Emulator qualification

- Device: exclusively leased `emulator-5554`; physical devices were not operated.
- The final dev APK was installed with `adb -s emulator-5554 install -r`, preserving existing data. APK SHA-256: `5605adbab7511ef169bd0175f0e56ffc387edab60fd12d42f5d3401636fbb16c`.
- Maestro verified default touch long press enters one-post selection, Search remains visible, Close/count/All are available, and Android system Back exits selection while retaining Browse.
- Maestro verified a normal fast swipe does not change the committed selection, Select All selects the 60 loaded posts, Deselect All retains usable zero-selection mode, and Back exits that mode.
- The final APK repeated the selection smoke flow successfully (17 Maestro commands). Exploratory system-card scripts were not full passes: All/Default navigate to their bookmark library rather than remaining on the group browser, and a final return-to-Browse Search visibility assertion failed. The observed system-card paths did not enter selection; the exact protected-card range behavior is qualified by application widget tests. No test collections or bookmarks were created. The emulator lease was released after testing.
- Continuous native hold-and-drag, reversal and edge auto-scroll remain unverified. Maestro exposes long press and swipe separately; a slow-swipe attempt did not establish the required continuous hold, so its range assertion failed. This is not counted as device acceptance. Controlled real-widget pointer tests cover those paths, including lazy edge auto-scroll and reversal.
- The emulator's Bookmark Group browser has only All and Default, and Following Topics is empty. Native folder/topic range acceptance therefore remains open; real application widget flows exercise populated collections and preserve protected cards, recursion/deduplication and domain actions.

### Acceptance matrix and remaining limits

| Revised acceptance area | Evidence / status |
| --- | --- |
| Active hold-drag, reversal, ordinary scrolling and edge auto-scroll | Real-widget pointer tests pass. Native touch entry, ordinary swipe and Back pass. Continuous native hold-drag/edge acceptance remains open. |
| Default/custom/Select/Disabled precedence and no duplicate callback | Actual post-card gesture dispatch tests pass, including custom Download and site action callbacks. Viewer defaults and global manual selection were preserved. |
| Desktop modifiers, focus guards, secondary/keyboard menus and Escape | Actual Linux/macOS-dispatch widget tests and complete Kurumi input tests pass. Native desktop run blocked by the Linux build dependency. |
| Stable source/page/unknown/entity keys and loaded index ordering | Controller, source snapshot, live feed, bookmark and real collection tests pass. |
| Append, refresh/reorder/removal, scope clearing and active empty mode | Controller and real application tests pass; emulator All/None/Back passes. |
| Retained destinations, dialogs, disposal and route-local profiles | Lifecycle/input tests and native modal two-profile regression pass. |
| Shared one/many actions, mixed origins, failure/retry snapshots | Real source-specific download flows, account snapshot checks and native action compatibility tests pass. Global profile is unchanged. |
| BM-008 membership, protected Default, final removal and Undo | Existing bookmark provider/details/folder suites passed both focused checks and the complete runner. No global Delete Everywhere action was added. |
| Following folder recursion, deduplication, confirmations and source execution | Existing domain services retained; Following suites and real folder/topic range flow pass. |
| Headers/search/filter/scroll stability and responsive footer | Real application layout tests pass for narrow/large-text/keyboard/search-position/pagination combinations; emulator Search/control visibility passes. |
| Other existing multi-select surfaces | See the inventory above. Independent checkbox ranges preserve choices outside the displayed collection. Hierarchical ranges are local to sibling leaves; cascading/dynamic parent choices remain explicit. Checkbox/tree adapters do not add edge auto-scroll to ancestor dialog/tree scrollables; ordinary scrolling between strokes retains the selections. |

Implementation and local automated qualification do not close the outstanding native continuous-gesture acceptance. Keep this work item in `in-progress` until that device gate is recorded; do not infer develop integration readiness from local tests alone. No push, merge, PR or release was performed or authorized.

To finish native acceptance, use the documented emulator lease procedure, populate non-sensitive disposable Bookmark Group/folder and Following Topic/folder collections, enter the existing Select mode, hold a selectable row and drag across siblings, reverse within the same held gesture, then hold near the viewport edge and verify auto-scroll selects newly reached rows. Verify ordinary scrolling remains available, system cards/progress rows never become targets, and Back first cancels an active drag before closing committed selection. Repeat on a post grid and record actual outcomes. Leave unrelated user data and the physical phone untouched.


## Acceptance-feedback revision — 2026-10-20

This revision implements the subsequent Browse, Bookmark Groups and Following
Topics feedback. It supersedes earlier observations that empty mode always stays
open, that one-post selection has a separate More submenu, and that collections
only expose their old header actions. Earlier verification remains historical.
The task branch/worktree above was continued. Local `develop` and
`origin/develop` still resolve to `7d58c7d86786fe3f891cb2810f615fc9adef07d5`;
the separate historical UX-002 planning branch was preserved. The primary
checkout and other task worktrees were not modified.

### Resulting behavior

- Manually removing the final selected item closes mode, including a completed
  deselecting range. All/None deliberately retains empty mode. Empty mode exposes
  its controls and no post or collection actions. The existing package gesture
  recognizers, range reversal and edge auto-scroll are retained.
- Post selection uses one action row for one or many posts. Download, Bookmark
  and Favorite/Unfavorite are direct actions when supported. Secondary and
  Danbooru-specific actions share one overflow. The old generic single-post
  submenu and duplicated account-favorite-group entry were removed. The Bookmark
  popup retains its established local membership actions; it is distinct from
  the secondary-action overflow. Its accessible name now matches its label.
- Favorite preflights source/account support for the entire selection, resolves
  known status, adds missing favorites, and offers Unfavorite when all targets
  are favorited. Failures retain selection, and retry does not add completed
  targets again. Controlled repository tests cover partial failure, retry and
  bulk removal without changing the active global profile. Closed context menus
  do not load favorite status: the regression first reproduced two eager status
  requests during ordinary browsing, then verifies zero before opening a menu
  and a real lookup after opening it.
- Selection hides the bottom navigation immediately. Root popup dialogs suspend
  selection input while retaining its ownership of hidden navigation. Covering
  pages and other destinations still release that ownership. Cancelling Add to
  group returns to the same selected posts.
- Bookmark Groups and Following Topics share the bottom selection controls and
  action bar. Their Scaffold reserves its actual height. Bookmark Groups also
  consumes the shell's bottom inset so the last card is reachable above normal
  navigation. Headers and existing filters remain available.
- Bookmark common actions are Move and Delete; one group/folder supports Rename,
  and group-only selections support Duplicate. Names are collected before the
  duplicate batch mutates storage. Combined deletion expands folders, deduplicates
  groups and shared bookmark membership, protects Default, confirms once, and
  preserves rollback and active-target handling. A failed move retains selection.
- Following common actions include Move, Remove, Refresh and Mark read according
  to the full expanded target set. Single topic/folder actions include their
  applicable Edit, Info and Open feed operations. Manual same-kind sibling
  selections support Move up/down; filtered/date views retain their existing
  restrictions. Unsupported members do not disappear silently from a bulk action.
  Existing recursion, confirmations, local/manual-only topics and domain services
  are retained.

### Selection performance evidence

The unchanged bookmark fixture has 3,000 bookmarks and 20 group cards. Selecting
and deselecting one group produced 26 preview-sort operations totaling 183,978
microseconds before the change. The regression now records zero such operations
for those interactions. Preview lists are memoized by library state, sort and
shuffle inputs. Following similarly caches dataset-derived folder summaries,
previews and its body; selection updates only its selection-dependent builders.
Its regression checks preview-list identity across selection changes.

These are structural and controlled-host measurements. Widget interaction times
also include test-framework work and varied substantially; they do not establish
a physical-device frame-time improvement or prove the reported 100 ms pause is
absent on every device. No strict host-speed threshold was added.

### Feedback revision verification

Runtime commits: `fbcdaa1908de4c54defaf8275c6c9de08ce7debd`,
`177599174`, and final candidate
`5e01aaf78c57a379f4328a2224c02e67007df8b4`. Subsequent edits to this record
are documentation only. FVM Flutter 3.47.2 and detected ordinary concurrency 6
were used, with no test-concurrency override or dependency upgrade.

- `./scripts/run_regression_tests.sh` exited 0 on the final runtime candidate:
  4,196 application tests, 1,469 package/CLI tests, and 72 Python tooling tests
  passed. PR-policy and Android release-script checks passed. The same two
  existing Go Router skips remain; no failing test was skipped for this task.
  Passing runs still emitted occasional Dart VM finalizer diagnostics, as in
  the original verification; these were not suppressed.
- The earlier complete gate on `fbcdaa190` passed 4,195 application tests,
  1,469 package/CLI tests and 72 Python tooling tests, plus policy/release-script
  checks. A later runner was stopped when review added the popup accessibility
  label; it is not counted as final verification.
- The final context-menu/native-toolbar/post-selection targeted run passed all
  23 tests. The subsequent feedback-flow run, including Bookmark semantics,
  passed all six tests. Earlier focused checks covered real app narrow-width,
  doubled-text and keyboard layouts, collection selection, domain rollback,
  bulk reordering, modal ownership, and bookmark final-membership semantics.
- Changed-scope analysis before the final menu/label correction: zero errors,
  zero warnings and 30 informational notices. Analysis of all five files changed
  by those final corrections: no issues. Changed Dart files were formatted;
  `git diff --check` passed.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`
  passed on the final runtime candidate. Gradle/AGP/Kotlin future-support warnings
  remain. Final dev APK SHA-256:
  `1a2eef498ea5caabaf227d6cd77442b23ca66d2cb2a37cc6cea7de25b86be8fd`.

### Final APK emulator checks and limits

Only exclusively leased `emulator-5554` was operated. The final APK was installed
with `adb -s emulator-5554 install -r`, retaining data; UI control used Maestro
MCP. The physical phone was not operated. The lease was released afterward.

- A complete 32-command Browse flow passed: touch selection, direct Download and
  Bookmark, one More control, final manual deselection, All/None retaining empty
  controls without actions, Back, Add to group, cancellation and retained selection.
- A disposable empty bookmark group exposed Move, Delete, Rename and Duplicate.
  Manual final deselection restored navigation. A complete 15-command selection
  flow passed for All/None, empty action removal and deletion entry; confirmation
  removed only that group and preserved Default.
- A disposable empty Following folder passed a complete 19-command flow covering
  Move/Remove, manual final deselection, empty All/None mode and removal entry.
  Confirmation removed the temporary folder and restored the original empty
  Following state. Both disposable collections were deleted before lease release.
- Exploratory flows with an early launch synchronization failure and selectors
  that did not match the accessible Bookmark/folder labels were not passes. The
  Bookmark label was corrected and the final APK flows above passed; the Following
  card selector includes its aggregate accessible caption.
- Live account Favorite mutation was not performed; its behavior is covered by
  controlled application/repository tests. Populated mixed folder/topic actions
  and performance under a large native collection remain device-unverified.
- Continuous native hold-and-drag, reversal and edge auto-scroll remain open as
  described in the original record. Real-widget pointer regressions passed; no
  separate long-press/swipe script is claimed as continuous-gesture acceptance.
  Native Linux remains unqualified because the previously attempted build requires
  unavailable `json-glib-1.0`; that blocked build was not repeated for this revision.

All task changes are committed locally. No push, merge, PR or release was
performed. The outstanding native continuous-gesture gate keeps UX-002 in
`in-progress`; automated results do not close that gate.


## Action refinements and comparison setting — 2026-10-20

The subsequent user feedback is implemented on the existing branch/worktree.
Runtime commits are `7aaae5f04506b50e60957c80c30e37837456d60b`,
`fa19561b2ce960674f9c5f7932e04cbb8f8e2525`, and final candidate
`ef0789161191100fa7c6ab39536bb1c9cdd63213`. No other task or primary checkout
was changed. Local `develop` and `origin/develop` still have the recorded base.

### Resulting behavior and decisions

- Favorite uses the outline heart; Unfavorite uses the filled heart.
- The shared selection bar sizes for all inline actions and caps the complete
  row at five slots, including an overflow control when needed. Four actions
  therefore remain visible where they previously competed for three slots.
  Explicit menu-only actions, including disabled actions, stay in overflow.
  Bookmarks and Following both use this shared behavior.
- Duplicating groups immediately creates copies named `{name} Copy` in English,
  with a localized suffix in other supported translations. Both the normal menu
  and selection action use the same batch path; there are no naming dialogs.
  Existing snapshot preflight, memberships and rollback are retained. Default
  remains copyable from its normal menu without changing its system identity
  or membership; it remains excluded from collection selection/move/deletion.
- Successful Duplicate and Rename close bookmark selection. Move and Delete
  already close after success. Successful Following Mark read now also closes
  selection. Cancellation and failure retain selection for retry. Refresh and
  repeated manual reordering retain selection; established post action behavior
  and All/None semantics remain as previously qualified.
- Selection and folder-deletion confirmations show only nonzero counts, with
  singular/plural forms and the label "unique bookmarks". The scrollable dialog
  lists the counts below its permanent-deletion prompt. English and German
  resources were added; other locales use the existing base-language fallback.
- Following selection no longer includes Open feed, Settings, topic Edit or
  Details. Those normal per-item operations remain available outside selection.
- Refresh availability now uses the same folder capability rule as the normal
  menu: a folder can refresh when at least one recursive member has a supported
  profile. A mixed folder's manual-only members therefore do not hide Refresh.
  Every explicitly selected folder must support its folder operation, and every
  explicitly selected topic must support direct refresh. Existing per-topic
  refresh services process the deduplicated recursive target set; unsupported
  topics do not become network requests. Pending refresh disables the action.

The optional comparison switch is at Settings → Appearance → Image Grid →
"Open post menu on long press". It defaults off, including when loading old or
malformed settings, and persists through the normal settings repository. Enabling
it changes only default inactive post-grid entry: hold opens the existing context
menu and Select enters the existing mode. Explicit Select, Disabled and custom
long-press assignments retain precedence. The profile gesture editor's Default
label follows the switch. Viewer and collection gestures, active hold-and-drag,
range reversal, modifiers, selection identity and action semantics are unchanged.

### Back ownership correction

Native comparison testing exposed a root-menu Back defect: Android exited the
activity instead of dispatching Back to the menu. A Router BackButtonListener
alone did not advertise internal pop handling. An open Kurumi context menu now
owns one LocalHistoryEntry on its current route, with AppBar dismissal disabled.
Local history alone did not fix native Back: the pinned Flutter SDK does not
publish a NavigationNotification when local history changes. The menu therefore
also publishes its current route capability after changes, using route-owned
context so disposal cleans up correctly. It releases the entry on dismissal or
disposal; native Back now closes the menu. Existing menu listeners, Escape
handling and focus restoration remain.
The new package regression reproduced missing local Back history before the fix,
then verifies system Back, outside dismissal and disposal cleanup. The actual
routed application also verifies Back closes the menu and retains Browse.

### Verification

- `./gen.sh i18n`: validation and generation passed for the changed English and
  German inputs; generated runtime output was refreshed without dependency changes.
- Affected application/widget/domain/layout checks passed all 201 tests on the
  action/comparison candidate. After the Back correction, all 133 Kurumi package
  tests and all 24 related application/native-toolbar/post-menu tests passed.
- Changed-file analysis: zero errors, zero warnings, 26 informational notices.
  The two changed Kurumi files also analyzed with no issues. Changed Dart files
  were formatted and `git diff --check` passed.
- The existing French toolbar fixture now waits for the asynchronous account
  capability result before clicking overflow. Its original click occurred while
  the new inline rating action moved the overflow control. The reduced test
  passed after waiting for that result. Temporary diagnostics and the unrelated
  fixture-height experiment were removed.
- `./scripts/run_regression_tests.sh` exited 0 on final runtime candidate
  `ef0789161191100fa7c6ab39536bb1c9cdd63213`: all 4,220 application tests,
  1,470 package/CLI tests across 13 packages, and 72 Python tooling tests passed.
  PR-policy and Android release-script checks passed. The two existing Go Router
  skips remain; no failing test was skipped for this revision. Ordinary test
  concurrency was 6. Passing runs still emitted occasional Dart VM finalizer and
  expected fixture image/network diagnostics; these were not suppressed.
- Earlier complete runners were interrupted to include the native Back fixes;
  neither is counted as a complete pass. Subsequent changes to this record are
  documentation only; runtime sources, tests and generated inputs are unchanged.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`
  passed on the final runtime candidate. Existing toolchain future-support
  warnings remain; no toolchain upgrade was attempted. APK SHA-256:
  `ea6d26af8a56bb5aa9913dc3279fa8cfd546eba409c83d980b401b80dd183f31`.

### Native refinement qualification

Only exclusively leased `emulator-5554` was operated, through Maestro MCP for UI
control. The APK was installed with `adb -s emulator-5554 install -r`, preserving
existing data. The physical phone was not operated.

- The action/comparison APK passed a complete 17-command flow verifying the
  switch, opening the menu with long press, choosing Select and adding a second
  post normally. The final Back-corrected runtime also retains this path in the
  real application regression suite.
- The final APK passed a complete nine-command cold-launch flow: the enabled
  preference survived process restart, long press opened Select, and Android
  system Back dismissed the menu while retaining Browse. It passed a separate
  19-command flow restoring the switch to off and confirming direct selection
  returns without a menu.
- A complete 20-command bookmark flow verified four direct actions (Move, Rename,
  Duplicate, Delete), immediate creation of a Copy group without a dialog,
  selection closure afterward and selection of both groups for deletion.
- The final 11-command deletion/cleanup flow verified exactly the nonzero count
  `2 bookmark groups`, without zero-folder or unique-bookmark entries. It deleted
  both disposable groups, preserved Default and returned to Browse. The switch
  was left off, both QA groups were removed, and the lease was released.
- Earlier native Back runs failed and exited the activity before the notification
  correction; these are not counted as passes. A launch attempted while APK
  installation was still completing also failed its post-loading assertion;
  the qualifying flow ran after installation reported Success.

Continuous native hold-and-drag/reversal/edge auto-scroll and physical-device
frame-time acceptance remain open. Populated mixed-folder refresh is covered by
controlled application tests; no live account Favorite changes are made for this
revision. Keep UX-002 in progress for its documented native acceptance gate.
All work remains local; no push, merge, PR or release is authorized or performed.

## Viewer return navigation animation — 2026-10-20

Runtime candidate: `095d1cdbf`, verified in the existing isolated worktree.

Feedback: returning from a post viewer abruptly recreated the bottom navigation
bar after the viewer transition. The shell removed the entire bar while
`viewerOpen` was true, discarding its `AnimatedSlide` state. A newly mounted bar
started at its visible target instead of animating to it.

The shell now retains the hidden bar with `Visibility(maintainState: true)`.
Viewer entry immediately positions it offscreen; viewer dismissal restores the
existing 160 ms slide. A bar hidden by scrolling stays hidden, and disabled
animations restore it immediately. Viewer clearance, focus/input blocking and
instant selection entry retain their existing behavior.

Regression evidence:

- Before the fix, the animation-state regression failed at 320, 390 and 768 px
  because the original state had been disposed; the 1280 px rail case passed.
- `fvm flutter test --no-pub --concurrency=6 test/core/navigation
  test/application/navigation_viewer_lifecycle_test.dart
  test/application/selection_feedback_flow_test.dart
  test/application/soft_keyboard_search_flow_test.dart --reporter expanded`:
  75 passed, including actual system-Back viewer dismissal and intermediate
  animation-frame checks.
- The final four-case `navigation_chrome_test.dart` rerun also passed after adding
  reduced-motion checks. It covers 320/390/768/1280 px layouts with 2x text,
  previously visible/scroll-hidden bars, viewer padding and immediate restoration
  with disabled animations.
- Formatting the three changed Dart files and `git diff --check` passed.
  Analysis of those files reported zero errors/warnings and six existing infos
  (five unawaited-future notices and one braces notice in unchanged code).
- `./scripts/run_regression_tests.sh` passed with exit 0 on the unchanged runtime
  state committed as `095d1cdbf`: 4,221 application tests and 1,470 package/CLI
  tests across all 13 packages passed. The two existing GoRouter skips remain.
  Pull-request policy checks, Android release-script tests and all 72 Python
  tooling tests passed. `TEST_CONCURRENCY` was unset; the detected physical-core
  concurrency was six. Log: `/tmp/ux002-viewer-return-complete.log`.
- Both local Markdown links in this task record resolve. This documentation-only
  update reuses the complete pass on the same runtime candidate.

This revision has no emulator, APK-build or physical-device timing result.
The controlled widget tests establish the transition geometry; the existing
native continuous hold-and-drag acceptance gate remains open.

## Immediate navigation restoration preference — 2026-10-20

Runtime candidate: `b495d2041`, verified in the existing isolated worktree.

The user prefers the timeline's navigation bar to be immediately in its original
position on return. This supersedes the separate 160 ms restoration animation
in the preceding revision.

The viewer now reports its reverse route-animation phase independently from
being open. The shell preserves the bar's timeline position while hidden and
reveals it at the start of the reverse transition. The viewer keeps layout
clearance and input ownership until disposal, so the visible bar cannot accept
navigation input during the outgoing transition. A previously scroll-hidden bar
stays hidden. Cancelling the closing state hides the bar again.

Verification:

- The 75-test navigation, viewer, selection-feedback and keyboard consumer run
  passed. The actual system-Back viewer test now checks that the bar is already
  at exactly its pre-viewer rectangle while the viewer is still mounted and
  closing, and stays there after disposal.
- Shell coverage includes visible/scroll-hidden positions, cancellation of the
  closing state, preserved viewer padding, disabled animations and
  320/390/768/1280 px widths with 2x text.
- All five changed Dart files were formatted. Their analysis reported zero
  errors/warnings and seven existing infos in unchanged code (five unawaited
  futures and two braces notices). `git diff --check` passed.
- `./scripts/run_regression_tests.sh` passed with exit 0 on the unchanged runtime
  state committed as `b495d2041`: all 4,221 application tests and 1,470 package/CLI
  tests across 13 packages passed. The two existing GoRouter skips remain.
  Pull-request policy checks, Android release-script tests and all 72 Python
  tooling tests passed. `TEST_CONCURRENCY` was unset; physical-core concurrency
  was six. Log: `/tmp/ux002-immediate-viewer-complete.log`.
- Both local Markdown links in this record resolve. This documentation-only
  update reuses the complete pass on the same runtime candidate.

No emulator, APK build, physical-device timing or native predictive-Back gesture
check was performed for this revision. The existing native continuous
hold-and-drag acceptance gate remains open; UX-002 stays in progress.

## Integration preparation on hold — 2026-10-20

The user initially authorized local integration, then asked to wait before
merging. No integration into `develop`, push, PR or release was performed.
Local `develop` remains `9be0d3e65` in its existing checkout; the primary checkout
was preserved. Keep this task branch/worktree for the unfinished preparation
and native acceptance work.

The task branch contains combined candidate `e06d2631d`: UX-002 tip `33f817dd2`
reconciled with `9be0d3e65` (portable post/search link files). Three additive
conflicts were resolved by preserving both imports and both translation keys.
`./gen.sh i18n` passed. Analysis of the three overlapping Dart files reported
zero errors/warnings and six existing infos.

`./scripts/run_regression_tests.sh` on this combination found two failures in
`post_selection_layout_flow_test.dart`: top-positioned search at 320 px and 2x
text in both infinite and paginated modes. The application run was interrupted
with exit 130 after these failures; package/CLI and tooling phases did not run.
Log: `/tmp/ux002-develop-integration-complete.log`. This is not a qualifying pass.

The infinite-mode failure reproduced serially. The new search-link button leaves
the result label only 60 px wide; the label becomes 392 px tall and pushes the
first post out of view. The eventual fix must preserve the existing result-count
and Follow-button row behavior, including the 240 px enlarged-text picker flow,
while keeping the new link action accessible. An experimental wrapping layout
was not retained because it broke that existing consumer contract; its patch is
available at `/tmp/ux002-header-wrap-experiment.patch`.

The preceding complete pass on `b495d2041` remains evidence for the original
UX-002 runtime only. A complete pass on the final combined candidate is still
required before integration can resume after user approval.

## Scroll-driven bottom navigation — 2026-10-20

Runtime candidate: `9b1bd0f22`. The user requested another local change while
keeping the merge on hold.

The bottom navigation now follows vertical post-list scroll distance directly,
including the fling from that gesture. Its full travel includes the system
bottom inset. Direction changes move it immediately, with no separate reveal
or hide animation during scrolling. At scroll end, more than 50% hidden snaps
fully hidden; 50% or less snaps fully visible, matching the search bar's
half-height rule. The existing 160 ms animation is used only for settling.

Programmatic scrolls, nested/horizontal scrolls, overscroll, inactive routes,
wide layouts without a bottom bar and disabled auto-hide cannot move it.
Selection, menu and viewer handling remain in control of their chrome states;
the immediate viewer-return behavior is preserved. Progress updates rebuild
only the translation wrapper, retaining the bar contents and shell subtree.

Verification on this runtime candidate:

- `fvm flutter test --no-pub --concurrency=6 test/core/navigation
  test/application/navigation_scroll_flow_test.dart
  test/application/navigation_viewer_lifecycle_test.dart
  test/application/selection_feedback_flow_test.dart
  test/application/soft_keyboard_search_flow_test.dart --reporter expanded`:
  81 passed. Log: `/tmp/ux002-scroll-navigation-final-consumers.log`.
- Real controlled grid pointers verify pixel-for-pixel movement while held,
  immediate reversal, no movement while held still, safe-area travel and both
  snap outcomes. Controller/boundary tests cover the exact 50% threshold,
  direct/fling versus programmatic input, disabled auto-hide, inactive routes,
  horizontal notifications and absent bottom bars.
- Shell tests verify partial translation without time-based catch-up, animated
  settling, retained bar contents, 320/390/768/1280 px layouts at 2x text,
  selection/menu handling, reduced motion and viewer return. Keyboard consumer
  cases passed at their existing phone/landscape sizes.
- All eight changed Dart files were formatted. Analysis found zero errors and
  warnings, with one existing braces info in `navigation_chrome_test.dart`.
  The analyzer exits 1 for that info. `git diff --check` passed.
- The initial targeted attempt had a synthetic gesture fixture compile error
  (`DragUpdateDetails.globalPosition` is required by the pinned SDK). The fixture
  was corrected; the final 81-test run above is the qualifying targeted result.

This bounded navigation change received affected/consumer verification. No new
complete application/package/tooling gate, APK build, emulator or physical-device
check was performed. The previous combined-candidate layout failures remain
unresolved, and a complete pass on the final combined state is still required
before integration. Local `develop` remains `9be0d3e65`; the merge stays on hold.

## Authorized local integration — 2026-10-20

The user renewed local merge approval after accepting scroll-driven navigation.
The combined runtime candidate is `a2ba69565`, incorporating the complete UX-002
branch and local `develop` base `9be0d3e65` (portable post/search link files).
The approved integration method is one Conventional Commit squash into local
`develop`, using the clean `.worktrees/develop` checkout and preserving the
primary checkout. The earlier `.worktrees/rebase-post-009` develop checkout was
removed externally while verification ran; `develop` remained at `9be0d3e65`.
Its replacement therefore has the same integration base and reuses the complete
pass on the unchanged combined runtime candidate.

The two search-layout failures from the first integration attempt were repaired.
The count and the grouped Share/Follow controls now share bounded flexible
space, preserving their established single-row layout. This prevents the new
share action from squeezing the enlarged result label into a 392 px column and
pushing post tiles out of view. Existing layout tests now also check all three
controls' bounds at 800/320/240 px and enlarged text. The existing 240 px Follow
picker interaction remains intact.

Checks performed:

- The affected search-layout, selection feedback, link-sharing and Follow
  consumer run passed all 36 tests. After strengthening the bounds assertions,
  the final layout/Follow rerun passed all 25 tests.
  Logs: `/tmp/ux002-merge-header-qualified.log` and
  `/tmp/ux002-merge-header-final-tests.log`.
- Both changed Dart files were formatted. Their analysis reported zero
  errors/warnings and one existing `unnecessary_unawaited` info in unchanged test
  code. The analyzer exits 1 for that info.
- `git diff develop --check` passed after replacing the task record's two
  Markdown hard-break trailing spaces with blank lines.
- `./scripts/run_regression_tests.sh` passed with exit 0 on combined runtime
  candidate `a2ba69565`: 4,293 application tests and 1,470 package/CLI tests across
  all 13 packages passed. The two existing GoRouter skips remain unchanged.
  Pull-request policy checks, Android release-script checks and all 72 Python
  tooling tests passed. Detected physical-core concurrency was six;
  `TEST_CONCURRENCY` was unset. Log: `/tmp/ux002-merge-final-complete.log`.
- This final task-record update changes documentation only and reuses that
  complete pass. Local squash integration must preserve this source tree and
  the already-qualified runtime; verify equality and checkout cleanliness after
  integration. The integrated commit identifier is reported in the final task
  response and local Git history.

No new APK build, emulator run or physical-device/native predictive-Back result
is claimed for this integration. Keep this record in progress and retain its task
branch/worktree for the outstanding native continuous hold-and-drag acceptance.
No push, PR or release is included in the local integration authorization.
