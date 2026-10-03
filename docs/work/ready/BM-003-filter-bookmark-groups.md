# Filter the bookmark-group overview by name

Priority: Normal
Affected feature: Bookmark-group overview

## Problem

The bookmark-group overview has no text filter, so finding a named group in a
large collection requires scanning or scrolling through every card.

## Expected behavior

A visible text field narrows the group cards by name. Inside a group, the
existing bookmark-tag search remains the text search for its posts.

## Acceptance criteria

- [ ] Filter the overview's group cards by a trimmed, case-insensitive
  substring of each group name. The built-in All and Ungrouped cards match
  their localized visible labels. An empty query shows every card in the
  existing order.
- [ ] Filtering does not search bookmark tags or contents, change group
  membership, change previews, or fetch posts. Opening a matching group shows
  its normal bookmark list with the existing visible tag-search field.
- [ ] Keep group creation available while filtering. Rename, duplicate, and
  delete act on the selected group's stable ID, including when distinct groups
  have the same name. The visible list updates after those actions.
- [ ] Show a localized no-match state with an easy way to clear the filter.
  With no user-created groups and an empty filter, the built-in All and
  Ungrouped cards remain visible. The field remains available when no cards
  match and works at narrow widths and enlarged text.
- [ ] Focused widget tests cover named and built-in cards, duplicate names,
  no-match recovery, and opening a group with its tag search intact. Validate
  the overview on Android with Maestro.

## Context and dependencies

Bookmark groups currently contain bookmarks and are not nested. Nested groups
are a separate future topic; this ticket does not introduce a second search
mode within a bookmark post list.

- [Bookmark groups](../../bookmark_groups.md)
- [Group overview](../../../lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart)
- [Compact controls inside groups](BM-002-compact-bookmark-controls.md)

Dependencies: None.
