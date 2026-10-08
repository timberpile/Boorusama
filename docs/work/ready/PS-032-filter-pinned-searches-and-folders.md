# Filter pinned searches and folders on the current level

Priority: Normal
Affected feature: Pinned Searches overview and folder pages

## Problem

The Pinned Searches overview can contain many Home pins and named folders from
different profiles. It has no way to narrow the visible entries by text or
owning profile. Folder pages likewise show every member pin.

## Expected behavior

Provide a visible text filter and a profile selector on both the overview and
folder pages. Filtering changes only the current list; it never changes stored
memberships, NEW state, ordering, or refresh scope.

## Acceptance criteria

- [ ] On the overview, a trimmed, case-insensitive substring matches folder
  names and Home pins by their custom name or stored query. It does not search
  pins inside folders. On a folder page, the text filter matches only that
  folder's pins by custom name or query. An empty query shows the full level.
- [ ] Offer All profiles and the configured profiles as choices, identifying
  duplicate profile names with their site URL. A chosen profile matches pins by
  owning profile ID. Text and profile conditions combine with AND for pins.
  On the overview, a named folder passes the profile filter when it contains
  at least one pin owned by that profile; its name must also pass the current
  text filter.
- [ ] Opening a visible folder carries the profile choice into its page but
  starts with an empty text filter, since the overview query matched the
  folder's name rather than its contents. Returning preserves the overview's
  filters. A removed selected profile falls back to All profiles.
- [ ] While a profile filter is active, hide folders with no member pins
  owned by that profile. A visible folder card shows the matching count out
  of the total (for example, "3 von 8 Suchen"); its NEW indicator, last-post
  label, and cached previews describe only matching pins. With All profiles
  selected, retain the existing aggregate card presentation.
- [ ] Filters do not change folder actions. Rename and move target the same
  stored folder; Refresh Folder and Delete Folder affect all member pins,
  including hidden ones. Keep the existing confirmation and make the full
  scope of refresh and delete clear in their labels or confirmation.
- [ ] Preserve the existing stored order and the relative order of visible
  pins and folders. When manual sort permits Move up/Move down, keep them
  available under active filters. Each move changes the selected entry's
  position in the complete stored list exactly as it would with no filter.
  The filtered view may show no immediate change when the adjacent entry is
  hidden. Opening, editing, refreshing, and deleting an individual visible
  pin retain their existing behavior.
- [ ] Keep the search and profile controls accessible when a filter finds no
  matches. Distinguish a collection with no saved entries from one with no
  matching entries, and provide a clear-filter action. Typing or changing a
  filter must not fetch posts or mutate persistence. Refresh All and Refresh
  Folder retain their full unfiltered scope.
- [ ] Localize new labels and states. Focused tests cover named and unnamed
  pins, folder-name-only matching, the current-level boundary, mixed-profile
  folders, combined filters, full-folder actions under filters, reordering
  under filters, and no-match recovery.
  Validate the overview and a folder page on Android with Maestro.

## Context and dependencies

Folders are shared across profiles, while each pin belongs to one profile.
This is a presentation filter over existing local state; it does not add a
query search against any booru or change feed-owned sources. The current-level
search boundary is a product decision for this ticket.

- [Pinned-search subsystem](../../pinned_searches.md)
- [Overview and folder page](../../../lib/core/search/subscriptions/src/pages/pinned_searches_page.dart)
- [Shared-folder behavior](../done/PS-018-rework-pinned-search-folder-navigation.md)
- Historical design artifact: `docs/superpowers/mockups/2026-10-03-pinned-search-folder-profile-filter.html`. This file is absent from current local `develop`; recover or recreate it before implementation.

Dependencies: None.


## Deferred from the current program (2026-10-06)

The user requested skipping all unstarted items to finish existing work. The coordinator released the setup-only reservation. No implementer was started, prerequisites were not replayed, and no product code or tests were changed. This ticket is available but outside the current authorized finishing scope. The setup-only reserved branch `feature/ps-032-filter-pinned-searches` and its worktree were subsequently removed during local maintenance. As checked on 2026-10-07, neither remains; there is no active claim.
