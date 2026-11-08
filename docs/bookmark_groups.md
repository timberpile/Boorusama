# Bookmark groups

## Saved records and local organization

A Bookmark has a canonical local integer ID. Posts, native Content Groups,
Related families, and retained legacy Collections share the durable allocator,
record index, and mutation journal. Post payloads remain in `favorites`; other
record payloads and their headers live in the corresponding content boxes.
A saved remote Pool, Work, Gallery, or Related family is one Bookmark, distinct
from a local Bookmark Group and from a separately saved member Post.

Local groups have a stable UUID, display name, nullable `parentGroupId`, sibling
`position`, direct `bookmarkIds`, and exact UTC direct-membership dates.
Names may repeat. Parent pointers are authoritative: there is no persisted
folder flag, child list, or descendant-membership list. `BookmarkGroupTree`
provides immutable ordered adjacency, iterative traversal, and graph validation.
Following Topics retain their independent folder model.
Legacy folder aliases apply only to explicitly tagged folder references and
old folder routes. Canonical Group UUIDs, including Default, are never remapped
through that compatibility table.

`BookmarkLibraryState` publishes the canonical records and direct membership
indexes. `.group(id)` is a direct read scope, `.subtree(id)` is a local union,
and `.all()` is library-wide. Subtree deduplication uses local integer IDs;
it never reconstructs an identity from a retained Post snapshot. Newest/oldest
membership sorting considers only dates within the selected scope. A bounded
snapshot cache retains recently used subtree projections rather than computing
all descendant unions.

## Default and direct mutations

Default is the protected root group with nil UUID
`00000000-0000-0000-0000-000000000000`. Its role comes from its identity,
not its name. It cannot be renamed, moved, or deleted. An ordinary group may
also be named Default. Home and All are navigation/read views, never writable
parents or implicit assignment targets.

Each Bookmark belongs to at least one group. Adding to a group preserves other
memberships. Removing targets an explicit direct membership and deletes a
record only when it loses its final membership. An aggregate view asks for an
actual source group; subtree removal choices are restricted to that subtree.
The absence of a direct membership in its parent never authorizes global deletion.
Favorites Sync remains additive and targets one group's direct memberships.

Moving a group changes only its parent/order. Duplicating copies only its direct
memberships into a sibling group. Deleting a group preserves its surviving
children by promoting them to the nearest surviving parent, while applying the
existing orphan policy to the deleted group's own memberships. Bulk selections
are validated together; ancestor/descendant moves do not repeat the subtree.
The shared journal commits the complete organization change.

Hierarchy Undo retains only affected groups and records. It restores UUIDs,
parent/order and exact membership dates, and reserves new monotonic IDs for
orphan payloads that were deleted. It preserves newer child names, memberships
and payload observations. Recreated group identities, newer child moves, or a
later global deletion of an originally shared record reject Undo before writing.
An explicitly deleted surviving child is not resurrected.

## Group screen and picker

Home and ordinary groups share one screen. Structure shows immediate child cards
above the direct Bookmark timeline on one lazy vertical scroll surface.
Content queries, sorting and source filters do not filter or reorder child cards.
All Bookmarks hides the cards and shows the deduplicated subtree timeline.
A truly empty direct section has a compact empty state; filtered-empty content
retains its controls. The production measured floating timeline header returns
to its natural position below the cards when scrolling upward through the boundary.
Pinned controls retain their visibility setting when the measured header fits.
If enlarged text, wrapped chips or a reduced viewport make the header taller
than the usable viewport, it scrolls naturally so every control remains reachable.
Pinning resumes as soon as the header fits again.
Group search suggestions stay between the navigation Header and the keyboard.
When that area cannot fit an interactive row, suggestions remain hidden until
space is available; they never cover the mode or ancestor controls.

Local child cards and saved records use separate typed selection controllers.
The card section binds its Group controller explicitly inside the shared
timeline viewport. Entering either selection scope clears the other; hidden
child cards in All Bookmarks are not keyboard-selection targets.

The Header title opens a Kurumi ancestor menu; Back moves up one group level.
The Header mode control preserves the committed query while changing scope,
and selection/scroll state is scoped by group UUID and mode. Groups without
children hide the mode control without discarding their stored choice.
`bookmarkGroupViewModes` uses local misc-data storage and is excluded from
Bookmark transfer and settings backups. Confirmed deletion prunes its UUID;
Undo may restore a missing preference. Cache-write failure does not report a
confirmed domain mutation as failed, and subsequent loading retries cleanup.

All picker presenters share hierarchy navigation and frozen action requests.
A row's body performs its direct membership or target-selection action; its
separate full-height 80-pixel trailing target opens that group, including leaves.
A current-group row remains selectable. Recent rows use the same split actions.
The top row keeps Back/path left and Add Group right. System Back and Escape
move up one level, dismissing only at Home; anchored overlays delegate Back
through their actual presenter. Child routes and their text input retain their
normal ownership. Navigation performs no remote metadata/member requests and
does not mutate membership or Recent ordering.

## Storage upgrade and recovery

`BookmarkStorageMigration` resolves pending unified journals before conversion.
It supports legacy storage and an already active #155 unified-v2 generation,
including subsequent writes and allocator reservations. The hierarchy is staged
as an explicit organization-v3 generation and activated at one durable marker.
A partially staged generation cannot become an ordinary writable facade.

Former folders become ordinary initially empty groups. Existing group UUIDs,
record IDs, memberships, dates, loaded details, Related ordering, tombstones and
allocator continuity are preserved. Cross-namespace UUID collisions use a
persisted deterministic folder-to-group map. Original legacy/v2 files remain
available as recovery evidence. Compatibility aliases support old folder-based
selection/template references without restoring a second canonical folder model.

The Hive Post adapter preserves its type ID and existing field numbers. Optional
fields 17/18 retain exact record timestamp microseconds; rows without those
fields retain their original DateTime fallback and timezone flag. Group parent
storage uses its own added field rather than reusing a legacy folder field.

## Transfer compatibility

The current `.bsexport` Bookmark source is version 10. Its single `data` array
contains typed saved records; groups contain direct file-local member IDs,
`parentGroupId`, position and exact membership dates. The writer marks
`organizationSchema: "nestedGroups"` and emits no canonical `folders` array.
Readers retain versions 4 through 9 and explicitly recognize the transitional
#155-only v10 folder shape. Ambiguous, mixed, unmarked new shapes and invalid
parent graphs are rejected before mutation. Versions 1 through 3 are unsupported.

Transfer integer IDs are file-local references. Applying an import remaps them
through durable local reservations; no imported number selects an existing
payload slot. Proven source identities may deduplicate content, while readable
unaddressable Posts and opaque legacy Collections remain independent records.
Profile hints are not content identity and clearing a hint never infers a source
ID from a retained snapshot. Decoding, importing and re-exporting preserved
snapshots require neither a matching profile nor a successful remote request.
Missing or ambiguous Bookmark profile mappings are optional access hints;
Following Topic execution retains its required account dependencies. Optional
Bookmark hints never choose an account for a required Topic.
Cold Bookmark storage and library initialization finishes before the import
preflight acquires its snapshot lock. Provider initialization runs in its own
zone and may need that same coordinator; awaiting it inside the locked snapshot
section can otherwise block a first import indefinitely.

Ordinary timelines and local group covers require a usable source binding. The
complete saved records and membership counts remain available to storage and
export. Profile changes recompute the local projection without importing again
or rewriting snapshots. Existing account, engine and installation-path isolation
still applies; an unrelated selected profile is never a cover fallback.

Native saved Danbooru Pool/Related and Szurubooru Pool records open through the
registered shared Group source and mixed-viewer entry. `CollectionBookmark`
remains a thin UI/old-wire projection over the canonical saved records, without
another allocator or durable membership store. Unproven legacy installation URLs
are never reconstructed as HTTPS. An approved public installation with a
registered Group reader can open without a saved profile; ambiguous accounts and
unsupported readers remain unavailable through the existing localized indicator.
Local saving reuses the generic Kurumi picker and rechecks the captured access
before and after asynchronous draft creation. It creates no anonymous profile.

Saved Group covers are static URL/variant/geometry descriptors, resolved through
the existing thumbnail resolver and access-scoped media cache. The effective
visibility-policy digest and exact permitted source are checked before media
requests or cached rendering. A rejected descriptor cannot fall back to its raw
URL. Cover descriptors confer no Post identity or media-action capabilities.
Explicit refresh retains local IDs, direct memberships and membership dates,
uses the captured actor, and checks that access again before publishing. Related
order remains the saved local preference rather than refreshed source metadata.

Group conflict identity is its UUID, never its name or displayed path. Update
replaces direct membership while preserving the existing name and placement;
Merge retains local-only memberships. Copies use ordinary local groups and
remap parents consistently. Full category Replace restores validated imported
definitions. Preview and apply share the same normalized hierarchy preparation,
and cancellation/preflight failure performs no partial import. After a durable
import, provider reload completes before the UI reports completion.

Private transaction rollback restores its original local IDs and membership
dates through `restoreLocalSnapshot`, rather than applying file-ID remapping.
Its version-3 mutation journal explicitly identifies restored tombstones and
recovers across each durable boundary. It accepts only previously known local
slots and never lowers the allocator. This restores the same logical pre-import
records; ordinary imports and Undo still cannot recycle a deleted ID. The private
recovery path is never used for external file, clipboard or nearby input.

Scoped subtree export retains separate group definitions and empty structural
ancestors without including unselected ancestor contents. Partial tree selection
can retain a parent's direct records while excluding a child. Default retains
its system role and is never copied into an import wrapper. Compatibility rules
for older formats remain covered by the transfer suites.

## Automatic backup retention

Automatic backup retention is **count-based**, not age-based. The settings UI
supports keeping 2, 3, 4, 5, 7, 14, 30, 60 or 90 backup files. New settings and
records without a saved choice default to **30**; existing explicitly saved
positive limits are preserved. Cleanup occurs after a successful automatic
backup, using the existing retention service. Keeping 30 backups represents
roughly 30 days only if one backup actually succeeds each day, and can increase
local storage usage. This setting does not change `.bsexport` format or group
membership behavior.

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
