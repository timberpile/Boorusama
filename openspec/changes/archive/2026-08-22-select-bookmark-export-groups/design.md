## Context

The bookmark backup source already writes bookmark objects to the top-level `data` array and group metadata to the optional top-level `groups` field. The generic backup tile exposes four actions, while the full ZIP backup invokes source exports without an interactive per-source scope. The new selection is therefore a direct-export concern and must not alter the shared import or ZIP paths.

## Goals / Non-Goals

**Goals:**

- Add one consistent scope-selection flow to direct bookmark file and clipboard exports.
- Keep the four existing actions and preserve the current all-bookmarks default.
- Filter bookmarks and group memberships in memory before the existing JSON encoding step.
- Keep the export format and additive importer compatible.
- Keep full ZIP backups on the existing all-data path.

**Non-Goals:**

- Adding group selection to full ZIP backups.
- Persisting the user's last export selection.
- Changing bookmark import merge, group matching, or deletion behavior.
- Adding device-local group IDs to the exported format.

## Decisions

### Represent the selection as runtime-only bookmark export scope

Introduce a bookmark-specific export-scope value that represents either all bookmarks or a set of selected real group IDs plus an optional No group flag. These IDs are used only while reading the current device's repository; serialized group metadata continues to use group names and file-local bookmark references.

This keeps selection concerns out of the generic backup JSON model. A global Riverpod selection state is not used because the choice is transient and must not leak between exports or interact with ZIP generation.

### Filter before generic encoding

The bookmark source will load bookmarks and memberships, resolve the selected scope, and construct a filtered `BookmarkBackupData`. The existing JSON converter then encodes that value without format changes.

For a selected scope, bookmark IDs are deduplicated by the bookmark's local ID. Group entries are created only for selected real groups, and their bookmark ID lists are restricted to the exported bookmark set. No group is represented as a serialized group entry.

### Keep selection at the direct-export boundary

The backup tile will invoke an optional bookmark-specific export-scope preparation hook for the two export actions. The hook will return the selected scope or cancellation, after which the existing file-picker and clipboard flows use the scoped bookmark data. Import actions remain unchanged, and ZIP export continues to request the default all-data scope without a UI context.

The hook is preferred over adding a destination flag, a clipboard boolean, or a global temporary provider. Other backup sources continue using the existing export path.

### Use one dialog for file and clipboard exports

Both direct export actions will use the same dialog and default to All bookmarks. The file picker is opened only after the user confirms a scope. Clipboard size checks therefore operate on the final filtered payload rather than the full bookmark collection.

## Risks / Trade-offs

- [Risk] A selected bookmark can belong to groups that are not selected. → Include the bookmark once but serialize only selected memberships, making the scope explicit and preventing unrequested group data from leaking into the export.
- [Risk] A large selected scope can still exceed Android clipboard limits. → Reuse the existing preflight size check and direct the user to file export when the final payload is too large.
- [Risk] Adding a direct-export hook can complicate the generic backup tile. → Keep the hook optional and source-specific; existing sources retain their current callbacks and behavior.
- [Risk] Group membership changes while the dialog is open could make the scope stale. → Resolve bookmarks and memberships after scope confirmation, immediately before encoding.

## Migration Plan

No data migration is required. Existing bookmark exports and imports remain valid. The feature can be rolled back by removing the direct-export selector and scope filtering; the JSON format does not require a version change.

## Open Questions

None.
