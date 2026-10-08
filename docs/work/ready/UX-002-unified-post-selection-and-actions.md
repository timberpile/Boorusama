# UX-002 — Unified Post Selection and Action System

Priority: Normal  
Affected features: Post Grid, Post Context Menus, multi-selection, Bookmark actions, Downloads, Booru-specific actions, gestures, desktop input, navigation  
Dependencies: BM-008 (Default Bookmark Group and consistent membership semantics)

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

### Selection and Input

- [ ] Mobile Long Press selects the pressed post when no explicit custom action is configured.
- [ ] A single selected post enters the same selection mode as multiple selected posts.
- [ ] Tapping further posts toggles their selection.
- [ ] Existing explicitly configured Long Press actions continue working.
- [ ] `Select` can be configured as a Grid Long Press action.
- [ ] An explicit Disabled option is available if required.
- [ ] Image Viewer gestures remain unchanged.
- [ ] Desktop Ctrl/Cmd+Click toggles post selection.
- [ ] Desktop Shift+Click performs range selection.
- [ ] Desktop Ctrl/Cmd+Shift+Click supports additive range selection.
- [ ] Desktop Ctrl/Cmd+A selects currently loaded posts when appropriate.
- [ ] Desktop Right Click retains the context menu.
- [ ] Escape and Back exit selection mode correctly.
- [ ] Gestures never accidentally trigger two conflicting operations.
- [ ] The existing grid-menu Select action remains available.

### Layout and Navigation

- [ ] Existing AppBar remains visible in Selection Mode.
- [ ] Search and tag-filter widgets remain visible.
- [ ] Sorting and grid configuration remain accessible.
- [ ] Selection controls are moved to the bottom toolbar.
- [ ] The upper replacement Selection AppBar is removed from Post Grid pages.
- [ ] The bottom toolbar displays Close, selected count, and Select All/None.
- [ ] Post actions appear in the same bottom action area.
- [ ] The toolbar is responsive and does not cover grid content.
- [ ] Entering or leaving selection does not cause unnecessary scroll jumps.
- [ ] Narrow screens and enlarged text are supported.

### Shared Actions

- [ ] One common action-dispatch architecture serves single and multi-selection.
- [ ] Single-post-only actions are available for a single selected post.
- [ ] Multi-post actions use the same underlying services where applicable.
- [ ] Site/profile permissions are evaluated for selected posts.
- [ ] Mixed-origin selections retain compatible common actions.
- [ ] Unsupported engine-specific actions do not run on incompatible posts.
- [ ] Bookmark Management follows BM-008 semantics.
- [ ] Failed actions display feedback without corrupting selection state.
- [ ] Selection is stable across sorting and safe during refresh/filter changes.

### Regression

- [ ] Normal tapping still opens posts.
- [ ] Post Viewer navigation remains functional.
- [ ] Existing Download behavior remains correct.
- [ ] Existing Bookmark Management behavior remains correct apart from approved BM-008 changes.
- [ ] Existing Favorite and engine-specific actions remain accessible.
- [ ] Custom gestures are not overwritten.
- [ ] Desktop context menus remain functional.
- [ ] Normal search, filtering, and sorting remain usable.
- [ ] Bookmark Groups with multiple profiles remain supported.

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

BM-008 should be implemented and integrated before finalizing Bookmark-specific behavior in this work item.

If UX-002 starts earlier, coordinate with the BM-008 implementer and keep Bookmark action changes isolated until their semantics are stable.

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