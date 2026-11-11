# Shared Post Viewer review candidate (#164)

The shared Viewer uses Immersive and Details modes, with one media subtree and
one scrolling Details surface per occurrence. Horizontal paging moves the entire
page continuously and retains its mode. This is P8's first change; P1-P7 remain
completed, and #140/#141 remain outside this acceptance package.

## Candidate and delivery boundary

- Base: published develop `35f205d900c6e4fb6f2f21478f887ee03b8a5d4a`.
- Branch: `feature/164-redesign-shared-post-viewer-modes`.
- Runtime/test candidate: `defbbfe19c9fda1637539463f3a6254dce7bb2e7`.
- Candidate tree: `bc239591013ee02c46b51a2575b3a6b167d65feb`.
- Prior qualified baseline: `3f8ec89626a83b7434a52ada05d92452f0a59459`;
  its pass does not replace verification of the new runtime candidate.
- The owner accepted the motion/video candidate `7a6e5cf66` on 2026-11-11 and
  authorized merge after the final deferred-source refinement. The UI source is
  unchanged by that refinement. This report records the approved local candidate
  for the subsequent squash publication to `origin/develop`; no PR, emulator
  operation or review APK build was requested or performed.

The [design contract](../designs/2026-11-10-unified-post-viewer.md) includes the
owner's successive device-review clarifications. The approved HTML is unchanged;
SHA-256 `c34b5f4b3c41807cf19ae95b86c13ecd2e3375906c2c313afd88cf3821788034`.
The latest clarification requires hidden Immersive UI after leaving Details,
rather than restoring its previous visible state.

## Motion, chrome and physical insets

Vertical mode gestures track the finger directly, including holds and reversals.
Only release commits and snaps. A snap uses an explicit short duration so a small
remaining distance does not collapse it into one or two frames. A new downward
pull at the top of Details returns to Immersive, including when the metadata are
shorter than the viewport. Beginning below the top remains ordinary scrolling.

A one-pointer observer avoids claiming the image's scale gesture arena. A second
pointer cancels the presentation drag synchronously, preserving vertical pinch
and pan. Root scroll notifications authorize the Details pull, preserving nested
controls and selection. Stretch overscroll is disabled on this surface.

The bottom toolbar slides downward instead of fading. It is fully hidden halfway
through Immersive-to-Details travel; this follows actual gesture progress, not a
timer. Any visible return uses the final half of travel. Ordinary overlay toggles
slide top and bottom chrome from opposite edges with the same curve. Info fades
with both overlay visibility and mode progress. Leaving Details hides Immersive
UI by default; the user can explicitly reveal it with a tap.

Inherited navigation padding is bounded by actual FlutterView system insets. The
app-navigation shell can briefly supply an extra navigation-bar obstruction when
the Viewer opens; this must not become a permanently cached Android inset. Hidden
system bars retain only the last physical inset, and consumed safe edges remain
consumed. Video controls do not add the bottom inset twice. Video quick actions
use the same opaque surface as images, in portrait and landscape.

Details media/content remain clipped between physical system bars. Immersive
media remain edge-to-edge while controls respect safe areas. Details uses an
adaptive contain-fit block, at most 60% usable height, followed by existing
metadata/actions. Info is absent there; Back exits, and tapping Details media
returns to Immersive with its saved transform.

## Intermittent video playback

The owner uses Auto, has app/system reduced motion disabled, and reports that
most playback succeeds. The investigation established these reproducible paths:

- Reactivating a retained adjacent BooruVideo reinitialized its native source.
  Its new native controller could lose looping, and its startup depended on the
  order of pause/play/initialization completion. A ready or initializing player
  is now retained when its occurrence becomes current again.
- Retention applies only while the source configuration is current. A URL,
  header or engine change while inactive still reloads on reactivation; obsolete
  preparation is cancelled and cannot register a late initialized source.
- A real URL switch reapplies looping after source replacement.
- Player registration honors current playback intent even when the request
  already reached a previous controller, preventing a replacement from staying
  paused while the toolbar retains the playback request.

These are controlled lifecycle regressions, not proof of reproducing every
sporadic symptom on Android. Native codec behavior, real Auto-engine selection,
network delivery and visible loop continuity still need owner device acceptance.

## Verification

The complete local suite passed on the exact runtime/test candidate above.
Subsequent handoff updates change documentation only; runtime, tests,
dependencies and generated runtime output remain unchanged.

- `./scripts/run_regression_tests.sh`, detected concurrency 6: exit 0;
  7,000 application tests, 1,691 tests across all 13 package/CLI roots, both
  repository shell suites and 76 Python tooling tests passed. GoRouter retains
  two existing skipped shell-route configuration tests; no new skips were added.
- Affected Viewer/video/navigation suite: 209 passed. This includes actual media
  snap frames in both directions, short Details pullback, synthetic 80px app
  obstruction vs real 24px system inset, toolbar motion/Info fading, opaque video
  surfaces, retained player/loop behavior, and replacement playback intent.
- Final mode-initialization check: all 43 mode tests passed. The subsequent
  deferred-source refinement passed all 44 video/navigation tests, including
  required reload and late-initialization cancellation.
- `fvm dart analyze` across all 38 changed Dart files: exit 0; zero errors or
  warnings, 25 existing informational findings, including the expanded video
  source/test scope. No new informational finding remains.
- `fvm dart format --output=none --set-exit-if-changed` on those files: exit 0,
  zero changes. `git diff --check`: passed.

The initial focused reproduction failed five cases for toolbar translation,
half-travel completion, UI reset and video reactivation/source-switch looping.
An additional real-media test exposed and then qualified short-Details pullback.
Earlier failed or interrupted runs are not complete-regression evidence.

## Visual evidence and owner acceptance

The opt-in real Flutter capture passed with strict hit testing and normal motion
enabled. Its 15 frames comprise the 12 reviewed square 414x915, portrait 320x800
at 2x text and panorama 844x390 states, plus early drag, late drag and mid-snap.
The exact-final recapture produced 15 byte-identical files compared with the
inspected frames. The 12 settled frames also match the prior baseline; the
three new inspected frames show footer translation, Info fading and a visible
snap remainder. Physical 24px top/bottom test-view insets are used. Synthetic
provider/media fixtures contain no credentials.

```bash
fvm flutter test --no-pub --concurrency=6 \
  --dart-define=VIEWER_CAPTURE_DIR=<durable-workspace-directory> \
  test/core/posts/details/mixed_post_details_page_test.dart \
  --plain-name 'capture approved shared Viewer modes'
```

The owner reported that `7a6e5cf6` works and approved integration once the last
source-lifecycle changes were finished. The exact manual scenario matrix was not
reported. Host/widget checks do not independently establish Android frame timing,
native decoding, authenticated live-service behavior or every intermittent loop
condition. No additional owner approval is required for this authorized merge.
The following cases remain useful when checking later changes to this Viewer:

1. Release a vertical mode drag near either endpoint: a visible snap should
   complete the remaining travel. Try a short Details page too.
2. Check the bottom edge for an extra strip, regular top/bottom overlay slides,
   footer disappearance by half travel, Info fading, and hidden UI after Details.
   Verify opaque video quick actions in both orientations.
3. With Auto, open an MP4 and WebM, allow multiple loops, swipe to an image and
   back repeatedly, then repeat in Details and with Immersive UI shown/hidden.
   These exercise the intermittent playback path described by the owner.
