# Keep bookmark search visible with compact source and sort controls

Priority: Normal
Affected feature: Bookmark post lists

## Problem

The bookmark post list places its tag-search field, horizontal source-URL chips,
and sort controls on three separate rows above the grid. The source and sort
rows use more vertical space than their choices require.

## Expected behavior

Keep the existing text search directly visible above the grid. Show the
selected source and sort mode together on one compact row beneath it. The
source choice remains visible, and Random exposes a separate action to
reshuffle the current results.

## Acceptance criteria

- [ ] Keep the current text field visible in the list header on All,
  Ungrouped, and named-group bookmark views. It continues to search bookmark
  tags and offer its existing suggestions; it is not moved into a menu.
- [ ] Replace the horizontal source chips and separate sort row with one row:
  a source selector showing `Source: All` or the selected source URL, a sort
  selector showing Newest, Oldest, or Random, and a reshuffle button only while
  Random is selected. Source opens a searchable choice surface containing the
  existing source URL options and All.
- [ ] Selecting Random shuffles once. The reshuffle button produces a new
  random order without changing the selected source, group, or tag query.
  Switching to Newest or Oldest removes the reshuffle button and preserves
  the current sorting behavior.
- [ ] Filtering to zero posts does not hide the text field or selected source
  and sort controls. Clearing a tag or source filter restores the expected
  posts without changing bookmark or group data.
- [ ] Long source URLs truncate in the compact row while their full value is
  available in the choice surface and accessibility label. At narrow widths
  and enlarged text, the controls remain operable without overflow; wrapping
  into another line is acceptable when necessary.
- [ ] All new visible labels and accessibility text are localized. Focused
  widget tests cover source and sort choices, Random reshuffle, the visible
  search field, zero-result recovery, and narrow/enlarged layouts. Validate
  the resulting layout on Android with Maestro.

## Context and dependencies

The current source filter uses bookmark source URLs, not profile IDs. Preserve
that selection meaning and the existing tag-search semantics. Bookmark groups
are currently flat; adding nested groups or group-name search inside a bookmark
post list is outside this ticket.

- [Bookmark group behavior](../../bookmark_groups.md)
- [Bookmark post list](../../../lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart)
- [Source selector](../../../lib/core/bookmarks/src/widgets/bookmark_booru_type_selector.dart)
- [Sort and reshuffle](../../../lib/core/bookmarks/src/widgets/bookmark_sort_button.dart)

Dependencies: None.
