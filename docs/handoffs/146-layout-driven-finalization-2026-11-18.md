# Attached Search header (#146)

Continue `bug/146-search-toolbar-overlap`. It includes accepted #175 from
`origin/develop` at `96e026cc9b7db88bd8544166deacaa5a15a0867e`, through local
synchronization commit `09410864ec893a87379a2fb1fbac3435afcfc9c1`.
#175 has been published and closed independently. #146 remains open for owner
Android acceptance; keep its branch/worktree. #96 is unchanged.

## Current behavior

With top Search placement, Search Bar, selected tags and Timeline Toolbar are
one natural-height Column on an opaque semantic surface. When both rows auto-hide,
one outer clip/alignment changes its visible layout height, so both rows receive
the same absolute displacement throughout dragging, snapping and reversal.
The toolbar cannot slide behind an independently animated Search Bar.

Both existing preferences remain independent. A pinned Search Bar stays visible
while the Toolbar collapses beneath its edge; a pinned Toolbar stays visible as
the Search Bar collapses above it. Both pinned means both visible. Bottom Search
retains its separate bottom placement and the original top Timeline Toolbar.
No settings or persistence formats change.

The top results viewport stays stationary while the floating panel moves.
A leading sliver reserves the measured natural height of its collapsible rows;
pinned rows reserve a fixed viewport inset. A 24 dp drag now moves the rows
and a visible tile by 24 dp; the earlier resizing viewport moved the tile
by 48 dp. Normalized rendered progress is retained through height changes.
Only snaps apply the existing 300 ms ease-in-out curve. Interrupted
snaps stop at their current rendered position; reduced motion snaps immediately.
Programmatic restoration does not initiate autohide. Fully hidden controls are
excluded from input, focus and semantics. Editor/options states show the editor
and remove the Toolbar's occupied height while retaining its state.

The earlier #146 corrections remain: the applied Search route paints an opaque
surface outside its inner SafeArea; actual editor layout replaces the estimated
56+48 dp reservation that exceeded the observed 92 dp editor by 12 dp. Query keys,
raw indices, viewer mappings, native Work restoration arguments and grid/scroll
controllers remain independent of header animation.

## Ownership and interfaces

`TimelineToolbarHost` is a route-local presentation slot. Inside its scope,
`TimelineHeaderSliver` supplies the existing Toolbar to that slot instead of
creating a second floating-header animator. Outside Search's top placement,
the existing measured floating/pinned sliver is unchanged. Standard Post and
native Work grids receive the same leading sliver before their result headers.
The Android check is to drag and reverse slowly in applied Search results,
with both top rows set to auto-hide, and compare a tile with the finger.

The standard configuration header and its menu accept optional explicit Post
and selection controllers. They still use inherited controllers for existing
callers; hosted Search passes the grid's exact existing controllers. The slot
copies theme and profile/access values, rather than retaining a descendant
ProviderContainer after its grid has been removed. Publication is coalesced after
build, query changes clear the old slot, and owner-checked release callbacks
cannot remove a replacement Toolbar or notify a disposed host.

`CurrentBooruConfigScope` accepts an optional compact unavailable widget. The
host supplies an empty widget when its source profile/access disappears. A
focused test reproduced an infinite-height Scaffold layout failure without this
fallback. Existing callers retain the original unavailable-profile behavior.

## Verification

Checked state: the final runtime/test working tree based on synchronization
commit `09410864ec893a87379a2fb1fbac3435afcfc9c1`, committed together with this
handoff. No runtime/test changes were made after the final checks.

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/core/search/search_{attached_toolbar,toolbar_overlap,layout_geometry,editor_surface}_test.dart \
  test/core/posts/listing/{timeline_header_sliver,timeline_toolbar_widget}_test.dart \
  test/boorus/pixiv/works/{work_listing_entry_points,work_attached_footer}_test.dart \
  test/application/{timeline_toolbar_scroll_flow,selection_search_actions_flow,soft_keyboard_search_flow,search_history_flow,post_selection_layout_flow,view_options_insets}_test.dart \
  test/core/content/profileless_content_access_test.dart
```

- **99 passed** on the final candidate; six workers match detected physical cores.
- Formatting and `git diff --check` passed.
- Affected-scope analysis of eight source/test files: **zero errors, zero warnings,
  11 pre-existing informational findings**. The analyzer exits 1 because infos
  are fatal under its default CLI policy; it is not a clean analyzer pass.
- The attached-header regression fails against the previous Search implementation
  at `3f3dc68607142456238de875080b71b5cad8b8f2`: its floating Toolbar disappears
  after programmatic scrolling while the editor remains visible. The final
  implementation passes that check and the intermediate-frame motion assertions.
- New tests cover all four preference combinations at 320 dp and 1x/2x text,
  genuine pixel-matched drags, both snap directions, interruption, height changes
  during dragging, reduced motion, query replacement and profile withdrawal.
  The hosted Select menu operates the grid's original selection controller.
- Native tests use the real Pixiv Search/Work grid with fake endpoints and retain
  viewer entries, request counts, route page/restoration behavior and controller
  identity. Existing keyboard, bottom placement, selection, opaque-surface and
  #175 connected-footer consumers pass in the same final run.

Earlier compiler/fixture failures and the deliberately failing before-correction
runs are not counted as passes. Durable logs are in
`.worktrees/_artifacts/146-attached-header-20261118/`, including
`final-candidate-tests.log`, `final-candidate-analysis.log`,
`before-regression.log` and `profile-lifecycle-probe.log`.

No APK, emulator/Maestro, Android or live/authenticated service checks were run.
Owner Android acceptance of #146 remains pending. This branch has local commits
only for this continuation; no #146 publication or integration is included.
Before a future approved #146 develop integration, run the complete local gate
on the combined final candidate. The earlier #175 complete pass qualifies only
its independently published candidate, not this #146 combination.
