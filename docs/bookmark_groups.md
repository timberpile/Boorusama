# Bookmark groups

Bookmark records remain in the `favorites` Hive box. Named groups are stored in
the `bookmark_groups` box and contain a GUID, a display name, and a set of local
bookmark keys. Display names are not identities and do not have to be unique.
Ordinary bookmark UI shows display names only; GUIDs are reserved for import
conflict identification and persistence.

`BookmarkLibraryState` is the shared snapshot for bookmark UI. It builds the
membership indexes used by the group browser, filtered grids, post actions, and
bulk actions. A nullable `activeBookmarkGroupId` setting stores the add/remove
target; null means `No Group`. `All` is a view and is never an assignment target.

## Backup compatibility

Current export and import uses the `.bsexport` container. A Full export marks
the bookmark source as complete and recommends category replacement. A custom
export records whether all groups (including future groups) or exact current
group UUIDs were selected. Per-group Update mirrors the imported name and
membership, removing newly orphaned bookmarks; Merge uses the imported name
and keeps local-only memberships. Import choices are validated before the durable
package transaction starts.

Package imports write bookmark repositories directly, bypassing the bookmark
provider mutation methods. After the durable transaction commits, the import
flow must await a provider reload before showing completion; otherwise the
group browser can keep displaying its stale pre-import snapshot.

Bookmark backup version 4 stores bookmarks in the top-level `data` array and
groups in the top-level `groups` array. Each bookmark carries its full post
snapshot and canonical `(site namespace, upstream post key)` identity. The site
namespace is the lowercase host plus non-default port and installation path;
scheme, credentials, query, fragment, and trailing slash do not affect it.
The post key is a stable upstream ID, or a work/page key for Pixiv. Engine and
profile metadata, media URLs, and local Hive keys are not identity components.
The importer verifies each serialized identity against its decoded snapshot
before any repository mutation. Group `bookmarkIds` refer to file-local bookmark
IDs in `data` and are resolved to local keys during import.

Versions 1 through 3 are unsupported after this breaking schema change. Old
local bookmark rows are ignored on ordinary loading, with no URL fallback.
Posts without a stable upstream ID cannot be bookmarked; bookmark actions show
an explanatory error instead.

Group objects carry a UUID `id`, name, and `bookmarkIds`. The UUID identifies a
group for import conflicts; the name remains a display label.

Only matching GUIDs conflict. Merge and Replace both use the imported display
name. Merge unions memberships, while Replace uses exactly the imported
membership set without deleting bookmark records. All conflict choices are
collected before storage is changed, so cancelling a conflict dialog cancels
the whole import.

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
