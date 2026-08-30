## Why

Direct bookmark backups currently export every bookmark and every group as one payload. Users need a way to export only selected bookmark groups, both to reduce backup size and to share a focused subset without changing the existing additive import behavior.

## What Changes

- Keep the four explicit bookmark backup actions: Export, Import, Export to clipboard, and Import from clipboard.
- Make both direct export actions open a bookmark export-scope dialog before writing or copying data.
- Default the scope to all bookmarks and do not remember the previous selection.
- Allow users to export selected real groups and a selectable No group scope.
- Export the union of bookmarks in the selected scopes once, preserving only the selected group memberships.
- Preserve empty selected groups in the exported group metadata.
- Leave bookmark import behavior and the existing JSON structure unchanged.
- Keep full ZIP backups unfiltered, including all bookmarks and all groups without a group-selection dialog.

## Capabilities

### New Capabilities

- `bookmark-export-selection`: Select the bookmark scope for direct file and clipboard exports while preserving group metadata and existing export compatibility.

### Modified Capabilities

None.

## Impact

- The bookmark backup source must build filtered bookmark and group data for a selected export scope.
- The direct backup tile export flow must present the scope selector before the file picker or clipboard operation.
- The existing JSON encoder can continue using the current `data` and optional `groups` fields.
- Full ZIP backup generation remains on its existing all-data path.
- New UI strings and focused unit/widget tests will be needed.
