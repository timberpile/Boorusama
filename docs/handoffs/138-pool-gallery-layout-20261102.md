# Issue #138 — Variant A Pool gallery layout

The subsequent [pinned timeline status-bar fix](138-pinned-timeline-status-inset-20261102.md)
records the correction and final verification for the Android pinning follow-up.

## Candidate and delivery boundary

Branch: `feature/138-mixed-viewer`, existing isolated worktree `.worktrees/138-mixed-viewer`.
Follow-up base: `56e473663e767a5c57daaf011617b8819a64f35c`.
Implementation and final runtime/test candidate: `d06e1e66a1d016df1357f4312162eae04353a283`
(`feat: compact Pool galleries with floating actions and timeline sort (#138)`).
The documentation-only handoff commit follows this candidate.

This implements the approved Variant A — Full Actions. It supersedes the gallery
chrome/layout described in the [original implementation handoff](138-mixed-viewer-20261102.md).
The Mixed Viewer architecture, source identity/binding, member loading, selection,
pagination and persistence contracts remain.

No push, develop integration, PR, issue closure or branch deletion was performed.
Keep the existing worktree and branch. A changed combined integration candidate
requires complete regression verification before future integration.

## Changes and decisions

Embedded and standalone Danbooru Series/Collections now share a 56dp floating,
snapping action bar: Back, Pool Bookmark, Search and Download. It scrolls away
with no reserved toolbar spacer and returns on upward scrolling. An explicit
opaque application surface keeps the controls readable over media.

`ViewerEntry.usesContentNavigationHeader` defaults to false; Pool entries return
true. The scaffold passes that choice through the backward-compatible
`PostDetailsPageView.overlayEnabled` flag, suppressing the outer Post overlay
for Pool entries. Loading/retry states retain the same navigation header and
existing actions using bounded reference metadata. Missing or invalid source
states offer Back without source-dependent actions. Ordinary Post overlays
retain their existing behavior.

The header owns the top system inset. The Pool grid omits its extra top SafeArea
and retains horizontal safe areas and normal bottom handling. The wrapping
title has 12dp horizontal and 8dp vertical padding, with optional secondary
updated metadata. Description parsing/rendering is unchanged; an empty
description adds no vertical spacer.

Pool sorting uses the existing localized Ordered / Latest / Oldest values in
`TimelineOptionSelector`. Optional `additionalControls` lists extend the generic
Post configuration header; Pool galleries supply the selector after count and
blacklist controls. The overflow button stays in the toolbar's fixed trailing
slot. Only an overflowing toolbar consumes horizontal scrolling; at wide widths
ordinary outer pager gestures remain available.

Local order, the existing member-fetch path and route-local checkpoints remain.
A new sort resets the viewport; selecting the same value is a no-op. Gallery
occurrences retain independent sort state and member Back restoration.
Timeline pinning continues to follow the existing setting. The top action bar
always floats rather than pinning.

### Confirmed rendering defect and correction

The initial restored-gallery regression captured Flutter's
`_RenderSliverFloatingHeader.isScrollingUpdate` reading its child's size while
an ancestor viewport was still applying content dimensions. It triggered
`RenderBox.size accessed beyond the scope of resize, layout, or permitted
parent access`; the durable original stack is in `restore-reproduction.log`.

The shared timeline now measures natural child extent using Flutter's existing
persistent-header renderer. Cached extent and snapping deferred out of ancestor
layout avoid that illegal read. Natural, unconstrained measurement also preserves
empty-to-content recovery and text resizing. The first version constrained the
cached child height too tightly; the existing empty-to-content test caught that,
and it was corrected before final verification. No SDK files or assertions were
modified.

This is the only additional infrastructure correction beyond the approved layout
plan. It is covered by restored multi-page galleries, existing timeline header
recovery/visibility tests, and the complete application suite.

## Verification

**Complete final gate passed:** `./scripts/run_regression_tests.sh`, exit 0 on clean `d06e1e66a1d016df1357f4312162eae04353a283`, using six workers, 2026-11-02 21:35:09–21:47:30 UTC. Application: **6,013 passed**. All 13 package/CLI suites: **1,654 passed**. Pull-request-policy and Android-release shell checks passed. Python tooling: **72 passed**. Two pre-existing `go_router` tests remain skipped: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. Skips are excluded from passing counts. Commit and clean status remained unchanged through completion.

Focused final command:

```bash
fvm flutter test --no-pub --concurrency=6 \
  test/application/pool_bookmark_flow_test.dart \
  test/core/posts/details/mixed_post_details_page_test.dart \
  test/core/posts/listing \
  test/application/timeline_toolbar_scroll_flow_test.dart \
  test/application/bookmark_timeline_toolbar_flow_test.dart
```

Result: **257 passed**, including 16 Pool viewport/text/pinning combinations,
long-title/empty-metadata layout, standalone Collection navigation, pending/error
Back/actions, source cancellation, independent sorting, member restoration,
selection, Post regressions and ordinary timelines.

The matrix asserts actual view size at 320×844, 390×844, 844×390 and 1280×800,
each at 1×/2× text and with timeline pinning off/on. Each header action has a
non-overlapping target of at least 48×48dp. Tests verify scroll-away/reveal,
toolbar/action-bar separation and visible action-bar opacity. The fixed overflow
stays reachable while overflowing timeline content scrolls. Existing generic
selector tests cover keyboard-constrained menus and theme variants.

All 17 owned Dart files pass
`fvm dart format --output=none --set-exit-if-changed <changed Dart paths>`.
Scoped `fvm flutter analyze --no-pub --no-fatal-infos <changed Dart paths>`
returned exit 0 with **0 errors, 0 warnings, 22 informational findings**.
The path list comprises the Dart diff from the follow-up base plus the four new
Dart files. `git diff --check` passes.

`fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`
succeeded from the final committed candidate. Installed APK and that local build
have matching SHA256:
`5f5c9fb3a9458a6ebaa12c3753b8ba0cb96b410a9f00d782f719453d25128471`.

Earlier checks are not counted as final passes. Initial focused tests exposed
the restored-gallery rendering assertion; the first renderer revision failed
empty-to-content recovery. Test development also caught an incorrect phone
fixture overriding requested viewport sizes, a long-title toolbar below the
initial viewport, and a horizontal gesture incorrectly tested as toolbar
scrolling when the controls already fit. Final tests assert actual viewport
dimensions, reveal below-fold content, and scroll controls only when overflow
exists. Two exploratory name filters matched no tests and were rerun correctly.
The initial analysis caught a bad import and later an unused test import; both
were fixed. The corrected full focused command above passed.

Known libavif native-hook build warnings recur on unchanged source; see
[build troubleshooting](../build_troubleshooting.md). Nonfatal native Dart
finalizer messages and existing Android toolchain support warnings also appeared.
Pass claims use completed exit statuses, not absence of those diagnostics.

## Android acceptance

Maestro controlled exclusively leased `emulator-5554` without resetting app data.
The live Danbooru query used separate `rating:g` and `4koma` chips, opening
“Grimoire ~Shiritsu Grimoire Mahou Gakuen~ - Idle Astronomy! (Miyako Hito)”.

Before/after PNGs show the same decoded first thumbnail banner moving from
y=982 to y=734 at density 2: **248 pixels / 124dp reclaimed**. An RGB comparison
of the 324×122 banner region matches 100 percent after translation, confirming
actual decoded content positions. Evidence is `before-pool-decoded.png`,
`final-initial.png` and `content-position-comparison.json`.

Observed on the final runtime:

- One compact top action row and a count/sort/fixed-overflow timeline.
- Decoded gallery thumbnails, vertical scroll-away, and upward return of both
  headers without overlapping controls or a permanent spacer.
- Ordered, Latest and Oldest choices; Latest visibly changes member order.
- Member viewer opening and Back to the same gallery anchors with Latest
  preserved, including at Android text scale 2.0.
- Horizontal Pool → ordinary Post → Pool navigation restores the proper header
  and selected sort.
- Landscape exposes all four actions and all three sort choices. Enlarged text
  wraps the full title and retains reachable sorting.
- Overflow exposes Select, Stats, Edit Blacklist and View Options. A horizontal
  drag in selection mode leaves the gallery selection footer visible and does
  not open an ordinary Post; closing selection restores normal gallery controls.

An exploratory assertion expected the offscreen Latest label during selection
and failed. The subsequent check used the visible selection footer, then
revealed the header and confirmed Latest. Some immediate captures preceded the
final animation/paint; stable repeated captures are the visual evidence.

Font scale is restored to 1.0, accelerometer rotation to 1 and user rotation to 0.
The original Browse profile, Safebooru (Danbooru), was explicitly confirmed
selected; the picker was dismissed, Browse left open and the lease released.
No bookmarks, remote favorites/votes, network settings or automatic-media settings
were changed. QA queries remain in ordinary Search history.

Live Android exercised a Series. Standalone Collections, exact 320/390dp widths,
wide layouts, source removal and controlled API failures/retry are covered by
automated tests rather than additional live acceptance. No physical-device or
latency measurement claim is made.

Durable local logs, before/after screenshots, provenance and acceptance records
live in `.worktrees/_artifacts/138-pool-layout/`; raw artifacts are not committed.

Readiness: **READY FOR INTEGRATION** on the recorded candidate, with the live-service limits above. Integration/publication remain unauthorized; verify any changed combined develop candidate before integration.
