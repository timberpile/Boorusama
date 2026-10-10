# Fit AppBar titles throughout the app without premature truncation

Priority: Normal
Affected feature: All application AppBar titles and bookmark-group overview cards
Status: Done; user visual acceptance and local integration authorized

Agent: Codex UI-001, 2026-10-09; corrections 2026-10-10

Branch: `agent/ui-001-fit-long-bookmark-group-titles`
Worktree: `.worktrees/ui-001-fit-long-bookmark-group-titles`

## Problem

Bookmark-group overview titles wrap to a second line but then end in an ellipsis. Titles in the opened group's AppBar also truncate, even though fitting the text within the already available title box could make more of the name visible.

## Expected behavior and acceptance criteria

- [x] Apply adaptive title fitting throughout the app, including ordinary and scrolling AppBars, settings, source-specific pages, and selection titles. Preserve toolbar geometry, leading/actions, explicit text styling, semantics, and editable search controls. Compound text labels use bounded fitting independently of their controls.

- [x] In the opened group's AppBar, preserve the existing toolbar and title box dimensions. Evaluate the largest complete fit for each feasible line count. Prefer fewer lines unless another layout increases rendered font size by at least 50% compared with the currently selected layout, respecting nonlinear text scaling.
- [x] Use a minimum base font size of **12 sp**, respect Flutter text scaling, and fall back to a sensible ellipsis only if all the text still cannot fit at that minimum. Short titles keep their normal font size.
- [x] The fitting calculation accounts for line height, available width, actions/back navigation, and long/unbreakable words. No clipping, text overlap, new toolbar height, or unnecessary large-text layout overflow.
- [x] In the bookmark-group overview, keep every card square and preserve the responsive 2/3/4-column grid and row alignment. Fit overlaid titles throughout the available card height using the largest-fitting wrapped font and a 12 sp minimum. The AppBar-specific 50% preference does not apply to cards. Long names must not increase card height or shift subsequent rows.
- [x] Keep the original full-preview dark gradient, without separate title or overflow backgrounds. Allow long titles into the lower thumbnail row and close to the overflow touch target, preserving unobscured Rename/Duplicate/Delete actions and any bottom selection/folder indicators.
- [x] Cover short, two-line, three-or-more-line, very long and unbreakable titles, narrow screens, 2x text scaling, and localized strings. Include widget tests for text fitting and a realistic grid/card layout; user visual acceptance recorded below; no agent Android run claimed.

## Context

The opened bookmark listing uses `BookmarkAppBar` and `BookmarkScrollView`. The overview uses `SliverGridDelegateWithFixedCrossAxisCount`, and `_GroupCard` overlays a title with `maxLines: 2` and `TextOverflow.ellipsis` on the preview.

- [Bookmark AppBar](../../../lib/core/bookmarks/src/widgets/bookmark_appbar.dart)
- [Bookmark scroll view](../../../lib/core/bookmarks/src/widgets/bookmark_scroll_view.dart)
- [Bookmark-group overview](../../../lib/core/bookmarks/src/pages/bookmark_group_browser_page.dart)

Dependencies: None.

## Decision

2026-10-08: Prefer automatic font fitting inside the existing AppBar title area, with a 12 sp lower bound. The initial overview decision allowed growing cards.

2026-10-10: User clarification supersedes growing overview cards: cards must always remain square, and their titles must adapt like the AppBar. Remove the global preview tint and use dark rounded backgrounds behind text and overflow only. The user explicitly accepted the corrected AppBar behavior; preserve it.

2026-10-10, subsequent visual refinement: restore the original full-preview dark gradient and remove separate label backgrounds. Expand the title bounds into the lower thumbnail row, with 8 dp card margins and no extra gap before the overflow touch target. Preserve square cards and the accepted AppBar behavior.

## Implementation and verification

- Opened titles measure full-layout candidates with Flutter's text scaler and
  line metrics. They prefer fewer lines unless a later candidate provides at
  least 50% larger rendered text, and use a bounded ellipsis only when no full
  layout fits at 12 sp.
  The original text scaler is passed explicitly through both nested AppBars;
  inherited status-bar insets remain removed inside the outer toolbar.
- Overview cards use fixed-square sliver grids with the same 2/3/4 column
  breakpoints and 12 dp spacing. Titles overlay the available height of each
  preview, including the lower thumbnail row, with 8 dp top/left/bottom margins.
  The right title bound meets the overflow button's 48 dp touch target without
  overlapping it. Folder/selection indicators reserve 40 dp at the bottom only
  when present. The original black gradient (60% top, 40% bottom) shades the
  entire preview; title and overflow have no separate backgrounds. All four
  preview cells remain square and fill the card.
- Focused widget/behavior tests cover short, multiline, extreme,
  unbreakable, and multilingual titles; 320/600/900 dp grids; 2x scaling;
  fixed square sizes and row alignment; unobscured overflow actions;
  back/action width; and keyboard-open dialogs. Card tests check that long
  titles extend into the lower preview row and meet the menu touch target.
  A rendered pixel test checks full-preview shading without label backgrounds.
  Actual BookmarkPage coverage with a 24 dp status inset at 1x/2x scale checks
  the title bounds, fixed toolbar extent, and search position, preserving the
  accepted AppBar behavior. Final results accompany the commit handoff.
- 2026-10-10 workflow clarification from the user: use focused tests and
  affected-scope analysis for design iterations and fixes; run the complete
  local application, package/CLI, and repository-tooling suites immediately
  before merge. The already-started full run for this refinement was stopped
  following that instruction. The 74 focused bookmark tests passed; affected
  analysis has no errors or warnings and two existing informational lints.
- Android acceptance remains pending: on 2026-10-10 ADB discovers online
  emulator-5556 and offline emulator-5554, but Maestro still lists no Android
  devices (only disconnected Chromium). No modified APK was installed or Android UI
  acceptance claimed. Keep this work item in progress until this check passes.

### Full-suite investigation

The initial complete application run failed in the unchanged image-cache test
`progressive live handoff reuses the exact decoded completer when decoded cache
admission is disabled` in `progressive_non_admitted_cache_test.dart`. The run
reported a missing pending adapter request; an isolated named rerun instead
retained the lower red pixels where blue target pixels were expected. These
checks use short asynchronous waits, but the cause has not been established.
No image-cache production or test files were changed as part of UI-001.
All 12 package suites and all three repository-tooling suites passed.
The initial affected-scope analysis reported two existing informational
browser-page lints, with no errors or warnings. A later complete local run for
the AppBar correction passed. Complete local verification of the final change
remains required immediately before merge, following the subsequent user
workflow clarification above.


## Correction of reported regressions (2026-10-10)

The title-below-preview redesign was not agreed and has been removed. Titles
remain over the previews. The subsequent user clarification also removes growing
cards: the grid is square and the title font adapts within its fixed bounds.

The complete MediaQuery override used to bypass AppBar text-scale clamping also
restored the Android status inset inside the nested AppBar. A regression test on
the actual BookmarkPage reproduced title paint extending to 89.5 dp below a
header that ended at 80 dp (24 dp inset + 56 dp toolbar). The correction forwards
only the original TextScaler, without resetting padding or other MediaQuery
values. Toolbar, search, and filter layout positions remain unchanged. The new
page tests verify the original failure mechanism instead of only testing a title
inside a standalone AppBar.

## App-wide title fitting (2026-10-10)

The user extended title fitting to the entire app. All 108 ordinary/sliver AppBar
construction sites now use `KurumiAppBar` / `KurumiSliverAppBar`. The wrappers
preserve Material toolbar parameters, preferred heights, bottom sections, and
scrolling behavior. Plain Text titles fit automatically; compound title labels
(selection counts, source versions, info icons, and bulk-download controls) use
`KurumiFittedText` in bounded slots. Editable search widgets retain their behavior.
The existing bookmark fitting algorithm now lives in Kurumi and is also reused
by square bookmark cards. Original text scaling is forwarded through nested
AppBars without resetting MediaQuery insets.

The two-line source-configuration header gives both labels bounded height and
compact line spacing so enlarged text cannot push its subtitle below the toolbar.
Focused coverage includes real settings/configuration pages, normal/sliver bars,
long/unbreakable/multilingual and RTL titles, text styling/semantics, dynamic
selection labels, control tap targets, centered titles, themed/explicit heights,
collapsed slivers with bottom sections, status insets, and open keyboards.
Final check results accompany the local commit handoff. The full repository
suite remains deferred until immediately before merge as requested by the user;
Android visual acceptance remains pending.

App-wide verification on the final local diff: 208 focused application tests and
all 56 Kurumi package tests passed. Kurumi analysis has no issues; application
analysis has no errors or warnings (113 informational notices remain). A Dart
AST audit matches all 93 ordinary and 15 sliver AppBar sites to the original
construction sites, and wrapper constructor parameters match the pinned Flutter
SDK. No Android UI run or complete repository test run was performed for this
extension; the latter is reserved for immediately before merge.


## AppBar wrapping preference (2026-10-10)

The finalized UX handoff replaces unconditional largest-font selection in
AppBars with a 50% minimum improvement in rendered font size before adding
lines. Each feasible line count gets a measured, complete-fit candidate between
12 sp and the normal style size. Later candidates compare with the currently
selected candidate, so an unselected two-line alternative cannot prevent a
three-line alternative from winning. Candidate bounds come from actual text
metrics and available height, with no fixed line-count cap. Nonlinear text
scalers participate in the comparison without clamping accessibility settings.
If the full title cannot fit at the floor, retain the physically visible lines
and ellipsize the final line; the original text/semantics remain available.

The preference follows `KurumiToolbarTitleScope`, covering ordinary/sliver bars
and their compound labels. Outside that scope the shared fitter retains its
largest-wrapped-font policy. Bookmark cards remain square with their existing
shading and wrapping; no card follow-up is needed for this AppBar change.
Typography, line height, vertical alignment, toolbar dimensions, and subsequent
content positions remain unchanged. No compressed line height or extra toolbar
height was introduced. Visual review by the user remains required before merge.

Verification results are recorded with the local handoff below. The complete
repository suite remains deferred until immediately before merge, as requested.

Final focused verification for the wrapping preference: all 82 Kurumi tests
and all 78 affected application tests passed; Kurumi analysis reports no issues.
Coverage includes the inclusive gain boundary, comparison with the selected
candidate across three lines, four-line layouts, nonlinear scaling, 100/150/200%
text sizes, rich-text fallback semantics, extreme scaling, geometry/insets,
and unchanged square bookmark cards. A cache-pixel test failed in the first
parallel application run, then passed alone and in the complete serial focused
rerun. A temporary Flutter rendering test also passed and produced a before/after
preview using the real toolbar component and app theme (the test placeholder
font was replaced with loaded Roboto). No Android device validation or complete
repository suite was run in this iteration. User visual acceptance and the full
pre-merge suite remain pending; no merge or publication is authorized.


## Accepted local integration (2026-10-10)

The user confirmed the final appearance ("super, das passt jetzt so"), explicitly
authorized local merging, and waived the complete test suite for integration.
Earlier pending visual acceptance is superseded by that confirmation. No new
agent-driven Android/device validation is claimed. Integration preserves the
newer protected Default-group behavior on develop while retaining square cards
and adaptive titles. Targeted conflict checks accompany the integration report.

Integration verification: all 57 focused bookmark folder/browser/AppBar widget
tests passed on the combined develop tree, including Default-group coverage.
The 97 feature files untouched by intervening develop commits match the approved
feature tip exactly; overlapping files were reviewed after automatic/resolved
merging. The complete test suite was explicitly waived by the user.
