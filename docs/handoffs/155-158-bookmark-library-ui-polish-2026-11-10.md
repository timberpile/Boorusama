# P4 picker, search and navigation polish — 2026-11-10

## Follow-up: duplicate the complete subgroup hierarchy

The owner confirmed that duplication should recursively copy the selected group
and every subgroup. Both active entry points (single repository duplication and
browser batch duplication) now share the tree's branch-copy operation and commit
all copied groups in one organization transaction. Each group has a fresh ID;
parent links point to copied parents. Child names, relative order, direct
memberships and membership dates survive, including empty/deep groups. Copied
roots remain siblings of their sources. Saved records are shared, not duplicated.
Overlapping ancestor/descendant selections copy the ancestor branch once.

Verification: `fvm flutter test --no-pub --concurrency=6` passed **93 tests** from:

- `test/core/bookmarks/bookmark_hierarchy_mutations_test.dart`
- `test/core/bookmarks/bookmark_group_hierarchy_test.dart`
- `test/core/bookmarks/bookmark_unified_group_repository_test.dart`
- `test/core/bookmarks/bookmark_unified_library_service_test.dart`
- `test/core/bookmarks/bookmark_library_service_test.dart`
- `test/core/bookmarks/bookmark_hierarchy_bulk_mutations_test.dart`
- `test/core/bookmarks/bookmark_hierarchy_scoped_actions_test.dart`
- `test/application/bookmark_hierarchy_screen_flow_test.dart`

New persistence tests cover both entry points, one revision per hierarchy copy,
restart, unchanged original groups/payloads, independently renamed child copies,
and invalid batch names leaving storage untouched. Tree tests cover overlapping
selections, multiple branches and sibling order when positions were tied.
`fvm flutter analyze --no-pub` on the six changed Dart files reports zero errors
and warnings, with 32 existing informational findings (exit 1).
Evidence: `.worktrees/_artifacts/p4-recursive-duplicate-20261110/`.
No new complete-suite, APK, device or develop-integration result is claimed.

## Follow-up: implicit focus scrolling in floating search fields

The prior guard only covered our explicit Structure reveal callback. Production
screen regressions reproduced a second path: Flutter's implicit caret reveal
rewound an already visible floating search field to its original sliver offset.
Structure moved from 2717 to 2169; subtree mode moved from 548 to zero. Both
regressions failed before this correction, with the harness opening the keyboard.

A search-local render proxy now skips redundant implicit reveal when the entire
field is already inside its viewport. Clipped fields still delegate to Flutter,
and the explicit forward-only Structure reveal remains unchanged. No shared
header, navigation, or Kurumi behavior changes are included.

The focused verification covers floating and pinned search across direct,
subtree and global views, production-screen focus/typing/autocomplete with the
keyboard open, enlarged text, landscape keyboard constraints, and header/toolbar
flows. Evidence: `.worktrees/_artifacts/p4-search-focus-reveal-20261110/`.
Final verification on this patch: 44 tests passed using
`fvm flutter test --no-pub --concurrency=6` with
`test/core/bookmarks/bookmark_search_bar_test.dart`,
`test/application/bookmark_hierarchy_screen_flow_test.dart`,
`test/application/bookmark_timeline_toolbar_flow_test.dart`, and
`test/core/posts/listing/timeline_header_sliver_test.dart`.
`fvm flutter analyze --no-pub` on the implementation and the two changed test
files reported zero errors/warnings and nine existing informational findings
(exit 1). The production hierarchy test retains its existing missed-tap warning;
the runner also emitted the existing Dart finalizer diagnostic without failures.
No new APK, device run, complete-suite result or develop integration is claimed.

## Latest owner clarification: forward-only Structure reveal

Focus scrolling is now explicitly enabled only for the direct Structure timeline
with preceding subgroup cards. Its target is the header's actual preceding scroll
extent, not the screen position of a pinned/floating field. It only advances when
the current scroll position is before that boundary; it never rewinds an entered
timeline. Unified/subtree, global All Bookmarks and groups without a subgroup
section do not opt into the behavior.

Thirty-one focused search, production hierarchy and timeline-toolbar tests pass,
including unchanged scroll offsets after focusing an entered direct timeline,
a unified timeline and global All Bookmarks. Forward reveal still works with
pinned/floating headers, enlarged text, IME changes and deferred-focus removal.
Affected analysis reports zero errors/warnings and seven informational findings.
Evidence: `.worktrees/_artifacts/p4-search-forward-only-20261110/`.
No fresh complete-suite or device result is claimed for this scoped correction;
final integration verification remains separate.

## Latest owner clarification: readable moving navigation

The owner reported unreadable Browse navigation after the all-state transparent
surface. This supersedes the transparency requirement below: the visible bar
again uses its theme's surfaceContainer fill. The fill is inside the same slide
as the controls, so it leaves the viewport with the bar; the browser remains
full-bleed and no fixed background strip is restored.

The animation regression now checks the actual surface color and its translated
top edge at visible, dragged, intermediate hide/reveal and hidden states. Twelve
related navigation/chrome/viewer tests passed. Analysis of both changed Dart
files reported no issues. Evidence is under
`.worktrees/_artifacts/p4-nav-readability-20261110/`.
This scoped color correction has no new complete-suite, device or APK result;
the earlier full-suite evidence below remains historical for its named candidate.
Fresh final-candidate verification is still required before integration.

Branch: `feature/155-158-bookmark-library-package`. Runtime/test candidate:
`e7fca8ecd6117bf84973b8ecf39d3a24e40fe2ad`. Own feedback base: `559d90f34`.
Local continuation of #155/#158; user acceptance and integration remain separate.

## Requested behavior

- Center the chevron horizontally within its independent navigation hit target.
- On clicking/focusing group search in Structure view, scroll the search header
  to the leading edge beneath the AppBar while keeping suggestions usable.
- Remove the main navigation's painted background entirely, including while
  the bar is visible, dragged, hiding or revealing.

## Implementation and evidence

The picker retains its independent 80/20 hit regions, 4dp inset navigation surface,
leaf membership action and selected semantics. Centered icons now have symmetric
placement; measured title padding reserves only the centered icon's painted space,
avoiding text overlap in both directions. The 280/396dp geometry tests assert
centers, nonoverlap, margins, keyboard actions and at least 70% label width.

Group search coalesces focus/tap reveal requests into the next frame, aligns the
existing scrollable to its leading edge, and respects app/system reduced motion.
The callback checks mounting, retained focus and the captured BookmarkView before
starting. It never commits the draft, changes filters or fetches content. Tests
assert top alignment before/after IME changes at 320dp and 1x/2x text, retained
focus, repeated typing/selection, and safe removal before the deferred reveal.

The residual background was an explicit Material fill on the navigation surface,
plus a fixed browser SafeArea crop. The earlier fix only released the 64dp app
allocation after hiding. The surface is now MaterialType.transparency in every
state, and the browser viewport extends behind it continuously. Controls retain
their native SafeArea placement; scrollable end spacing keeps final cards clear.
Popup/toast obstruction measurement remains independent and unchanged.

Independent review identified an actual pagination clearance issue exposed by
removing the crop: with a top-only page indicator the final tile ended at
794.2857 while navigation began at 746. The bottom-indicator control passed.
Top-only pagination now receives scrollable viewPadding; infinite mode keeps its
existing padding, and a bottom page indicator retains its existing SafeArea
without a second inset. Application tests check the final row against the actual
navigation edge in both pagination cases.

The real-app navigation test checks a full-height group viewport and the actual
nearest Kurumi/material_ui Material at visible, dragged, genuinely intermediate
hide/reveal frames and fully hidden/revealed states. Its fractional offsets prove
the intermediate checks exercise animation. The initial draft used Flutter's
separate Material type; that selector was corrected rather than treating the
unrelated scaffold material as the navigation surface.

## Verification

- Reproduction before the fixes: seven expected assertion failures covering four
  chevron geometries, two focus positions and one fixed bottom crop.
- Initial corrected focused command: **26 passed**, including the new actual-app pagination
  cases and focus-removal guard. The top-only pagination RED above was reproduced
  before the shared end-padding repair.
- Earlier neighboring consumer command at `08bec6ea`: **362 passed**, covering folder UX, hierarchy,
  picker lifecycle/layout, complete Bookmark details and Favorites dialog files,
  navigation chrome/overlay/toast, all Post-listing tests, timeline toolbar flows
  and viewer lifecycle. The existing lifecycle hit-test warning at line 221 is
  also present in the preceding qualified C3 full log; it is not counted as a
  new pass/failure or a device acceptance result.
- All nine changed Dart files format cleanly. Affected analyzer: exit 0, zero
  errors, zero warnings and 28 informational findings.
- Six detected physical cores; no competing test compilers were launched.

The first complete attempt at `08bec6ea` found a real remaining obstruction in
an unchanged production hierarchy test: after landscape/IME changes at 2x text,
pinned controls ended at 376 while navigation began at 305. The full viewport
height made the renderer incorrectly consider the wrapped header small enough
to pin. The run was explicitly stopped after 3,032 passes/one failure; exit -15
and its interruption record are retained. No complete pass or package/tooling
coverage is inferred from that attempt.

Pin eligibility now uses the unobstructed viewport by subtracting the remaining
MediaQuery bottom padding. The painted image viewport stays full height; a
header too tall for the actual interactive space scrolls rather than pinning
its actions beneath navigation. Existing consumed SafeArea/keyboard layout is
not counted twice. The private render property invalidates layout on changes.
The unchanged production regression, header units, expanded pinned/floating
focus matrix and navigation/pagination tests pass together: **39 passed**.

Final complete suite: `./scripts/run_regression_tests.sh` passed on exact
`e7fca8ecd6117bf84973b8ecf39d3a24e40fe2ad`, exit 0: **6,589 application tests**,
**1,677 package/CLI tests** across all 13 roots, both repository shell suites and
**76 Python tests**. Two existing GoRouter skips remain; no complete root was
skipped. Use `complete-regression-final.log`, its `.commit`/`.exit` and
`final-suite-counts.json`, not the interrupted first attempt.

The independent Sol High reviewer subsequently reconciled the exact commit,
exit marker, all 14 Flutter completion lines and shell/Python results. Final
whole-candidate verdict: **APPROVE**. The report commit changes documentation
only, so the unchanged runtime/test pass remains applicable.

Independent actual GPT-6.1 Sol High source review: **APPROVE SOURCE** on exact
`e7fca8ec`. The pagination and pinned-header findings were corrected and the reviewer reconciled
focused/consumer/static evidence. Review: `sol-high-review.md` under
`.worktrees/_artifacts/p4-ui-polish-20261110/`.

No new APK, Android/Maestro or live-service verification was performed. Current
claims are automated host/widget/application evidence; earlier Android evidence
is historical and does not establish these animation/focus changes on a device.
No P4 merge, push, issue closure or release is authorized. P5 and later package
branches were not changed by this follow-up.

## Manual follow-up

Build from the owning worktree, not the untouched primary checkout:
`.worktrees/155-158-bookmark-library-package`.

1. Check centered parent chevrons and label readability in ordinary/Recent pickers.
2. In Structure view below group cards, click search: it should scroll beneath
   the AppBar, retain focus and show selectable tag suggestions with the keyboard.
3. Drag, hide and reveal navigation: images should remain visible behind the
   buttons with no solid bar background, including intermediate animation frames.
4. With top-only pagination, scroll to the final saved row and verify it remains
   fully reachable above visible navigation controls.
