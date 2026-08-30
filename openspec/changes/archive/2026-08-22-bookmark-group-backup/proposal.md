## Why

Boorusama already exports and imports local bookmarks, but it loses the local group memberships that organize those bookmarks. Users need a backup format that preserves groups without changing existing bookmark records or making imports destructive.

## What Changes

- Preserve the existing bookmark backup `data` array and bookmark object shape.
- Add an optional top-level `groups` array containing each group's name and the exported bookmark IDs assigned to it.
- Export all local bookmark groups and their memberships alongside bookmarks.
- Import bookmarks first, resolve exported bookmark references to local bookmark records, then restore memberships.
- Reuse an existing group when its name matches case-insensitively; otherwise create it.
- Merge memberships without removing existing bookmarks, groups, or memberships.
- Continue accepting legacy bookmark-only JSON files.

## Capabilities

### New Capabilities

- `bookmark-backup-groups`: Preserve local bookmark groups and memberships in bookmark JSON backup export and import.

### Modified Capabilities

None.

## Impact

- Bookmark backup payload parsing and encoding.
- Bookmark backup source export/import orchestration.
- Local bookmark-group repository lookups and membership writes.
- Backup and bookmark tests.
