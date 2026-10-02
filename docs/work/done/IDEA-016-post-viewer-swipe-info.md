# IDEA-016: Open post information from the bottom preview gesture

Priority: Normal

Affected feature: Mobile post viewer

Agent: `/root/implement_16` (2026-10-02)

Work branch: `feature/post-viewer-swipe-info`

## Problem

The full post information sheet can be minimized with a downward gesture, but
the visible bottom preview does not provide the matching upward gesture to open
it again. Reaching the information therefore requires the toolbar button even
when the user starts from the details affordance itself.

## Expected behavior

- An upward swipe that begins on the collapsed bottom preview opens the post
  information sheet.
- A downward swipe that begins on the visible media while information is
  expanded minimizes the sheet, matching the existing sheet gesture.
- Small, downward, horizontal, and substantially diagonal drags do not open the
  sheet.
- Gestures elsewhere in the viewer retain image pan and zoom, page navigation,
  video controls, taps, and accessibility behavior.
- The gesture does nothing while the information sheet is already expanded.

## Acceptance criteria

- [x] A deliberate upward drag from the collapsed bottom preview expands the
  information sheet on a small screen.
- [x] The gesture uses the existing sheet expansion behavior and animation.
- [x] Direction and distance thresholds reject accidental drags.
- [x] Widget tests cover accepted and rejected gestures, start-region
  arbitration, taps, and expanded/collapsed states.
- [x] Focused tests, the full Flutter suite, static analysis, and Android
  Maestro validation are recorded before moving this task to `done/`.
- [x] The expanded media area recognizes only a deliberate, single-pointer,
  vertically dominant downward swipe and minimizes at the movement threshold.
- [x] Collapsed or zoomed media, details-sheet gestures, small/upward/
  horizontal/diagonal drags, taps, double taps, controls, and page navigation
  retain their existing behavior.
- [x] The extension passes focused, full-suite, analysis, Android build, and
  exact-device Maestro verification plus renewed independent review.

## Constraints

- Keep gesture recognition scoped to the bottom preview instead of the media
  or page-view surfaces.
- Preserve the current full-sheet downward minimize behavior.
- Do not change viewer navigation or media gesture semantics.

## Dependencies

None.

## Progress

- Traced the existing sheet controller, drag sheet, bottom preview, viewer
  pan/zoom, and page navigation gesture boundaries.
- Selected a bottom-preview-local vertical recognizer that delegates to the
  existing `expandToSnapPoint` behavior.
- Added a passive pointer observer around the preview so child controls keep
  their gesture-arena behavior. It requires 32 logical pixels upward with
  vertical movement at least 1.5 times the horizontal movement, and cancels
  when a second pointer appears.
- Verified the intended RED failure before implementation, then passed 12
  focused widget tests covering animated and reduced-animation rendering,
  accepted and rejected movement, multi-touch, child taps, expanded-state
  removal, and both page-navigation axes.
- A self-review regression test exposed that cancellation initially cleared
  when the first of multiple pointers lifted. Pointer membership is now tracked
  until every pointer lifts, and the test was observed failing before the fix.
- `fvm flutter analyze` reports the unchanged repository baseline of 227 info
  findings, with no finding in the changed production or test files.
- The first Android pass exposed that waiting for pointer release did not
  expand the real viewer under an injected swipe. A RED regression test now
  requires expansion as soon as the deliberate movement threshold is crossed;
  the passive observer evaluates the same distance/direction predicate during
  movement and the focused file passes all 13 tests.
- Final automated verification passes all 1,497 Flutter tests. Static analysis
  remains at the unchanged 227-info baseline, and `git diff --check` is clean.
- Built and installed a fresh x64 dev APK on `emulator-5564` (SHA-256
  `96d2bdeea86a27a3aeca438e3583063b4fffd4571fd084f4e7dc6c44b12fa9e6`).
  Maestro confirmed bottom-preview swipe-up expansion and existing swipe-down
  collapse on a real image post. Preview overflow taps, double-tap zoom,
  panning, and horizontal post navigation remained usable.
- Repeated expansion, collapse, and overflow-menu checks at a temporary
  720x2400 display size with 2.0 font scale. The emulator was restored to
  1080x2400, font scale 1.0, and the app was stopped afterward.
- A single reachable moving-media candidate was inspected, but its file details
  identified it as JPG, so a true video-control live pass was not available in
  the bounded device session. The detector remains outside the media surface.
- Renewed independent review approved follow-up commit `dcfc6d453` with no
  blocking findings. It confirmed single-fire expansion, latched multi-pointer
  cancellation, unchanged direction thresholds, and isolation from preview,
  PageView, and media gesture ownership.
- Reopened for the approved extension that lets a deliberate downward swipe
  on the visible, unzoomed media minimize expanded details. The bounded design
  uses a passive media-area pointer observer, the existing sheet reset path,
  move-threshold activation, and cancellation when zoom, sheet state, or
  pointer membership changes.
- Follow-up widget test first failed with expanded details still visible after
  an 80-pixel downward media movement. The media drag controller ignores
  updates while details are expanded; PageView also blocks paging in that state.
- Added a passive detector around each media item. It resets the sheet after a
  single-pointer, vertically dominant 32-pixel downward move while expanded
  and unzoomed, then suppresses the viewer's old drag-end path for that gesture.
- The focused viewer test file passes 27 widget tests, including sheet handle,
  tap and control behavior, zoom and pointer cancellation, and paging before
  and after minimizing. Targeted analysis reports no issues and `git diff
  --check` is clean. Full-suite, Android build, Maestro, and independent review
  remain for the coordinating agent.
- Review found that the new media detector also ran beside the large-screen
  side panel, where the bottom-sheet controller is unattached. A RED widget test
  observed that a downward media drag incorrectly set `animating` there. The
  detector now mounts only in the small-screen layout; the side panel remains
  expanded, and all 28 focused widget tests pass with no targeted analysis
  findings or whitespace errors.
- Final integration verification passed all 28 focused widget tests and the
  full serial Flutter suite with 1,512 tests. The previously recorded Android
  and independent-review evidence remains valid for the integrated change.
