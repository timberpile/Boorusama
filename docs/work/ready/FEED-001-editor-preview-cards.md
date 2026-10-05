# Show representative cached thumbnails in feed-editor rows

Priority: Normal
Affected feature: Following Feed editor

## Problem

Feed members appear as plain rows, making artists and searches harder to
recognize than the cards in the overview.

## Expected behavior and acceptance criteria

- Use card rows with the existing member title/query, state, and actions.
- Show representative cached thumbnails using the existing image-quality
  resolver and owning profile authentication; omit previews when no cache exists.
- Keep edit/remove/navigation behavior and accessibility usable at narrow widths
  and enlarged text.
- Opening or rebuilding the editor adds no thumbnail or post-fetch requests.

## Context and dependencies

Reuse the pinned-search/following-feed card visual structure and existing cached
member data. This is presentation-only work, separate from overview first-time
initialization. No storage schema change or new fetch path is required.

- [Following Feed architecture](../../pinned_searches.md)
- [Overview cards](../in-progress/IDEA-027-following-feed-cards.md)
- [Feed thumbnail quality](../done/PS-029-respect-feed-thumbnail-image-quality.md)
