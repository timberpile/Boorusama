# Shared pinned-search folders

## Intent and scope

The Pinned Searches page is one collection. Profiles still own queries,
authentication, refresh state, and post navigation, but they no longer divide
the page into sections. Named folders can contain independent pins from
different profiles. A pin outside a named folder is in one shared `[Home]`
destination. Folders stay single-level. Hidden following-feed sources are
excluded from this organization.

This design replaces the profile grouping from PS-011 and profile-owned folder
behavior from PS-006. The Info dialog change in PS-017 is separate.

## Page and interactions

The root page shows named folders in manual order, then Home's search cards. It
shows neither profile group headers nor a Home heading. If there are no named
folders, it simply shows cards; if Home is empty, it shows only folders. Each
card, including inside folders, has a small profile footnote. It shows the
profile name, falls back to the site URL when unnamed, and includes the URL if
names alone are ambiguous. Opening a pin activates its owning profile and runs
its stored query through that profile.

The current Add Folder app-bar action becomes **Manage folders**. Its page
provides create, rename, manual reorder, and delete actions for shared named
folders. Home cannot be renamed or deleted. The old per-profile management
shortcut goes away. Tapping a named folder opens its member page, which keeps
the folder's NEW and refresh actions.

The pin dialog and **Move to folder** dialog list all named folders and
`[Home]`. Move to folder also offers **Create folder**. Creating one there
moves the selected pin into it after creation succeeds; cancel or failure
leaves the pin where it was. Move up/down changes the visible order within
Home or the current folder, including between pins from different profiles.

Deleting a named folder requires confirmation that names it, counts its pins,
and warns that they will be unpinned. Confirming removes the folder and every
member pin, across profiles. Cancel changes nothing. Empty folders also
require confirmation. This does not delete posts or profiles.

## Organization model

One shared organization record stores the ordered folder list, each folder's
ordered pin IDs, and Home's ordered pin IDs. Folder IDs are stable and names
are unique case-insensitively across the collection. Each independent pin has
one destination. New pins append to their selected destination; moves remove
the old membership and append to the new destination. Deleting a pin removes
its ID from the record. This record is the source of truth for display order
across profiles; per-profile pin positions cannot order a mixed-profile list.

`SearchSubscription` retains each pin's profile ID, query, name, previews,
NEW state, and refresh checkpoints. Folder membership does not change its
owner. The repository rejects missing IDs and feed-owned source IDs as folder
members. Mutations are serialized; an ordinary failed write reports an error
and restores a consistent folder and pin state.

Folders have not shipped, so the profile-folder format needs no migration.
Independent pins with no shared organization entry appear in Home in a
deterministic order. Experimental profile-folder rows may be discarded. No
nested folders or cross-site combined post feed is added.

## Refresh and profile lifecycle

A folder shows NEW when any member pin has NEW. Opening a member clears only
that pin's read state, then the folder badge recomputes. Refresh Folder visits
members in existing refresh-priority order, resolves each pin's own profile
and query adapter, and uses the shared request gate. It does not switch the
active profile merely to refresh. Root Refresh All continues to cover
supported profiles. Unsupported pins remain identifiable in the combined
list and retain their existing unsupported or error state.

Removing a profile deletes its pins and their Home or folder memberships,
leaving folders and other profiles' pins intact. Empty folders remain until
deleted. Opening a pin from Home or a mixed folder uses existing owner-aware
navigation.

## Backup and restore

Backups save shared folder definitions, folder order, member order, and Home
order alongside independent pins with profile references. Restore maps each
pin to its profile, then reconstructs shared membership using the resolved
pin IDs. Pins whose profiles cannot be matched are skipped; remaining members
and empty folders are retained. Newly imported pins from pin-only backups
append to Home; existing pins keep their current destinations.
Old experimental profile-folder backups need no folder migration.

## Verification

- Repository tests cover cross-profile membership and ordering, unique names,
  feed-source exclusion, move/create failure, folder deletion, and profile
  removal without disturbing other members.
- Backup tests cover mixed-profile folders, order, empty folders, missing
  profiles, and pin-only restore.
- Widget tests cover the ungrouped root, profile footnotes, `[Home]` pickers,
  Create folder from Move to folder, and destructive confirmation and cancel.
- Android Maestro checks unfiled-only, folders-only, mixed-profile folder,
  move/create, and folder-deletion flows. Automated and emulator checks are
  recorded separately.
