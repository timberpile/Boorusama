# Issue #104: deliberate swipes over expanded details

Branch: `feature/104-expanded-details-swipe`.
Runtime/test commit: `3f4750c7814341c9c11ab6ddee183281ca11ec2f`.
Parent: `d4037633c0a8ca26636e82a49003bb6f0870806e`.

## Result

On phones in horizontal viewer mode, a deliberate sideways swipe over expanded
details now changes posts and collapses the panel, just like media paging.
The gesture requires at least 48 logical pixels horizontally and horizontal
movement at least twice vertical movement. Navigation occurs on release.
Vertical intent, reversal to the starting point, pointer cancellation and
multitouch cancel paging. The recognizer participates in Flutter's gesture
arena so nested horizontal scrolling, controls and long-press text selection
retain ownership of their gestures.

Zoom, disabled paging, sheet/viewer animation, vertical mode, large screens and
page boundaries retain their restrictions. Eligibility is checked both when
installing the recognizer and immediately before navigation. Disabled animation
uses an immediate page jump; animated paging retains the existing controller
transition. The existing page-change collapse and full new-post details remain.

## Verification

FVM Flutter 3.47.2; ordinary test concurrency: six physical cores.

```sh
fvm flutter test --no-pub --concurrency=6 \
  test/core/posts/details_pageview test/core/posts/details
```

Passed: 231 tests, exit 0. Includes forward/back swipes over details with
animations enabled/disabled, short/diagonal/vertical rejection, actual metadata
scrolling, nested horizontal scrolling, taps, long-press selection and dragging,
multitouch, mid-gesture zoom changes, cancellation, reversal and page boundaries.
Nested controls/selection also run at 320 logical pixels wide with 2x text.
Existing media, zoom/navigation and mixed-profile viewer consumers pass.
The first focused run exposed a zero-duration animation assertion; immediate
paging was corrected to use the controller's jump path, then the full affected
scope was rerun on the final candidate.

Scoped `fvm flutter analyze --no-pub --no-fatal-infos` over all three changed Dart
files: exit 0, zero errors, warnings or informational findings. FVM formatting,
final diff review and `git diff --check` passed.

Durable local logs/provenance: `.worktrees/_artifacts/metadata-and-details-followup-20261101/`
(`104-final-consumers`, `104-final-analysis`). This handoff adds documentation
only after the checked runtime/test commit.

## Manual acceptance

No new APK/device verification or complete repository regression was run for
this scoped follow-up. Prior device/full-suite evidence applies only to the
candidate recorded in its historical handoff. Human gesture acceptance remains:

1. Expand actual post details on a phone. Clearly swipe left/right over metadata;
   confirm one post change, collapsed details, and correct metadata on reopening.
2. Scroll metadata vertically and diagonally; use tags/links, nested horizontal
   content, long-press selection and selection-handle dragging without paging.
3. Compare slow and fast swipes, rapid/mid-snap actions, zoom/video, disabled
   paging and animation, vertical mode and large-screen layouts.

A complete local suite is required on the eventual integration candidate.
No push, merge, PR, issue closure or branch deletion was performed.

## Accepted integration scope (2026-11-01)

The user reported that swiping the details content has no preview motion during
the drag, and authorized merging the current behavior if adding it is not a
simple fix. Inspection confirms that the recognizer deliberately commits on
release and that the details sheet is a separate overlay above the media pager.
A coherent finger-following transition would need to coordinate those layers,
cancellation and nested gesture ownership; it is deferred from this accepted
scope. The current release-triggered navigation is accepted for integration.
The approved source is `9e8b5a5aa9edaf43f3a98337c071c76fb4b210e6`, combined with
develop `f3a84d9178cebd799c1cab56d0a14cea97e7552c`. Integration qualification and
publication are recorded separately from the historical scoped checks above.
