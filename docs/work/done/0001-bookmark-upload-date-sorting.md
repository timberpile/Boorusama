# Sort bookmarks by upload date or bookmark date

Priority: Normal
Affected feature: Bookmark post lists (All and groups), group previews
Agent/session: Codex (local implementation, 2026-10-13)
Work branch: `feature/bookmark-upload-date-sort`
Worktree: `.worktrees/bookmark-upload-date-sort`

## Problem

The bookmark sort picker only offers Newest, Oldest and Random, with the
date-based choices referring to when a post was bookmarked. Users cannot sort
by the post's original upload date, especially in groups containing bookmarks
from multiple profiles or sites.

## Expected behavior

Show five compact, unambiguous choices in the existing Kurumi sort picker:

- Upload icon + **Newest** / **Oldest**
- Bookmark icon + **Newest** / **Oldest**
- Shuffle icon + **Random**

The selected control must retain a visible, localized **Sort:** prefix
before the icon and choice (e.g. `Sort: [bookmark icon] Newest`). Keep the
popup choices compact with just icon + Newest/Oldest/Random. Add a subtle
vertical divider between Sort (including the optional reshuffle action) and Source
in the filter bar. Do not add dividers inside either menu.

Use full, localized date-source descriptions for tooltips and accessibility.
Keep **Newest Bookmark** as the default, preserving the existing date behavior.

## Acceptance criteria

- [x] Upload sort uses `bookmark.post.createdAt`; bookmark sort uses
  `bookmark.createdAt`. Both support newest-first and oldest-first.
- [x] Known upload dates are sorted chronologically, with undated posts after
  dated posts in both directions. Within undated posts (and as a tie-breaker
  for equal dates), order by stable normalized site namespace and then numeric
  post ID. Do not treat unrelated sites' post IDs as one global timeline;
  comparison must be transitive and deterministic.
- [x] Apply the new modes consistently to All, bookmark-group lists and
  group previews, preserving tag/source filters.
- [x] Preserve Random's seeded ordering and separate reshuffle action.
- [x] Use the existing Kurumi popup styling, compact icon+text options and
  localized accessible labels, plus a visible `Sort:` prefix on the selected
  control; verify at narrow widths and large text scale.
- [x] Separate Sort and Source in the filter bar with a subtle vertical divider,
  keeping the popup options free of dividers and preserving tap behavior.
- [x] Add focused tests for the two date sources, missing dates across sites,
  equal-date tie-breaking, group/previews, and menu choices.
- [x] Format affected Dart files and run the complete FVM test suites specified
  in AGENTS.md before moving this item to done.

## Context and dependencies

Post upload dates are already stored in bookmark post snapshots. No new
database fields, migration, or network requests are required. Site namespace
is a stable fallback grouping key where profile IDs could change.

- [Bookmark selector](../../../lib/core/bookmarks/src/providers/bookmark_group_selectors.dart)
- [Sort picker](../../../lib/core/bookmarks/src/widgets/bookmark_sort_button.dart)
- [Popup component](../../../lib/core/bookmarks/src/widgets/bookmark_option_selector.dart)
- [Bookmark groups](../../bookmark_groups.md)

Dependencies: None.

## Progress and verification

Implemented and formatted on the work branch. The focused bookmark controls and
sorting tests pass, including narrow width, enlarged text, and keyboard coverage.
The complete application, package, CLI, and repository-tooling suites passed
locally. One concurrent application run intermittently missed cached image pixels;
the same test passed in the complete run and again in a serial focused rerun.
No device test was needed for this widget-level change.
