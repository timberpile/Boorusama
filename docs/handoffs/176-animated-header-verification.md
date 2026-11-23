# #176 animated viewer header and image counter

This records an earlier #176 revision. See the
[canvas and ordering follow-up](176-canvas-order-verification.md) for canvas placement and timing.

Runtime and tests are in `8cf37d132` on `feature/176-group-viewer-design`.
The local base is `403cc778b`. The remote task branch at `268bc7a89` has
two additional documentation commits. The tested runtime base is identical.

## Behavior

- The shared Viewer overlay uses centered 24dp glyphs with transparent
  resting surfaces and 48dp touch targets. Sort, View and Info have 4dp
  between their touch targets in Immersive. Single Sort uses the existing
  Kurumi menu and announces the localized current order. Timeline View uses
  its neighbors' transparent action style.
- Info fades and the space for its control and gutter contracts by 52dp
  over the existing presentation progress. Sort and View move into that
  space and reverse with the same drag or snap. Info drops out of pointer,
  focus, and semantics handling during the transition.
- The counter follows the current member's visible media rectangle with
  an 8dp inset. It clips to the safe viewport above the bottom preview,
  keeps its screen size during zoom, and scrolls with the media in Detailed.
  The three-second lifetime and 180ms fade remain independent of header
  layout. Missing member geometry suppresses the hint until it is known.

## Evidence

The pre-change regressions failed on the uneven header gap, missing
intermediate reflow, and screen-level counter position. The log is
`red-regressions.log` in the ignored artifact directory
`.worktrees/_artifacts/176-animated-header/` within the task worktree.

- The affected Flutter run passed 665 tests across `test/core/posts/details` and
  `test/core/posts/details_pageview` directories plus the Pool bookmark,
  Booru browsing, and keyboard-navigation application flows. It ran with
  `fvm flutter test --no-pub --concurrency=6 --reporter expanded`.
  See `affected-3.log`. The final test-only additions were checked in the
  focused run below.
- The final focused run passed 14 cases including the counter zoom and
  scrolling tests, the Related header at 320dp with normal and doubled
  text in light and dark themes, and the Pixiv screenshot fixture.
  See `focused-final.log`. The real decoded Pixiv Page regressions compare
  the label corner against the painted image corner in Detailed.
- Formatting and `git diff --check` passed. The scoped analyzer ran with
  `--no-fatal-infos` and reported zero errors, zero warnings, and
  34 informational findings. See `analyze-verified.log`.
- Flutter fixture captures at 320dp with doubled text, 414dp with normal
  text, and 844×390 show the counter on the image before expiry and gone
  after expiry. Captures are under `widget-captures/` in the artifact
  directory. The landscape capture shows the counter above the bottom
  preview while the image extends behind it.

ADB device discovery timed out and logged a conflict on its listening port.
Maestro device discovery independently timed out. Android captures, native
visual acceptance, and on-device video checks are pending. The full
integration suite was outside this local follow-up. #176 stays open with
its current `blocked` label.
