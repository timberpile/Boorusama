## Why

Boorusama currently stores local bookmarks in one ungrouped collection, while Danbooru's separate favorite-group feature is server-specific. Users need a local equivalent that works across all booru types without depending on server support, while preserving the existing bookmark workflow.

## What Changes

- Add global local bookmark groups that can contain bookmarks from any booru type or configuration.
- Allow a bookmark to belong to multiple groups, or to remain ungrouped.
- Add `All` and `No Group` system views to the existing bookmarks page.
- Open the bookmarks route with a dedicated full-screen masonry group browser before showing the existing bookmarks view.
- Preview each group with the first image produced by the existing group ordering and overlay the group name near the top of the image.
- Provide group creation through a compact `+` control in the browser's top-right corner.
- Add group selection and management to the bookmarks page, including create, duplicate, rename, and delete operations.
- Replace the current single-action bookmark context-menu entry with group-aware add, remove, and complete-delete actions.
- Make the bookmark button target the active/last-selected group, with long-press group selection and a visible target label.
- Show an indicator and count when a bookmark belongs to groups other than the active target group.
- Protect users from accidental data loss when deleting groups or removing the final group membership, with confirmation behavior based on whether a non-empty group has orphaned bookmarks.
- Use title case for important nouns in user-facing bookmark-group labels and actions.

## Capabilities

### New Capabilities

- `local-bookmark-groups`: Manage global local bookmark groups and group membership through the bookmarks page and post bookmark interactions.

### Modified Capabilities

None.

## Impact

- Local bookmark domain model, persistence, and state management.
- Bookmarks page filtering and group-management UI.
- Full-screen bookmark group browser and group preview loading.
- Post detail and thumbnail context-menu bookmark actions.
- Bookmark button interaction and visual state.
- Localization, generated code, and automated tests.
