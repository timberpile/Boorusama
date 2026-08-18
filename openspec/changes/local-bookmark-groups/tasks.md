## 1. Local group persistence

- [x] 1.1 Define local group and bookmark-membership persistence models using separate Hive records and register their adapters without changing the existing bookmark record schema.
- [x] 1.2 Implement group and membership repository operations for create, rename, duplicate, delete, add, remove, membership lookup, and stale-membership pruning.
- [x] 1.3 Implement coordinated bookmark operations that create a bookmark before assigning a requested group, roll back a newly created bookmark if assignment fails, and delete all memberships for complete bookmark deletion.
- [x] 1.4 Add coverage for existing bookmarks loading as `Ungrouped`, multiple memberships, duplicate-group membership copying, final-membership removal, orphan cleanup, and complete deletion.

## 2. Bookmark and target state

- [x] 2.1 Extend bookmark state loading so widgets can determine named memberships, total named-group count, and ungrouped status for each bookmark.
- [x] 2.2 Add persisted active-target state with `Ungrouped` as the default, fallback when a saved group no longer exists, and the specified behavior for selecting `All Bookmarks`.
- [x] 2.3 Add provider-level operations for adding to, removing from, and deleting bookmarks through the group-aware workflow while keeping existing bookmark-page state updates consistent.

## 3. Bookmarks page and group management

- [x] 3.1 Add the `All Bookmarks`, `Ungrouped`, and named-group selector to the existing bookmarks page without disrupting current tag, source, sort, and shuffle filters.
- [x] 3.2 Add create, duplicate, and rename flows with group-name validation and active-target updates.
- [x] 3.3 Add group deletion confirmation showing affected membership and orphan counts, with separate keep-ungrouped and delete-orphans outcomes.
- [x] 3.4 Refresh the bookmarks page, group selector, and membership state after every group or membership mutation, including when the currently displayed group is deleted.

## 4. Post bookmark controls

- [x] 4.1 Update the bookmark button to use active-group membership for its filled state and to display the active target label below the icon.
- [x] 4.2 Add the other-groups count badge using the total number of named groups containing the bookmark, including the active group when applicable.
- [x] 4.3 Add long-press group selection, including named groups, the `Ungrouped` target, and `Create new group`; selecting a new group shall add the current post and persist the target.
- [x] 4.4 Implement single-tap behavior for new ungrouped bookmarks, named-group additions, named-group removals, and the protected grouped-post behavior when `Ungrouped` is active.

## 5. Thumbnail context menus

- [x] 5.1 Replace the existing local add-to-bookmark item in the general thumbnail context menu with a dedicated bookmark section separated by a divider.
- [x] 5.2 Apply the same local bookmark section to the Danbooru thumbnail context menu while keeping Danbooru's server-side favorite-group action separate.
- [x] 5.3 Add `Add to...`, active-target add, `Remove from...`, and active-target removal actions with correct membership filtering and target updates.
- [x] 5.4 Add the confirmed `Delete bookmark completely` action as the separated destructive menu item.

## 6. Localization and verification

- [x] 6.1 Add localization entries for group names, selectors, add/remove actions, target labels, count descriptions, confirmations, orphan outcomes, and errors.
- [x] 6.2 Regenerate localization and other generated sources required by the repository.
- [ ] 6.3 Add provider, repository, and widget tests for group filtering, active-target behavior, button states, count badges, context-menu actions, and deletion outcomes.
- [ ] 6.4 Run formatting, static analysis, targeted tests, and the repository's applicable validation scripts; resolve any regressions in existing bookmark behavior.
