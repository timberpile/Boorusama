# Bookmark Groups Design

## Goal

Reintroduce the complete local bookmark-group experience from commit
`ad130bc1` on the current `develop` architecture, while improving state
consistency, persistence boundaries, error handling, and cross-device sharing.
Bookmark backup files produced by the old implementation must import without
conversion.

GitHub issue: `#13`

## Scope

The feature includes:

- a full-screen bookmark-group browser with `All`, `No Group`, and named
  group preview cards;
- create, duplicate, rename, and delete actions for named groups;
- a persisted active bookmark target;
- group-aware bookmark controls on post detail toolbars and thumbnail context
  menus;
- group-aware bulk add, removal, and complete deletion;
- selected-group bookmark exports;
- bookmark and group counts in direct backup feedback;
- legacy-compatible bookmark-group import;
- GUID-based merge and replace behavior for shared groups.

The feature does not migrate the private Hive boxes used by the old development
branch. Compatibility is provided through its exported JSON format.

## User Experience

Opening the Bookmarks route shows a group browser before the existing bookmark
grid. It contains square cards for `All`, `No Group`, and each named group. Each
card uses the first four bookmarks in the current bookmark sort order as a 2x2
preview. Missing preview cells remain transparent. Opening a card navigates to
the existing bookmark content view filtered to that target.

Named groups can be created, duplicated, renamed, and deleted. Deleting an empty
group is immediate. Deleting a non-empty group requires confirmation and
reports its bookmark count. Bookmarks that belong only to a deleted group are
deleted; bookmarks with another named membership remain.

`No Group` and a named group can be active bookmark targets. `All` is only a
browsing view. Opening `No Group` activates it, opening a named group activates
that group, and opening `All` leaves the active target unchanged. Creating a
group while assigning posts activates it, while creating an empty group from
the browser leaves the target unchanged. A missing persisted group falls back
to `No Group`.

A normal bookmark-button tap toggles the current post in the active target. A
long press opens the anchored group picker. The button shows membership in the
active target, the active target label where space permits, and the count of
named groups containing the post. The thumbnail context menu replaces the
single-purpose bookmark action with an in-place group picker. Both surfaces can
create a group while assigning the post.

For a single post, removing its final named membership deletes the bookmark.
For bulk removal, removing the final named membership preserves the bookmark in
`No Group`. Complete deletion remains a separate confirmed bulk action and also
removes cached images. Bulk add and removal keep selection mode active for
items still visible.

## Domain Model

`BookmarkGroup` is an immutable Equatable value containing:

- `String id`: a lowercase canonical UUID string;
- `String name`: a trimmed, non-empty display label;
- `Set<int> bookmarkIds`: local Hive bookmark keys.

Group identity is exclusively GUID-based. Duplicate display names are valid.
Renaming never changes identity.

`BookmarkTarget` is a typed value with `ungrouped` and `group(groupId)` variants.
The `All` view is represented separately as a bookmark view filter, preventing
it from accidentally becoming an add target. The persisted setting stores a
nullable group GUID, where `null` means `No Group`.

`BookmarkLibraryState` is the single in-memory snapshot consumed by bookmark
features. It contains the loaded bookmarks, groups, membership indexes by local
bookmark key and bookmark identity, and the effective active target. Pure
selectors derive filtered bookmark lists, four-item previews, button state,
and aggregate bulk counts.

## Persistence

The existing `favorites` Hive box and `BookmarkHiveRepository` remain the
source of bookmark records. A new `bookmark_groups` Hive box stores one
`BookmarkGroupHiveObject` per group. The object contains its GUID, name, and a
deduplicated list of bookmark keys.

Storing memberships within each group avoids the old implementation's separate
membership box, duplicate membership rows, and full membership-table scans for
simple group operations. Repository reads normalize duplicate bookmark keys.
Consistency repair removes references to bookmark keys that no longer exist;
it never deletes bookmarks merely because they are ungrouped.

Hive does not support transactions spanning the bookmark and group boxes.
Compound mutation services therefore snapshot affected records, apply writes
in a failure-safe order, and attempt rollback after an exception. They reload
and repair storage before exposing state after any failure. Replacing a group's
membership set is a single group-record write.

## State Management and Business Logic

Providers are declared manually. `BookmarkLibraryNotifier` is an
`AsyncNotifier<BookmarkLibraryState>` and is the only provider that publishes
bookmark/group membership state. It loads a consistent repository snapshot and
serializes mutations so simultaneous button actions cannot overwrite each
other.

The notifier delegates business rules to focused services:

- `BookmarkLibraryService` coordinates bookmark creation, membership changes,
  group management, deletion, cache cleanup, rollback, and repair;
- `BookmarkBackupCodec` parses and encodes the bookmark backup payload;
- `BookmarkImportPlanner` validates imports, maps exported bookmark keys to
  bookmark identities, identifies conflicts, and creates an immutable plan;
- `BookmarkImportService` applies a fully resolved plan;
- pure selector functions implement filtering, previews, button state, and
  bulk membership summaries.

UI widgets request operations and display localized results. They do not read
Hive repositories or contain membership rules. Successful mutations publish
one refreshed snapshot. Failures retain or recover a consistent snapshot and
return typed failures suitable for localized messages.

## Backup Format

The existing bookmark envelope remains version `1`. Bookmark objects remain
unchanged in the top-level `data` array. The optional top-level `groups` array
retains the old `name` and `bookmarkIds` fields and adds an optional `id`:

```json
{
  "version": 1,
  "data": [],
  "groups": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Favorites",
      "bookmarkIds": [12, 18]
    }
  ]
}
```

`bookmarkIds` are file-local references to bookmark objects in `data`. During
import they are resolved through `Bookmark.uniqueId`, never assumed to be valid
local Hive keys. References absent from `data` are ignored. Duplicate references
are deduplicated.

Legacy group entries without `id` always create new groups with freshly
generated GUIDs, including when their names match existing groups. Group names
are not used for identity. A malformed GUID or the same GUID appearing more
than once in a single import makes the file invalid before any writes occur.

Direct export offers `All bookmarks`, each named group, and `No Group`. Selected
groups export the union of their bookmarks once and include membership entries
only for selected real groups. Empty selected groups remain in the output. ZIP
backup always exports the complete library without prompting.

## Shared-Group Conflicts

An imported group conflicts only when its GUID already exists locally. Each
conflict is presented individually with:

- `Merge`: update the local display name to the imported name, preserve existing
  memberships, and add imported memberships;
- `Replace`: update the display name and replace the complete membership set
  with the imported set;
- `Cancel import`: abandon the import before any changes are applied;
- an `Apply to all remaining conflicts` checkbox for Merge or Replace.

Conflict collection completes before mutation. This ensures cancelling any
dialog leaves storage unchanged. Replace never deletes bookmark records;
bookmarks removed from the replaced group remain in other groups or appear in
`No Group`.

## Validation and Error Handling

External JSON is treated as nullable and untrusted. The codec validates the
envelope, every bookmark object, group field types, UUID syntax, and duplicate
group IDs. Invalid content produces a localized invalid-format result without
partial import. A malformed group object is not silently reinterpreted as a
legacy group.

Typed operation results carry affected bookmark counts, already-existing
counts, and the number moved to `No Group`. User-facing messages are defined in
the i18n resources and accessed through `context.t`. Debug logging may include
field paths and parser details, but release UI does not expose raw exceptions.

## Testing

Implementation follows red-green-refactor. Tests focus on observable behavior:

- Hive repository tests cover GUID identity, duplicate names, membership
  deduplication, group duplication, rename, deletion previews, and stale-key
  repair;
- state and selector tests cover `All`, `No Group`, named filters, sorting,
  previews, badges, active-target fallback, and mixed bulk selections;
- service tests cover single-post versus bulk final-membership behavior,
  rollback, cache cleanup, and serialized mutation outcomes;
- golden codec tests load representative JSON produced by the old branch and
  prove it imports without conversion;
- import-planning tests cover legacy GUID generation, invalid UUIDs, repeated
  IDs, ignored missing bookmark references, Merge, Replace, apply-to-remaining,
  cancellation before writes, and idempotent re-import;
- widget tests cover the group browser, group picker, conflict dialogs, scoped
  export dialog, and preservation of multi-selection;
- integration verification runs generation, formatting, static analysis,
  focused tests, and the complete `fvm flutter test` suite.

## Delivery

Development occurs on `feature/13-bookmark-groups`. The pull request targets
`develop`, is titled exactly `Merge branch 'feature/13-bookmark-groups'`, and
includes `Closes #13` in its body. It will not be merged without explicit user
approval.
