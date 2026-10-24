# Issue #85 — Local verification and integration handoff

Issue: https://github.com/timberpile/Boorusama/issues/85  
Branch: `bug/85-bottom-navigation-feed-exit`  
Base `develop`: `6875e0ce778aecfb2b83780c2185ce9273a9b2cc`  
Source and regression-test commit: `ad4724a8ec7e3159b0e119499a8f2afa63945fd5`  
Current work: branch tip (includes this documentation-only follow-up).

## Report and cause

User-reported reproduction: open a Following feed, scroll until the app bottom navigation slides away, then navigate back. The previous non-feed screen still has the bar translated off-screen until another timeline is scrolled upward. Device reproduction is not yet performed.

`NavigationChromeController.barHiddenFraction` is shared by the shell. `NavigationScrollBoundary` updates it only in response to user scroll. `NavigationController.selectDestination` already resets it on a primary-destination change, but pushing/popping pages within the same destination does not select a new destination. A non-scrollable parent therefore inherits the feed's hidden chrome.

## Scoped fix

- The production shell now passes its current branch route to `NavigationChromeRouteSync`, driven by the existing `DestinationRouteObserver.topRoute` notification.
- The sync widget remembers the last non-popup route and calls `navigationChromeProvider.notifier.show()` when the active page changes. This restores the bar without changing the feed's scroll offset, resizing the grid, or modifying the scroll gesture logic.
- Popup routes do not count as page changes. Post-viewer entry/exit is exempt, preserving the existing hidden state across viewer lifecycle transitions.
- The show call is deferred until after the frame to avoid provider writes during Navigator builds, with a mounted/current-route guard against superseded transitions.
- `test/core/navigation/navigation_chrome_route_sync_test.dart` covers returning to an overview/editor from a hidden feed, popup/viewer preservation, and continued hide/reveal by scrolling. The regression is checked in, **not executed**.

Source review and GitHub branch/diff inspection completed. **No Dart formatting, static analyzer, Flutter tests, full regression run, APK/device reproduction, or Maestro checks have been executed** in this remote environment (GitHub connection only; no Flutter/Dart/FVM SDK or runnable checkout). Do not treat the branch as integration-ready yet.

## Local verification

1. Read current `AGENTS.md`, `docs/development_workflow.md`, `docs/issue_workflow.md`, and `docs/android_emulator.md`. Fetch the issue branch and inspect `python3 scripts/agent_worktree.py status 85-bottom-navigation-feed-exit --branch bug/85-bottom-navigation-feed-exit` before creating or attaching its own isolated worktree. Preserve all unrelated work and never reset the primary checkout.
2. Bootstrap dependencies and missing generated outputs as required by the checkout, using pinned FVM. Run `fvm dart format` on the two changed Dart files and the new test, inspect the format diff, and run `git diff --check`. Analyze the affected navigation files.
3. Run the focused widget regression `fvm flutter test --no-pub test/core/navigation/navigation_chrome_route_sync_test.dart` and the existing `test/core/navigation` suite plus `test/application/navigation_scroll_flow_test.dart`, `test/application/navigation_redesign_flow_test.dart`, and `test/application/navigation_viewer_lifecycle_test.dart`. Use the physical-core concurrency helper for multi-file suites. Resolve any analyzer/test issues on this same branch, commit and rerun. Consider adding an end-to-end widget test through the real production router to verify observer wiring when practical.
4. Reproduce on Android via Maestro using an existing populated Following Topic/Folder feed with enough posts to scroll. Acquire/renew/release the **exclusive emulator lease** as documented, target an explicit serial, and avoid touching other sessions. Open feed, scroll downward until the bar fully hides, then use Back. The Following overview/management screen must immediately reveal the bottom bar without scrolling elsewhere.
5. Repeat with folder feeds and other child pages reachable from Browse/Following/Bookmarks where feasible. Verify that ordinary feeds/grids still hide on downward gestures and reveal on upward gestures. Open and close a post viewer from a hidden feed and confirm its previous scroll-chrome state is preserved. Check transient dialogs/popups, tab changes, the auto-hide setting, keyboard/selection coverage, and a narrow/enlarged-text viewport. Look for stale post-frame resets during rapid navigation and animations.
6. Inspect the entire branch diff and changed-route policy against current `develop`. If a real-device or integration test exposes a state/lifecycle gap, fix the cause on this branch, rerun targeted checks, and document any remaining limitations. Do not claim a passing check without its actual command/result and commit SHA.

## Conditional integration and cleanup

The user authorized the local agent to **merge if verification passes**. Before integrating, reconcile with current `origin/develop` and execute the entire `./scripts/run_regression_tests.sh` on the **final combined integration candidate**, as required by `AGENTS.md`. A targeted pass or CI alone does not replace this gate.

Once accepted, integrate as one descriptive Conventional Commit on `develop` **including `#85` in its subject**, publish to `origin/develop`, verify publication, close issue #85 as completed and remove workflow-status labels, then delete this completed task's remote branch and disposable local worktree/branch in accordance with the workflow. No PR is requested. If verification fails, is incomplete, or the combined candidate changes, **do not merge**; keep the issue open, update the handoff/evidence and address the blocker.

Record the final checked SHA, test commands/results/skips, Maestro scenario/evidence, merge/publication evidence, and any remaining risks. Do not include credentials or local paths as shared evidence.
