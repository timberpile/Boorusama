# P4 manual-feedback corrections — 2026-11-10

Latest continuation: [picker, search and navigation polish](155-158-bookmark-library-ui-polish-2026-11-10.md) records centered chevrons, focus alignment and removal of the navigation background throughout animation, with new exact-candidate verification.

Branch: `feature/155-158-bookmark-library-package`. Runtime/test candidate:
`c3de4a95aef18046587867d5b21f38f21c7476b6`. Preceding qualified package: `0ff22c009`.
Local continuation of #155/#158; integration and user acceptance remain pending.

## Behavior and causes

- Leaf groups in ordinary and Recent picker rows now use the full width only for
  direct membership. They have no chevron, navigation surface, tooltip or action.
  Parent rows retain independent 80/20 actions, with 4dp margins around the
  navigation surface. The resting fill is onSurface at 4% opacity, subtly lighter
  on a dark popup and slightly darker on a light popup. Back has no custom fill.
  Merged semantics retain the saved-membership state on the single leaf action.
  This owner feedback supersedes the earlier qualification's intentionally
  navigable empty-group behavior; child creation remains available in the browser.
- Group autocomplete now repositions during enclosing scroll changes. The default
  popover dismissed on keyboard-triggered scrolling below Structure cards and
  did not reopen while the same field retained focus. The regression reproduces
  the lost suggestion at 320dp/2x text with the keyboard open; the final test types
  multiple drafts, preserves focus and selects a suggestion at both 1x/2x text.
- A hidden main navigation bar no longer leaves its 64dp synthetic MediaQuery
  bottom allocation. The actual application regression reproduced a viewport
  bottom of 746 instead of 810 after hiding, then checks hide/show restoration.
  Native system safe-area padding remains; visible chrome keeps its allocation.
- Static Group cover Posts use the same source-specific thumbnail generator, quality
  settings, fallback and decoded-format renderer as Timeline Posts. Hard-coded
  sample-only selection could select an empty or HTML Realbooru preview instead
  of its supported thumbnail. Known source/profile resolution owns both the
  generator and image authentication; the active unrelated profile is not used
  as a fallback. Unknown sources retain the generic renderer.

The existing grid renderer is exposed as `PostGridImage` with optional cover
geometry; its Timeline defaults and bounded candidate/cache/decoder behavior are
unchanged. Static-GIF detection is shared by the preview helper and actual card,
including uppercase formats and URL-only legacy evidence. No animation is
requested when autoplay is disabled and there is no proven static poster.
GIFs retain the established sample/poster URL in both autoplay states instead of
switching to original-quality media; they do not evaluate the static generator.

## Verification

FVM formatter: all 13 changed Dart files clean. Affected analyzer: exit 0,
zero errors, zero warnings and 20 informational findings. Default concurrency
is six detected physical cores. The 13-file consumer command passed 177 tests
but failed ten folder UX fixture cases; after those fixture corrections, all
54 tests in that file passed. This combination is diagnostic evidence, not
represented as one successful final broad command.

The first complete run at `e0f920b52` failed: 6,574 passed and ten failed.
Six assertions/fixtures still encoded superseded contracts (two Recent leaf
padding assertions, three hidden-bar viewer-exit insets, and one Favorites
creation path into a leaf). Four unchanged mounted GIF-cover tests exposed
original-vs-sample request selection. Runtime now retains the original GIF sample
contract; the tests were not weakened and their clock/timeout guards did not
change. All **80 tests** in the five affected consumer files then passed,
including actual controlled decode, no original-GIF request and cache-drain
checks. Final commit `c3de4a95a` contains that correction.

Final complete suite: `./scripts/run_regression_tests.sh` passed at exact
`c3de4a95aef18046587867d5b21f38f21c7476b6`, exit 0: **6,584 application tests**,
**1,677 package/CLI tests** across all 13 roots, both repository shell suites
and **76 Python tests**. Two existing GoRouter skips remain; no complete test root
was skipped. Use `complete-regression-final.log`, its `.exit`/`.commit` and
`final-suite-counts.json`. The earlier `complete-regression.log` is a failed
run, not reusable success evidence. The final runtime/test tree remains unchanged
when this report is committed.

The independent actual GPT-6.1 Sol High reviewer found and root repaired two
first-draft regressions: missing broad GIF detection in the actual card and lost
selected semantics on full-width leaves. `MergeSemantics` was checked against the
actual selected/unselected accessible node. Corrected-tree source verdict:
APPROVE SOURCE in `sol-high-review.md` under the evidence root. After the final
runner completed, the reviewer independently reconciled the exact commit/exit,
all 14 Flutter completion lines, shell/Python results and focused/static checks.
Final whole-candidate verdict: **APPROVE** at `c3de4a95a`. This is technical
approval for a user rebuild/manual retest; integration remains unapproved.

Earlier draft compiler/fixture failures are not passes. The 13-file consumer run
initially had 177 passes/10 failures, all in folder UX fixtures: three lacked the
production global presentation override; two compact-menu and five creation cases
navigated a leaf under the superseded contract. The fixtures now use the actual
null global presentation scope and real parent nodes, retaining the original
creation destination/geometry/selection assertions. Dedicated leaf regressions
prove navigation is absent. Final evidence must supersede the initial run.

Evidence root: `.worktrees/_artifacts/p4-ui-feedback-20261110/`.
No new APK, Android/Maestro or live Realbooru request was performed. Current
rendering evidence is controlled automated coverage. Earlier runtime973 Android
migration/restoration evidence remains historical and does not claim these UI
changes were exercised on a device. P5's earlier candidate and tests do not include
this P4 follow-up; reconcile its own delta when its sequential turn arrives.

## Focused manual follow-up

1. In ordinary and Recent picker lists, tap leaf rows near either edge: only
   membership changes. Parent rows navigate only through their separate surface;
   check the margins, subtle fill and unfilled Back action.
2. In Structure view below child cards, open the keyboard and type/edit several
   tag prefixes; suggestions should remain selectable, including enlarged text.
3. Hide and reveal the main navigation while browsing groups and images; no
   app-owned black strip should remain after the bar hides.
4. Compare Realbooru group covers with their Timeline, including low/high image
   quality; check static GIF posters with autoplay disabled.
