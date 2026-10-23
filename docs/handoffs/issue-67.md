# Issue #67 — Local acceptance handoff

Branch: `bug/67-view-options-spacing`  
Base: `565a504cf714fa9de19053b22f5f761561a35f54`  
Issue: https://github.com/timberpile/Boorusama/issues/67

## Cause and implementation

`AppNavigationShell` deliberately reserves a stable bottom-navigation extent in the destination's MediaQuery so hiding chrome does not move the timeline. Nested popup routes inherited that synthetic padding even when the bar was hidden.

The page MediaQuery remains unchanged. A separate `NavigationOverlayInsetsScope` publishes the actual animated bar overlap, bounded below by real system padding. It shares the bar's target/duration policy, follows partial drag and snap animation, and removes app overlap when keyboard/viewer coverage makes it irrelevant. System view padding and keyboard view insets are not discarded.

Kurumi's generic overlay MediaQuery boundary applies only inside a hosted Navigator and changes only bottom padding/view padding. The common app sheet used by View Options, raw Material-sheet wrapper, adaptive sheet/bar sheet, adaptive dialog, and side-panel boundaries use it. Root-Navigator overlays outside the navigation scope retain their normal system MediaQuery. No View Options-specific padding workaround or timeline resizing was added.

## Source audit and coverage

Inspected the View Options and Edit Blacklist callers in `post_grid_config_icon_button.dart`, navigation shell/scroll scope, and shared Kurumi sheet/adaptive/dialog entry points. The app-modal fix covers other users of that same API. Standalone root dialogs already avoid the nested synthetic navigation inset. The new scoped boundary is available for any custom nested overlay found during local acceptance; do not subtract a hardcoded 64 pixels or erase system gesture/keyboard padding.

Tests: `packages/kurumi/test/overlay_insets_test.dart` preserves non-bottom data and root-overlay behavior; `test/core/navigation/navigation_overlay_insets_test.dart` covers visible/partial/hidden overlap, intermediate animation, unchanged page padding, and keyboard insets.

## Verification status

**Formatting, analysis, Flutter tests, and device checks have not run.** This environment has no FVM/Flutter SDK and cannot clone GitHub. Source review is not runtime acceptance, and no integration-ready claim is made.

## Local acceptance

1. Fetch the branch into an isolated worktree and read current `AGENTS.md`. Bootstrap dependencies/missing generated files normally.
2. Format changed Dart files. Run all `packages/kurumi` tests and application `test/core/navigation` tests with the physical-core concurrency helper. Analyze affected code. Add a rendered View Options/modal-route test using existing navigation fixtures, especially while a sheet remains open during a bar snap.
3. Run `./scripts/run_regression_tests.sh` for this shared infrastructure change and again on any changed combined develop integration candidate.
4. On a narrow Android view, compare View Options with the bar fully visible, partially hidden, fully hidden, and snapping. The sheet must reserve only the live overlap while the timeline retains the same position. Check gesture navigation, enlarged text, keyboard open/closed, selection mode, viewer entry/return, wide layout, and reduced motion.
5. Exercise Edit Blacklist and representative app-modal, adaptive/bar, side-panel, and root-dialog callers. Verify the third-party bar-sheet route does not independently reintroduce a captured navigation inset outside the corrected content boundary; fix its shared wrapper if a rendered regression exposes one. Preserve real insets and root-Navigator behavior.
6. Acquire the documented emulator lease before device work. Review the full diff, fix small defects on this branch, rerun checks, and record exact commands/results, skips, and the checked commit.

Independent of the other quick-win branches. No merge, PR, issue closure, or deletion is authorized. A later approved integration subject must include `#67`; use `Refs #67` until acceptance passes.

## Local acceptance evidence (2026-10-23)

Checked runtime/test commit: `2e94b5d26cb9b96007bcb22c7998fca42d2d3194`. Fresh-worktree FVM dependencies and missing generated output were initialized through `./gen.sh`; generated files remain ignored. Formatted changed Dart files and passed `git diff --check`.

- Added real overlay-route coverage in `packages/kurumi/test/overlay_routes_test.dart`: app modal, raw Material, adaptive/bar, side-panel and root-dialog boundaries while the live inset changes without closing the route. **6 passed** with `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/overlay_routes_test.dart` from that package.
- Added an application flow opening the actual View Options `PostGridActionSheet` at 320 pixels, verifying changing overlap during hide/snap and an unchanged grid rectangle. `fvm flutter test --no-pub --reporter=expanded --concurrency=6 test/application/view_options_insets_test.dart`: **1 passed**.
- Inspected the third-party bar-sheet route: its outer wrapper handles top safe-area removal and does not independently reintroduce the bottom navigation inset. Rendered routes preserve root-Navigator behavior and real system padding.
- Affected navigation/Kurumi Dart analysis passed with informational lints, no errors or warnings.
- `./scripts/run_regression_tests.sh`: **passed, exit 0** on this committed runtime/test candidate. Application **4462 passed**; all **13 package/CLI suites passed**, including Kurumi **141 passed**. Existing go_router skips: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. Both shell tooling suites passed; Python tooling **72 passed**. Log: `/tmp/boorusama-acceptance/67-view-options-spacing-full-regression.log`.

Flutter 3.47.2 / Dart 3.13.2 and six physical-core workers were used with an isolated pinned SDK copy. The Android live UI matrix remains pending at this point, including gesture navigation, selection/viewer coverage, enlarged text, keyboard, wide layout and reduced motion. No merge, push, PR, issue closure, deletion, or combined-develop qualification occurred.

### Android follow-up (2026-10-23)

Initialized native plugin metadata with `fvm flutter pub get --offline`, then built with `fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub`: **passed**. Installed under an exclusive lease with `adb -s emulator-5554 install -r`, preserving data. APK SHA-256: `50f8311287803eea6a21a1c4c4ca5306b62398816aa11e95e1ed1a6c0c1b577a`.

Maestro opened actual View Options with the navigation bar visible, then scrolled until it was fully hidden and reopened the sheet. The hidden-bar sheet uses the extra space rather than retaining the navigation gap; background tiles stay in place. Also kept the sheet open while applying 2x system text and opened it successfully in an 800 dp wide emulator viewport. Restored portrait, the original physical-size setting and normal system text afterward. Screenshots: `/tmp/boorusama-acceptance/67-{visible-grid,visible-view-options,hidden-grid,hidden-view-options,view-options-2x,wide-grid-rendered,wide-view-options}.png`.

The 2x screenshot exposes clipping/collision in the existing View Options label/value rows. Their source in `post_grid_config_icon_button.dart` is unchanged from the branch base; the inset patch does not redesign that row layout. This remains a visual acceptance limitation. Edit Blacklist was absent from this profile's grid menu, so no live blacklist-modal check is claimed. Partial/snap updates, root/dialog/adaptive/bar/side boundaries and keyboard inset preservation have the rendered application/package coverage above; selection/viewer/reduced-motion and full device keyboard/partial-snap matrices remain unverified. No merge, push, closure or branch deletion occurred.

### Pool segmented-control overflow follow-up (2026-10-23)

The reported PoolOrderToggle needs three 120-pixel segments plus 8 pixels of inner padding (368 total), but the actual parent supplies 363.4 pixels. Reproduced this exact overflow and the narrower 320-pixel case before changing the shared Kurumi control. Segments now flex within available width, grow vertically for enlarged/wrapped labels, and measure their actual constrained widths for the selection indicator. Ample-width controls retain their requested widths.

Verification on the final runtime/test tree committed with this handoff:

- New Kurumi layout regressions cover 320/363.4/600-pixel widths at 1x/2x text, selection callbacks and indicator bounds. Four narrow cases failed before the fix. Complete Kurumi suite: **147 passed**.
- The actual PoolOrderToggle at 363.4 pixels and 1x/2x text, existing View Options inset test and navigation tests: **65 passed**.
- Focused analysis of the changed Dart files: **No issues found**. Formatting and `git diff --check` passed.
- `./scripts/run_regression_tests.sh`: **exit 0**; application **4464 passed**, all 13 package/CLI suites passed (Kurumi **147**), both shell tooling suites passed, Python tooling **72 passed**. Two existing go_router skips remain. Logs: `/tmp/boorusama-67-followup/{kurumi,app,analyze,full}.log`. Flutter 3.47.2 / Dart 3.13.2, six workers.

No new device run was performed for this follow-up. The exact supplied pool overflow is covered by rendered regressions; the additional ListTile/semantics assertions were not independently reproduced and are not separately claimed fixed. Earlier device/large-text limitations above remain. No integration or publication occurred.


## Authorized combined integration verification (2026-10-23)

The user's subsequent instruction authorizes integrating the eight reviewed issues if verification passes, superseding earlier local-only statements for this operation. #52, #71 and unrelated bookmark-freeze work remain excluded.

Starting branch head: `cacb65b503726ad2471d60f00237d17908d76b03`. Combined runtime/test candidate: `e9b0b7916bd95e3ca134dd7fb797b81e43007503`, built on develop `afc04f4933aa0e442b9f80b2662f0fc5ad277379`. Subsequent handoff edits are documentation only.

Preserved live overlay obstruction, stable page layout, real keyboard/safe-area insets, root-Navigator isolation and the shared modal/adaptive/bar/side wrappers. The reported pool RenderFlex overflow is covered by the real PoolOrderToggle and Kurumi segmented-control fixtures, including the supplied constrained width and enlarged text. All pass in the combined suite.

Maestro reopened View Options with navigation fully visible and fully hidden; screenshots show the live gap disappears when the bar is hidden. No View Options setting changed. Mid-animation/partial overlap, open-route inset updates, selection/viewer/reduced motion, root/dialog/side/bar and keyboard behavior have executed application/package coverage. The prior 2x View Options label/value collision is in unchanged baseline rows, as identified by the review; it is not reclassified as a regression introduced by this change.

The required `./scripts/run_regression_tests.sh` completed with **exit 0**, using six physical-core workers: **4,734 application tests**, all **13 package/CLI suites** (Kurumi **161 passed**), both shell tooling suites, and **72 Python tooling tests**. The two existing go_router skips remain. The first combined run exposed three obsolete domain-label expectations in #48's profile-switch fixtures; after reconciling with #47's requested labels, the entire unchanged final candidate was rerun successfully. No failing/incomplete run is counted as a pass.

Full command/results, APK correspondence, cross-branch reconciliation and limits are consolidated in [issue-48.md](issue-48.md#combined-verification-evidence-and-limits). This entry supersedes earlier pending combined-candidate qualification, without relabeling historical device checks as current evidence.

Cleanup verification: the created bookmark folder/group and Topic are absent, the original three profiles remain, system font scale is restored to 1.0, the original viewport/orientation were not changed, and the exact emulator lease was released. The dev APK/data remain installed; no app-data reset or phone operation occurred.
