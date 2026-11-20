# #176 Group viewer rebase review

The local `feature/176-group-viewer-design` branch was rebased from
`ae414e469` onto `develop` at `04fd511a8`. All 54 feature commits were
replayed. The tested runtime and test revision is `91c7e7a3b`.

## Rebase fixes

- Kept the prepared Group page and settled-display callback while restoring
  #176's Timeline tile drill-in, Single controls, and Back behavior. Kept
  Safebooru's unavailable-members message and the guard that lets old Pool
  covers acquire missing visibility facts.
- Connected the shared membership controller to the prepared first-page cache
  for the same reference, reader, order, limit, and refresh revision. A regression
  asserts one member read per Group while swiping across a plain Post and
  switching between Timeline and Single.
- Kept pending continuation results out of a gallery after the viewer swipes
  away. A controlled test holds the second batch until the gallery is inactive.
- Preserved the original Markdown line breaks using explicit break markers.

## Verification

`./scripts/run_regression_tests.sh` exited 0 with six workers. It passed
7,951 application tests, 1,730 package and CLI tests across 13 suites, both
shell tooling suites, and all 76 Python tooling tests. Two package tests were
skipped. Analysis of the 65 changed Dart files reported zero errors, zero
warnings, and 158 informational findings. Formatting and
`git diff develop --check` passed.

Logs and the Git range comparison are in
`.worktrees/_artifacts/176-develop-rebase/` under the primary checkout.
Verification for this rebase used the Flutter host runner. Device and live
service review remain open on this revision.

## Final review walkthrough

1. Open a multi-page Pixiv Work in Single. Switch to Timeline, scroll down,
   open a tile, and go Back. Expect the same Timeline scroll position and
   distinct Page and Work bookmark buttons in Single. A single-image Work
   should stay in Single.
2. Open a Danbooru Series or Related group. Change the order in Single and
   check that the current image stays visible while the new order loads.
   When the change applies, Single should open the first item in that order.
3. Swipe from a Group through an ordinary Post into another Group. Check
   that the active mode carries across and the next Group is already laid out
   as you land. If the starting item is a playing video, it should pause as the
   first swipe starts.
