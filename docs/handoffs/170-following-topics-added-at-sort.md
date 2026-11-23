# Sort Following Topics by Added Date — Technical Handoff

Issue: [#170](https://github.com/timberpile/Boorusama/issues/170).
Branch: `feature/170-following-topics-added-sort`.

## Accepted behavior

The Following Topics list has four sort choices, in this order:

- **Manual** (`manual`): persisted organization order.
- **Name** (`nameAsc`): alphabetical display names, with query fallback.
- **Unread First** (`updatesFirst`): unseen Topics first, then latest cached post
  within the unseen/read groups.
- **Recently Added** (`addedNewest`): persisted `FollowingTopic.createdAt`, newest
  first, with position and stable ID breaking equal-date ties.

The owner removed the original oldest-first added-date proposal and the existing
Oldest Post First option. Both obsolete stored values (`addedOldest` and
`lastPostOldest`) now resolve to Manual through the existing settings fallback.
The retained identifiers are unchanged; no timestamp migration is needed.

Sorting changes only a display copy. Preserve organization positions, folder
membership, creation timestamps, and read-only received-folder controls. Apply
Recently Added to the final filtered/descendant Topic projection and within each
direct received publisher section. Keep its folder rows in manual order.
Separate feed-member and feed-post ordering are outside this change.

## Verification

- Check newest-first creation dates, deterministic ties, and unchanged manual inputs.
- Check settings serialization, provider recreation, and removed-value fallbacks.
- Check Home, named/nested folders, filtered lists, and direct received sections.
- Check the four localized menu choices at 320px and 200% text, including an open keyboard.

See [verification and remaining acceptance](170-added-sort-verification.md) for
executed checks and device/integration limits.
