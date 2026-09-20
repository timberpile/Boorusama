# Make pinned-search folders shared across profiles

Priority: Normal
Affected feature: Pinned-search organization and navigation

## Problem and reproduction

The all-profile page groups pins by profile and shows a folder-open shortcut
above unfiled searches. The shortcut opens a second page with the same pins,
suggesting an unnamed folder. Folders themselves are profile-owned, so a user
cannot organize related searches from different profiles together.

## Expected behavior

Show one pinned-search collection with named folders above Home's search cards.
Home is the no-folder destination and has no heading on the root page. Each
search card identifies its owning profile. Named folders can contain pins from
multiple profiles while each pin still opens and refreshes through its owner.

## Acceptance criteria

- [ ] Remove profile group headers and the duplicate per-profile management
  shortcut. Show named folders first and Home cards without an Unfiled heading.
- [ ] Give every pin card a small owning-profile footnote, including on folder
  pages; opening a pin preserves owner-aware navigation.
- [ ] Replace the top Add Folder action with Manage folders, where users can
  create, rename, manually reorder, and delete shared named folders.
- [ ] Offer `[Home]` and all named folders in pin and Move to folder dialogs.
  Create folder is available from Move to folder and moves the pin into the new
  folder on success.
- [ ] Folder deletion warns and asks for confirmation, then removes the folder
  and all contained pinned searches. Cancel leaves both intact.
- [ ] Preserve manual pin ordering within Home and each folder across profiles.
  Folder NEW and Refresh Folder aggregate member pins while resolving each
  refresh through its owning profile.
- [ ] Profile removal clears only its own pins from shared organization;
  feed-owned sources never enter folders or Home. Backup/restore preserves
  shared membership and ordering.
- [ ] Add focused persistence and widget coverage, and validate the key
  navigation and deletion flows on Android with Maestro.

## Design and dependencies

Follow the proposed [shared-folder design](../../superpowers/specs/2026-09-19-shared-pinned-search-folders-design.md).
Folders have not shipped, so the current profile-folder data does not require
migration. This supersedes the folder ownership and grouping assumptions in
[PS-006](../done/PS-006-search-folders.md) and
[PS-011](../done/PS-011-all-profile-pinned-search-list-design.md).

Follow the [development workflow](../../development_workflow.md) when
implementing. This ticket records the redesign; no UI or storage change has
been applied.
