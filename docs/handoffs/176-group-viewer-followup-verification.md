# #176 group viewer follow-up verification

This records an earlier #176 revision. See the
[canvas and ordering follow-up](176-canvas-order-verification.md) for canvas placement and transactional sorting.

Local runtime and tests: `40cce183c` on
`feature/176-group-viewer-design`, following `2a81fe9e7`.
This follow-up implements the accepted control and repeat-entry corrections.
#176 remains open for owner acceptance. Publication and develop integration
remain separately authorized actions.

## Result

- Related Timeline uses the existing localized **Related Posts** string in the
  navigation app bar's title slot.
- Back, Details and view controls paint 40dp circles with at least 48dp touch
  targets. Single's sort selector uses the same Kurumi overlay colors, a 40dp
  painted height, a 48dp touch target and a 12dp corner radius.
- Timeline member entry opens Immersive with both toolbar rows shown or hidden
  according to the captured source profile's enabled override or global viewer
  setting. Explicit view switching retains Detailed restoration.
- Repeated member entry remains swipeable after drag-down returns to Timeline.
  Mode transitions now have owners; replacing or disposing a presentation
  releases its animation and dismissal gates. Stale completions cannot release
  a newer transition. Route-offset restoration distinguishes a retained route
  from a real reverse pop. Independent zoom and selection locks remain intact.

The regression was reproduced before changing production code: the normal-motion
route retained `pager.animating == true` after drag-down interception; reduced
motion did not. Timeline entry also failed the complete toolbar visibility
assertions. See `reproduction-3.log` in the artifact directory below.

The optional Kurumi compact-circle implementation uses a padded TextButton so
painted size and touch bounds work under both Material 2 and Material 3. Existing
callers retain their original implementation. A styled popup trigger reuses
Kurumi's menu, semantics and keyboard-focus behavior.

## Automated evidence

Commands ran in `.worktrees/176-group-viewer-design` using FVM and six detected
physical cores. Durable logs, native flows and screenshots are in the ignored
`.worktrees/_artifacts/176-group-viewer-followup/` directory within that worktree.

- Seventeen added tests cover the real Related route with normal/reduced motion,
  three drill-in visits, duplicate Post IDs with separate occurrence keys,
  cancelled dismissal and reverse swiping; the global/profile Show/Hide matrix;
  320dp header geometry at normal/doubled text in light/dark themes; Material
  2/3 padded edge taps; and styled-menu keyboard/focus behavior.
- `fvm flutter test --no-pub test/core/posts/details/mixed_post_details_page_test.dart --name 'Related repeated|Related Timeline tile|Related header geometry|group-only sequence starts' --reporter expanded`:
  15 passed, including the corrected existing Back-button assertion.
  See `regressions-final.log`.
- Complete Kurumi suite: 241 passed (`kurumi-verified.log`).
- `./scripts/run_regression_tests.sh` recorded passing results for the application
  (7,799), all 13 package/CLI suites (1,725; two skipped), both shell checks and
  all 76 Python tests: **9,524 Dart/Flutter tests passed**. The aggregate process
  returned signal 143 after printing the final tooling results; this is not a
  clean aggregate exit-0 claim. All three final repository tooling commands were
  rerun individually and exited 0. See `full-regression.log`,
  `policy-final.log`, `release-tooling-final.log`, and `tooling-final.log`.
- `fvm flutter analyze --no-pub --no-fatal-infos <13 changed Dart files>`:
  exit 0, zero errors, zero warnings, 26 informational findings
  (`analyze-final.log`). This is not a zero-lint claim.
- `fvm dart format --output=none --set-exit-if-changed <13 changed Dart files>`:
  exit 0, no changes (`format-final.log`). `git diff --check` passed.

All runtime/test files are unchanged from these checks in `40cce183c`.
The subsequent handoff commit changes documentation only.

## Native evidence

Built the unchanged final runtime using
`fvm flutter build apk --debug --flavor dev --target-platform android-x64`
(`apk-final.log`). Local APK and installed `base.apk` both have SHA-256:

`f80fa57b44783b957c4796dc4bf3f5c9869c0037f39ed6240a91baacbacb7841`

Installed without clearing app data on exclusively leased `emulator-5556`,
package `com.timberpile.boorusama.dev`. Maestro MCP controlled UI after
hierarchy inspection. Decoded Related and Pixiv images were visually inspected.

- A real two-member Related family passed the exact reported sequence, including
  initial Single swipe, switching to Timeline, opening a tile, swiping, drag-down,
  opening a different tile, and swiping back. The retained 23-command
  `native-related-cycle.yaml` repeats three member visits and asserts distinct
  member timestamps and both Bookmark toolbar controls. It passed at normal
  360dp width/text and again at 320dp with Android font scale 1.5.
- Related Timeline's title appears inside the app bar at 320dp/150% text.
  Single and Detailed captures show matching compact header surfaces and sort
  height/radius. Automated tests measure the exact painted and touch dimensions.
- With global UI Overlay set to Hide, Related Timeline tile entry hides both
  toolbar rows. After drag-down, another tile also opens with both rows hidden.
  Tapping media reveals both rows, and member swiping still works.
  Global Show was then restored and asserted in settings.
- The six-member Danbooru Series used in the original handoff and a real
  three-Page Pixiv Work passed Timeline/tile/swipe/drag-down/re-entry smoke
  checks. Both scoped Bookmark controls remained available after reopening.
  The Related flow provides the explicit member-identity assertions; these
  additional flows are smoke checks, not equivalent identity coverage.

Retained captures include `native-related-single-320-150.png`,
`native-related-timeline-320-150.png`,
`native-related-hidden-320-150.png`,
`native-related-detailed-320-150.png` and
`native-pixiv-repeat-single.png`.

Original Default profile, global Show preference, physical density 320 without
an override, and font scale 1.0 were restored; density/font values were read back.
Profile-specific settings were inspected without saving edits. No Bookmark,
folder membership or website Favorite was saved. The exclusive lease was
released.

## Limits

Native light-theme, reduced-motion and enabled profile-override scenarios have
automated coverage only in this follow-up. Collection-specific live sorting,
landscape/video, predictive Back, authenticated writes and physical-device
responsiveness were not requalified. The original implementation handoff remains
historical evidence for its own candidate. Owner visual acceptance is pending;
no push, PR, integration or issue closure was performed.
