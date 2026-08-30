## Why

Boorusama currently stores local bookmarks in one ungrouped collection, while Danbooru's separate favorite-group feature is server-specific. Users need a local equivalent that works across all booru types without depending on server support, while preserving the existing bookmark workflow.

## What Changes

- Add global local bookmark groups that can contain bookmarks from any booru type or configuration.
- Allow a bookmark to belong to multiple groups, or to remain ungrouped.
- Add `All` and `No Group` system views to the existing bookmarks page.
- Open the bookmarks route with a dedicated full-screen group browser before showing the existing bookmarks view.
- Preview each group as a square card containing up to the first four images produced by the existing group ordering, with the group name overlaid near the top.
- Keep empty preview cells transparent, separate populated cells with a small visible gap, and use a subtle outline to show the extent of an otherwise empty group card without a gray fill rectangle.
- Provide group creation through a compact `+` control in the browser's top-right corner.
- Keep the browser open after creating a group; creating an empty group SHALL not navigate into an unusable empty content view.
- Add group management to the group browser, including create, duplicate, rename, and delete operations.
- Replace the current single-action bookmark context-menu entry with one `Bookmark` action that opens an in-place group picker; selecting a group toggles membership and updates the active target.
- Make the bookmark button target the active/last-selected group, with long-press group selection and a visible target label.
- Show a small downward-arrow affordance on the bookmark button, aligned with the existing download-button affordance, to communicate that long press opens group actions; always show the normal button's target label below the icon with enough width for several characters before wrapping or ellipsizing.
- Keep the normal bookmark control in the same fixed toolbar slot and vertical center as neighboring action icons; position the single-line target label below the bookmark anchor without letting it change the icon's vertical alignment.
- Use the same standard icon-button press feedback and full hit target as the download control, including long-press handling for the bookmark glyph, arrow, and count-badge area.
- Present the long-press group picker as the same anchored popup style used by Downloads and hamburger menus, with a trailing `Active` badge on the current target row.
- Present the thumbnail-menu `Bookmark` action as an in-place replacement at the same popup position, reusing the post bookmark picker with leading membership icons, no thumbnail-context `Active` badge, and safe create-group dismissal.
- Give the thumbnail `Bookmark` action a right chevron, keep the replacement picker vertically compact, and provide a leading-arrow `Back` row separated from the group list by a divider.
- Show group membership with filled group icons in both group pickers, and show the active target with a simple small gray `Active` label only in the post bookmark picker rather than using a checkmark, border, background, or accent-color selection state in that picker.
- Open the create-group dialog from a stable navigator context after dismissing the hold menu so it remains safe during overlay teardown.
- Show an indicator and count when a bookmark belongs to groups other than the active target group.
- Delete a bookmark completely when removing its final named-group membership; removing one of several memberships only removes that membership.
- Show the existing `Bookmark added` and `Bookmark removed` success toasts for named-group additions and removals as well as `No Group` actions.
- Use normal sentence case for longer English labels and messages, retaining intentional title case only for names such as `Bookmark Groups`, `All`, and `No Group`.

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
