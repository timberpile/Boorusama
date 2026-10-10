# Bookmark groups

Bookmark records remain in the `favorites` Hive box. Named groups are stored in
the `bookmark_groups` box and contain a GUID, a display name, and a set of local
bookmark keys. Display names are not identities and do not have to be unique.
Ordinary bookmark UI shows display names only; GUIDs are reserved for import
conflict identification and persistence.

`BookmarkLibraryState` is the shared snapshot for bookmark UI. It builds the
membership indexes used by the group browser, filtered grids, post actions, and
bulk actions. A nullable `activeBookmarkGroupId` setting stores the add/remove
target. Missing, invalid, or legacy null targets resolve to the permanent Default
group. `All` is a view and is never an assignment target.

## Default and membership removal

Default is a real, root-level group with reserved UUID
`00000000-0000-0000-0000-000000000000` (the nil UUID). Its system role is derived from that
identity, never its name. Repository APIs reject rename, deletion, and folder
placement. At Home, All and Default appear side by side above a horizontal
divider; user-created folders and groups appear below it. Ordinary groups may
also be named Default. Loading repairs stale
membership references, creates the system group, and assigns only bookmarks
with no memberships to Default. This migration is idempotent and preserves
snapshots and timestamps. Adding explicitly to another group never removes or
adds a Default membership.

Every bookmark belongs to at least one group. Add preserves other memberships;
Remove targets exactly one group and deletes bookmarks losing their final
membership. The All view requires source-group selection. Global deletion APIs
remain internal to maintenance and replacement operations.

## Viewer removal feedback

Viewer toolbar removals persist immediately. The viewer keeps its post-list
snapshot while the underlying grid refreshes after closing. Removal shows one
localized Undo Snackbar for the successful operation, with removed and deleted
counts. Undo runs through the shared serialized mutation queue, restores only
the removed membership, and restores deleted snapshots using current local IDs.
It preserves a newer snapshot or other memberships if the bookmark was added
again. Missing source groups, a superseding removal, and import/restore
boundaries invalidate Undo with feedback. Expiring feedback or terminating the
app requires no cleanup of persisted orphan records.

## Backup compatibility

Current export and import uses the `.bsexport` container. A Full export marks
the bookmark source as complete and recommends category replacement. A custom
export records whether all groups (including future groups) or exact current
group UUIDs were selected. Per-group Update preserves the exact local name and
UUID while replacing membership and removing newly orphaned bookmarks. Merge and Merge into preserve
the local target name and keep local-only memberships. New groups and copies use
the imported name. Full category Replace restores the imported group
definitions. Import choices are validated before the durable package transaction
starts.

Package imports write bookmark repositories directly, bypassing the bookmark
provider mutation methods. After the durable transaction commits, the import
flow must await a provider reload before showing completion; otherwise the
group browser can keep displaying its stale pre-import snapshot.

Bookmark backup version 5 includes folders, placements, and the Default group's
`systemRole: "default"`. Compatible version-4 exports remain importable; imported
bookmarks without memberships are assigned to Default. Full Replace restores one
Default group. Custom import always merges incoming Default members, and never
copies the system group into an import wrapper. Ordinary group import modes
retain their existing semantics.

Bookmark backup version 4 stores bookmarks in the top-level `data` array and
groups in the top-level `groups` array. Each bookmark carries its full post
snapshot and canonical `(site namespace, upstream post key)` identity. The site
namespace is the lowercase host plus non-default port and installation path;
scheme, credentials, query, fragment, and trailing slash do not affect it.
Full URLs discard only the port default for their own scheme. Stored, scheme-less
namespaces retain an explicit port, including `:80` or `:443`, so reloading
cannot merge an HTTP `:443` installation with the HTTPS default. Changing an
unusual installation between those two forms changes its namespace.
The post key is a stable upstream ID, or a work/page key for Pixiv. Engine and
profile metadata, media URLs, and local Hive keys are not identity components.
The importer verifies each serialized identity against its decoded snapshot
before any repository mutation. Group `bookmarkIds` refer to file-local bookmark
IDs in `data`; references absent from `data` are rejected before import
planning. Valid references are resolved to local keys during import.

Versions 1 through 3 are unsupported after this breaking schema change. Old
local bookmark rows are ignored on ordinary loading, with no URL fallback.
Posts without a stable upstream ID cannot be bookmarked; bookmark actions show
an explanatory error instead. Native Sankaku string IDs are preserved in
post snapshots and decoded from Hive's untyped nested map values on reload.

Group objects carry a UUID `id`, name, and `bookmarkIds`. The UUID identifies a
group for import conflicts; the name remains a display label.

Only matching GUIDs conflict; equal names or displayed paths do not match
groups. The legacy per-group Replace conflict choice resolves to Update and
therefore preserves the local name while replacing membership and removing
newly orphaned bookmarks. All conflict choices are collected before storage is
changed, so cancelling a conflict dialog cancels the whole import.

## Name dialog lifecycle

Create, rename, duplicate, and create-and-add share the name dialog. Its widget
state owns the text controller and disposes it when the widget unmounts.
`showDialog` completes when the route is popped, before the closing animation
unmounts the text field. Disposing the controller immediately after awaiting
`showDialog` can therefore cause a used-after-disposal error, followed by a
misleading `_dependents.isEmpty` framework assertion.

## Post viewer toolbar layout

Post viewer action rows align controls at the top, with a minimum 48-pixel
control height that also centers the compact overflow button. The bookmark
caption starts two pixels below the visible glyph and keeps two pixels below
the text, using the lower part of the 48-pixel tap target with a compact line
height. A wrapped caption grows the control only by the second line. Its
112-pixel text area can extend beyond the adaptive row's narrower button slot.
This keeps caption length from changing the bookmark icon's alignment with
neighboring controls. Other adaptive rows retain their default center
alignment.
