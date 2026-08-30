## Context

Boorusama already serializes bookmarks as a top-level `data` array and imports them additively using `Bookmark.uniqueId`. Local bookmark groups are stored separately in the bookmark-group repository and use device-local numeric IDs. The backup needs to preserve memberships without exposing those IDs as cross-device identity, while older bookmark-only files must continue to work.

## Goals / Non-Goals

### Goals

- Preserve the current bookmark JSON objects and `data` array.
- Add optional group metadata using group names and file-local bookmark references.
- Restore groups and memberships across devices with different local IDs.
- Keep imports additive, non-destructive, and safe to repeat.
- Continue importing existing bookmark-only backups.

### Non-Goals

- Synchronizing or merging changed bookmark metadata.
- Exporting or importing device-local group IDs.
- Deleting groups or memberships that are absent from an imported file.
- Changing the Anime Boxes conversion script in this change.

## Decisions

### Keep bookmark data stable and add optional top-level metadata

The existing bookmark list remains in `data` with the current `Bookmark.toJson()` shape. Groups are represented by an optional top-level field:

```json
{
  "data": [{ "id": 12, "booruId": "...", "originalUrl": "..." }],
  "groups": [{ "name": "Favorites", "bookmarkIds": [12] }]
}
```

The numeric bookmark IDs in `groups` are only references within this file. They are resolved through the corresponding bookmark's `uniqueId` during import. Group IDs are not exported.

### Extend the generic payload without coupling it to bookmarks

The generic backup payload and converter will preserve optional unknown top-level fields. The bookmark source will provide its `groups` field through a source-specific payload extension, while other backup sources continue using their current behavior.

### Use a bookmark-specific parsed value

The bookmark source will parse both the bookmark list and optional group entries into a small backup value object. Export still writes the list through the existing `data` path and writes group metadata separately. Import can therefore resolve references before writing memberships without changing the generic list handler contract.

### Import in two phases

The executor first adds only bookmarks whose `uniqueId` is not already present. It then reloads bookmarks, maps exported bookmark IDs to local bookmark records by `uniqueId`, and restores each group membership. This handles both newly created and pre-existing bookmarks.

### Match groups by normalized name

Group names are matched case-insensitively and existing groups are reused. Membership writes use the repository's idempotent add operation. This avoids duplicate groups and makes repeated imports safe.

## Risks / Trade-offs

- A group entry that references a bookmark omitted from `data` cannot be restored; the importer will skip it safely.
- Existing bookmarks with the same `uniqueId` keep their current metadata, matching the existing non-destructive import behavior.
- Preserving arbitrary top-level fields in the generic payload slightly broadens its model, but prevents source-specific metadata from being discarded during decode.

## Migration Plan

No data migration is required. Existing exports remain valid because `groups` is optional. New exports include groups when available. The implementation should retain the current bookmark backup version because the existing `data` format is unchanged and the new field is optional.

## Open Questions

None for this change.
