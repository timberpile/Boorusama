# Connected Explore navigation panel (#175)

Continue `bug/175-pixiv-navigation-autohide`, synchronized with origin/develop
`e2468e50cd9dbd1a2a9fce0ad4fab47673cfb8e1`. Keep the existing native scroll
boundary and the integrated #169/#174 refresh, identity and restoration behavior.
This supersedes the earlier handoff's missing-scroll-boundary-only scope.

## Architecture

Explore's outer SafeArea consumed the full synthetic bottom navigation inset
until hiding completed. The navigation Material itself already moved with its
buttons; the leftover band was the uncovered page surface. The date stepper
was independently pinned outside the grid.

`NavigationOverlayInsetsScope` now owns the single rendered animation. Navigation,
the route-owned footer and overlay insets consume its frame geometry. Normal
scroll motion is immediate; snap/reversal motion preserves the existing duration,
and viewer progress uses the existing route-progress composition. No Pixiv widget
duplicates animation policy. Root-overlay toast notifications remain coalesced
after layout to avoid marking unrelated overlays dirty during a build.

The navigation height N includes the system inset, D is the attached footer
height, and T=N+D supplies scroll travel. Both surfaces translate by T*H using
the shared rendered hidden fraction H. Footer extent changes retarget the same
driver from current rendered geometry. The navigation still occupies N pixels;
the footer is positioned immediately above it.

`NavigationAttachedFooter` registers only transient geometry and destination
ownership. Existing route observers distinguish covering popups/viewers from
ordinary pages; inactive retained destinations release their contribution.
Explore owns feed/date state. A retiring immutable date snapshot remains mounted
only while its extent collapses. Wide layouts pin the footer and preserve the
native grid/controller. No settings or data formats change.

Explore opts out of synthetic bottom padding. A general `ViewportBottomInsets`
scope gives NativeContentGrid scroll-end clearance and live scroll-to-top
obstruction without resizing the viewport. Other destinations keep their prior
page-padding behavior. The footer uses the navigation's opaque semantic surface;
hidden controls are excluded from input, focus and semantics.

A new drag interrupting a snap now seeds its fraction from the shared rendered
geometry through NavigationScrollBoundary. Continuing drags use their immediate
scroll state. This is a read of the existing renderer, not another animation
source; controller-only callers retain their existing fallback. The regression
reproduced a 30 dp content drag moving navigation backwards before this correction.

## Verification

- Affected-source formatting passed.
- Affected-source/test analysis: zero errors, zero warnings, 12 informational
  findings. No unrelated informational cleanup was included.
- Navigation/viewer/selection/event-forwarding consumer run: 141 passed.
- Final real-shell and overlay-inset checks: 4 passed. They include 320 dp,
  enlarged text, partial motion/reversal, actual dragging, feed/destination
  changes, date-picker dismissal, viewer progress, keyboard, selection, reduced
  motion, final rows, pagination actions and wide-layout controller retention.
- Legacy assertions about AnimatedSlide were updated to read the actual rendered
  transform; mounting identity and input guards remain asserted.
- Interrupted-snap correction: changed-file analysis found no issues, and all
  10 controller, boundary and actual-shell checks passed at normal/enlarged text.
- `git diff --check`: passed.

Full regression qualification is recorded in a subsequent documentation-only
update after checking the committed runtime candidate. Earlier compilation and
fixture-selector failures are not passes; durable logs retain those attempts.
The initial full run was interrupted after the new gesture regression exposed
the snap-target jump. It is not counted as a complete pass; the final full run
uses the corrected committed candidate.

Durable logs: `.worktrees/_artifacts/146-175-finalize-20261118/`.
No Android/emulator/Maestro, APK or authenticated API checks were performed by
the agent. The owner subsequently accepted #175 and authorized integration.
#96 is unchanged. #146 remains a separate, unfinished task.

## Complete final regression

Checked candidate: `56427182dad34760f9063de244020b1dfc258ac8`, including the
interrupted-drag correction. Command: `./scripts/run_regression_tests.sh` using
six workers from `scripts/physical_core_count.py`.

- Application: **7,646 passed**.
- All 13 package/CLI suites: **1,722 passed**, with two existing go_router skips.
- Both repository shell suites passed.
- Python repository tooling: **76 passed**.
- `REGRESSION_EXIT=0`.

The tree was clean throughout this final run. This verification update changes
only this handoff; runtime, tests, dependencies and tooling remain identical to
the checked candidate. No new device/live acceptance is claimed. #146 remains a
separate branch, so a future combined integration candidate needs its own full
qualification. At the time of that regression run, neither issue had been merged
or closed, and neither branch had been pushed or deleted.

## Accepted integration

The owner marked #175 ready to merge. Refreshed origin/develop remained at
`e2468e50cd9dbd1a2a9fce0ad4fab47673cfb8e1`. The squash candidate has the same
runtime, tests, dependencies and tooling as the fully checked commit above;
only this handoff differs. The complete pass is therefore reused under the
repository integration policy. The accepted change is published independently
of #146. The primary checkout and #96 are preserved.
