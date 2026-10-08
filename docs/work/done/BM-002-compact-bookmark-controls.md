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

- [x] Keep the current text field visible in the list header on All,
  Ungrouped, and named-group bookmark views. It continues to search bookmark
  tags and offer its existing suggestions; it is not moved into a menu.
- [x] Replace the horizontal source chips and separate sort row with one row:
  a sort selector showing Newest, Oldest, or Random, a reshuffle button only
  while Random is selected, and a source selector showing `Source: All` or the
  selected source URL. Source opens an anchored context popup containing the
  existing source URL options and All, without a separate search field.
  The smaller, lower-contrast bookmark count follows the filters on the same
  row, immediately before the grid-settings menu at the far right. The filters
  and count scroll horizontally with complete labels; the menu stays fixed.
- [x] Selecting Random shuffles once. The reshuffle button produces a new
  random order without changing the selected source, group, or tag query.
  Switching to Newest or Oldest removes the reshuffle button and preserves
  the current sorting behavior.
- [x] Filtering to zero posts does not hide the text field or selected source
  and sort controls. Clearing a tag or source filter restores the expected
  posts without changing bookmark or group data.
- [x] Long source URLs remain fully readable in the horizontally scrollable
  filter row and choice surface, with full accessibility labels. At narrow
  widths and enlarged text, controls remain operable without overflow or text
  truncation, and the count remains on the same row.
- [x] All new visible labels and accessibility text are localized. Focused
  widget tests cover source and sort choices, Random reshuffle, the visible
  search field, zero-result recovery, and narrow/enlarged layouts. Validate
  the resulting layout manually; the user confirmed their own verification
  on 2026-10-08. No additional Android/Maestro run is required.

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

## Claim

- Implementer: Codex root session, 2026-10-07.
- Branch: `agent/bm-002-compact-bookmark-controls`.
- Worktree: `.worktrees/bm-002-compact-bookmark-controls`.

## Implementation and verification

- Kept the existing bookmark tag search and suggestions in the list header for
  All, Ungrouped, and named groups.
- Replaced source chips and the separate sort row with a wrapping compact row.
  Source opens an anchored popup menu, including a localized All option.
  Long sources truncate in the row and remain complete in the popup, tooltip,
  and accessibility label. Source options retain their existing URL/host meaning.
- Sort offers Newest, Oldest, and Random. Selecting Random shuffles once;
  selecting it again preserves the order. The separate reshuffle action changes
  the seed while retaining group, source, and tag filters. Rapid presses now
  receive distinct seeds.
- Both selectors remain visible after zero-result filters. Existing localized
  source, All, sort, and shuffle strings cover all displayed and accessible text.
- `fvm flutter test --no-pub` on `bookmark_list_controls_test.dart`,
  `bookmark_details_page_test.dart`, and `bookmark_library_state_test.dart`:
  **34 passed**. Tests include full-page zero-result recovery and reshuffling in
  all three view kinds, source choices and dismissal, all sort choices,
  full source semantics, and 320px width / 200% text with keyboard insets.
- Affected-scope `fvm flutter analyze --no-pub`: **No issues found**.
  `git diff --check`: passed.
- Required missing generated outputs were created with `./gen.sh` in the fresh
  worktree. No generated tracked files changed.

## Historical device-validation limitation (resolved by user verification)

The initial Android/Maestro validation could not run: `adb devices -l` returned no devices,
while Maestro MCP `list_devices` timed out after 180 seconds. The agent therefore left the final acceptance
criterion unchecked and initially retained the ticket in `in-progress`.
The user subsequently confirmed their own verification on 2026-10-08;
this limitation no longer leaves any acceptance criterion open.
Local commit requested by the user. No integration or publication was performed.

## User-requested layout revision

- Sort precedes source. The grid settings control shares this row and the live
  filtered bookmark count is always its last element, including after wrapping.
- Count uses `bodySmall` and the theme's `onSurfaceVariant` color.
- Source uses an anchored popup menu without its own search field or sheet.
- The prior local commit is `7e894bc18`; this revision is a follow-up to it.

- Revision verification: **24 passed** across `bookmark_list_controls_test.dart`
  and `bookmark_details_page_test.dart`; affected-scope analysis reported
  **No issues found**, and `git diff --check` passed. Coverage includes the count's
  position and subdued style at 800px/320px and 100%/200% text, live zero-result
  counts, popup selection/dismissal, full source semantics, and keyboard insets.
- Latest ADB discovery lists a physical handset only, with no Android emulator.
  Emulator/Maestro layout validation was pending at that stage. The user requested a local commit for this revision and automatic commits for future changes.

## Single-row layout and shared menu revision

- Replaced wrapping with a flexible single row, keeping the small subdued count
  last and on the same line at narrow widths and enlarged text. Source and sort
  labels truncate and retain full accessible labels.
- Both selectors now reuse `KurumiPopupMenuButton` / `KurumiPopupMenuItem`, the
  same rounded anchored menu used by the grid actions. Current options have a
  checkmark and selected semantics. Long source menus scroll within a bounded
  popup; neither selector has a search field.
- Removed the top app-bar menu and its obsolete single-item edit state. The
  grid-actions Select command and Select All retain downloading, group removal,
  and deletion through the existing selection actions. Widget tests enter this
  path, check download is enabled, and open/cancel deletion for all three views.

- Verification for this revision: **25 focused tests passed** across
  `bookmark_list_controls_test.dart` and `bookmark_details_page_test.dart`.
  Affected-scope analysis: **No issues found**. `git diff --check`: passed.
  Emulator/Maestro validation was pending at that stage; no integration or publication.

## Horizontal scrolling and rightmost menu revision (2026-10-08)

- The grid-settings menu stays fixed at the far right. The small subdued count
  follows the filters, immediately before this menu. When content fits, the
  count aligns beside the menu; overflowing content scrolls horizontally.
- Removed ellipsis from filter labels and count. Source URLs, sort names, and
  count text render fully even at narrow widths with enlarged text. The count
  participates in scrolling so large text cannot cause a row overflow.
- Popup triggers remain operable after horizontally scrolling their labels.

- Verification: all 10 control tests passed, including horizontal drag,
  reaching the count at the scroll end, fixed menu position, complete labels,
  and 320px/800px widths at 100%/200% text. All 15 page tests also passed with
  this implementation. Affected-scope analysis: **No issues found**;
  `git diff --check`: passed. Android/Maestro validation was pending at that stage.

## Approved local integration (2026-10-08)

- User approved merging the final controls. Prepared a local `develop` squash
  while preserving its unrelated pinned-search Info/refresh change.
- Integration candidate matched all approved BM-002 files. **39 focused tests
  passed** across control, page, and bookmark-state suites; affected-scope
  analysis reported **No issues found**. Diff checks passed.
- Android/Maestro validation was pending at that stage. The ticket was initially left in `in-progress`
  and its task worktree/branch were retained for that follow-up. This was
  superseded by the user-approved completion and verification below. No push or other
  remote publication was requested or performed.

## User-approved completion and cleanup (2026-10-08)

- The user explicitly requested moving this integrated work item to `done` and
  deleting its remaining local task worktree and branch. This supersedes the
  earlier decision to retain them for device validation.
- Local `develop` commit `5fa9ff79fd41b87999f3cdcda4074a55a7f4ff03` contains
  the final implementation. Every implementation, test, and other task path
  changed on the task branch matches the integrated tree exactly; only this
  ticket's later integration note differs. No implementation work remains.
- Prior focused tests and analysis are recorded above. The user confirmed
  their own verification on 2026-10-08 and explicitly stated that no open
  Android/Maestro check is needed. All acceptance criteria are complete.
  No additional agent-run device validation is required.
- The original worktree has no tracked or untracked changes. Its ignored files
  are disposable Flutter/Dart build, dependency, and generated outputs.
- This completion correction is integrated locally; no remote publication.
