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

Bookmark backup version 1 keeps bookmark objects in the top-level `data` array
and group objects in the top-level `groups` array. Group `bookmarkIds` are
file-local references into `data`; they must be resolved through
`Bookmark.uniqueId` and must never be treated as keys in the receiving Hive box.

Legacy group objects have `name` and `bookmarkIds` but no `id`. Every legacy
group receives a fresh GUID on every import, even when its name matches a local
group. New exports additionally include `id`.

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
caption occupies up to two lines beneath its icon; its 112-pixel text area can
extend beyond the adaptive row's narrower button slot. This keeps caption
length from changing the bookmark icon's alignment with neighboring controls.
Other adaptive rows retain their default center alignment.
