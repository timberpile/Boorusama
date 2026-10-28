# Issue #80: Viewer Bookmark Group Picker

## Branch and scope

- Branch: `feature/80-viewer-bookmark-picker`.
- Independent base: `6875e0ce778aecfb2b83780c2185ce9273a9b2cc` (`develop`).
- No dependency on #73 and no changes to its branch. Review possible overlap in
  `bookmark_multi_selection.dart` during a later, explicitly approved integration.
- No merge, PR, issue closure, or develop publication is authorized by this handoff.

## Implemented behavior

Both viewer toolbar variants open the anchored group picker on tap, without an
implicit membership mutation, caption, arrow painter, or long-press bookmark
action. Any saved membership fills the bookmark icon; multiple memberships retain
the count badge. Existing non-toolbar toggle actions keep their API.

The single-post picker pins navigation and Create New Group above the scrollable
hierarchy, with Recent below. Each region remains scrollable when height or text
scaling prevents all rows fitting. The shared folder picker keeps its prior layout
for other callers unless the new optional pinned regions are supplied.

Recent contains at most three distinct stable group IDs. Its optional preference
is stored in the existing `bookmark_folders` Hive box; no adapter or membership
schema changes. Renames/moves resolve through the current library, removed groups
are filtered, and invalid preference values are ignored. Legacy repository
implementations without this optional capability remain supported. Full box
backups can preserve the preference; logical membership imports do not replay it.

Successful manual group additions/removals (including create-with-posts and UI
bulk selection) update recency inside the serialized mutation. No-op and failed
mutations do not. `addPostsToGroup` defaults to non-manual so automatic server
favorite sync and import paths cannot reorder Recent. Undo restores prior data
without recording a new target choice. Preference failure cannot turn a committed
membership operation into a reported failure; it produces a payload-free warning.

## Verification and review

Container: `git diff --check` and JSON parsing. FVM is not installed in this
container; hosted FVM formatting, analysis and scoped regression results must be
read from the final session report rather than assumed from this draft handoff.
Tests cover repository recreation, distinct ordering, corrupt/deleted entries,
manual versus automatic changes, no-ops/failures, both toolbar variants, explicit
selection, nested Recent, pinned scrolling and small-width enlarged-text layouts.
The headless bookmark-library flow is updated for explicit group selection.

Run locally:

```bash
./init.sh
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter analyze --no-pub --no-fatal-infos lib/core/bookmarks lib/core/posts/details_parts/src/toolbars/bookmark_post_button.dart test/core/bookmarks test/application/bookmark_library_flow_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/core/bookmarks test/application/bookmark_library_flow_test.dart
```

Run the i18n package's complete test suite if it contains tests. Generate the new
English fallback key through the normal generation flow; do not hand-edit outputs.

Required Android acceptance: read `docs/android_emulator.md`, obtain an exclusive
lease and use Maestro. Test both viewer toolbars, nested folders, three Recent
entries, add/remove/restart/rename/move/delete, Undo, create-new, large libraries,
small width, large font, open keyboard, and source-profile authentication.
Verify an automatic favorites refresh and bookmark import do not reorder Recent.
Exercise backup/restore of old data without the new preference and new data with it.

A complete LOCAL regression on the final combined integration candidate is still
required before any approved merge; hosted scoped tests do not satisfy that gate.
