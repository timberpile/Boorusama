## 1. Local group persistence

- [x] 1.1 Define local group and bookmark-membership persistence models using separate Hive records and register their adapters without changing the existing bookmark record schema.
- [x] 1.2 Implement group and membership repository operations for create, rename, duplicate, delete, add, remove, membership lookup, and stale-membership pruning.
- [x] 1.3 Implement coordinated bookmark operations that create a bookmark before assigning a requested group, roll back a newly created bookmark if assignment fails, and delete all memberships for complete bookmark deletion.
- [x] 1.4 Add coverage for existing bookmarks loading in `No Group`, multiple memberships, duplicate-group membership copying, final-membership removal, orphan cleanup, and complete deletion.

## 2. Bookmark and target state

- [x] 2.1 Extend bookmark state loading so widgets can determine named memberships, total named-group count, and ungrouped status for each bookmark.
- [x] 2.2 Add persisted active-target state with `No Group` as the default, fallback when a saved group no longer exists, and the specified behavior for selecting `All`.
- [x] 2.3 Add provider-level operations for adding to, removing from, and deleting bookmarks through the group-aware workflow while keeping existing bookmark-page state updates consistent.
- [x] 2.4 Delete the bookmark record when removing its final named membership, while preserving it when another named membership remains.

## 3. Bookmarks page and group management

- [x] 3.1 Add the `All`, `No Group`, and named-group selector to the existing bookmarks page without disrupting current tag, source, sort, and shuffle filters.
- [x] 3.2 Add create, duplicate, and rename flows with group-name validation and active-target updates.
- [x] 3.3 Delete empty groups without prompting; always confirm non-empty groups with one standard confirmation containing the total bookmark count, deleting bookmarks that belong to no other group.
- [x] 3.4 Refresh the bookmarks page, group selector, and membership state after every group or membership mutation, including when the currently displayed group is deleted.
- [x] 3.5 Refine the full-screen group browser as the initial bookmarks route with square cards and remove the old horizontal selector from the bookmarks content view.
- [x] 3.6 Build `All`, `No Group`, and named-group cards with up to the first four sorted previews in a 2x2 grid, bookmark-grid preview quality, transparent missing cells, and overlaid names.
- [x] 3.7 Keep the compact top-right `+` group-creation action, use `Create` for the dialog confirmation, and expose only `Duplicate`, `Rename`, and `Delete` on named-card menus.
- [x] 3.8 Open the existing bookmarks content view when a browser card is selected, synchronize the selected group and active bookmark target, and show the browser/group names in their respective titles.
- [x] 3.9 Render transparent group-card preview surfaces with small image gaps and a subtle outline, and keep the browser open after creating a new empty group.
- [x] 3.10 Remove the orphan-preservation deletion choice and use one count-bearing confirmation before deleting non-empty groups and their unique bookmarks.

## 4. Post bookmark controls

- [x] 4.1 Update the bookmark button to use active-group membership for its filled state and to display a responsive active-target label below the icon.
- [x] 4.2 Add the other-groups count badge using the total number of named groups containing the bookmark, including the active group when applicable.
- [x] 4.3 Add long-press group selection, including named groups, the `No Group` target, and `Create new group`; show membership with a filled group icon, show the active target with a low-emphasis `Active` badge, and hide `No Group` when it cannot be used for removal.
- [x] 4.4 Implement single-tap behavior for new ungrouped bookmarks, named-group additions, named-group removals, and the protected grouped-post behavior when `No Group` is active; label the ungrouped direct action `Add bookmark`.
- [x] 4.5 Add the bookmark button's small downward-arrow long-press affordance and widen its active-target label so it can show several characters before wrapping or ellipsizing.
- [x] 4.6 Replace picker checkmarks/accent selection styling with filled membership icons and a small gray `Active` label, while keeping `No Group` hidden for grouped-post removal.
- [x] 4.7 Align the bookmark dropdown affordance with the download control, always show the normal button's active-target label, and open hold-menu dialogs from a stable navigator context.
- [x] 4.8 Keep the normal bookmark glyph in the neighboring toolbar icons' fixed vertical slot and center its single-line, reduced-size label on the glyph while treating the arrow and count badge as appendages.
- [x] 4.9 Use the same icon-button press feedback and full long-press hit target as the download control for the normal bookmark button.
- [x] 4.10 Replace the bookmark hold bottom sheet with an anchored popup matching the download and hamburger menu style, including a trailing `Active` badge slot and safe create-group dialog dismissal.
- [x] 4.11 Show the existing bookmark success toasts after successful named-group additions and removals in post and thumbnail bookmark interactions.

## 5. Thumbnail context menus

- [x] 5.1 Replace the existing local add-to-bookmark item in the general thumbnail context menu with one `Bookmark` entry between exactly one leading and one trailing divider.
- [x] 5.2 Apply the same local `Bookmark` entry to the Danbooru thumbnail context menu while keeping Danbooru's server-side favorite-group action separate.
- [x] 5.3 Replace the thumbnail bookmark actions with one `Bookmark` entry whose in-place group picker toggles membership, updates the active target, and uses leading membership icons without an `Active` badge.
- [x] 5.4 Remove the complete-delete context-menu action and its localization while retaining existing bookmarks-page deletion flows.
- [x] 5.5 Keep exactly one divider before and one divider after the thumbnail `Bookmark` entry without duplicate separators.
- [x] 5.6 Replace the thumbnail context-menu contents in place at the same popup position, reuse the post bookmark group's toggle behavior, omit the thumbnail-context `Active` badge, and safely dismiss before opening group-creation dialogs.
- [x] 5.7 Add the `Bookmark` right chevron, compact the replacement picker padding, and add a leading-arrow `Back` row with a divider that restores the original menu.

## 6. Localization and verification

- [x] 6.1 Add localization entries for group names, selectors, bookmark-picker labels, target labels, count-bearing deletion confirmations, and errors.
- [x] 6.2 Regenerate localization and other generated sources required by the repository.
- [x] 6.3 Add focused provider, repository, and widget tests for group filtering, preview selection, and transparent missing preview cells.
- [x] 6.4 Run formatting, static analysis, targeted tests, and the repository's applicable validation scripts; resolve any regressions in existing bookmark behavior.
- [x] 6.5 Run formatting, static analysis, focused bookmark-group tests, and strict OpenSpec validation for the revised browser, picker, and bookmark-control behavior, including the in-place thumbnail bookmark picker and Back navigation.
- [x] 6.6 Add and run focused coverage for final-membership removal deleting the bookmark and multi-membership removal preserving it; rerun formatting, analysis, and strict OpenSpec validation.
- [x] 6.7 Verify named-group success-toast behavior with focused tests and rerun formatting, analysis, and strict OpenSpec validation.
