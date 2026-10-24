# Navigation polish verification — 19 October 2026

Branch: `feature/navigation-direct-destinations-preview`.
Fetched input: `ce02fdad3` (the approved follow-up).
Runtime candidate: `4cdb8062d`; final test candidate: `3dc9fd989`.
This report and the companion specification corrections do not change that runtime or test candidate.

The subsequent requested sidebar order, sizing and labels are documented separately in the [sidebar layout follow-up report](2026-10-19-sidebar-layout-report.md), with its own checked candidate and verification limits.

## Result

- Profiles is the first standard Settings category. It embeds the existing management list without a second app bar and provides a non-reorderable Add header. The old current-profile section and compact/wide catalog administration row are removed; the standalone destination remains compatible.
- Favorites recovery opens the shared Settings/Profiles category. An explicit request identity lets the same category reopen in retained Settings after another category was selected. This uses the existing Settings navigation provider and preserves other destination histories.
- The bounded overlay uses the installed `material_ui 1.2.0` DrawerController, re-exported by Kurumi, and the historical `swipeAreaToOpenSidebarPercentage` calculation. It stays mounted when closed, synchronizes public open/close commands with chrome callbacks, and owns the scrim and local history. The app catalog has no X. Bottom shortcuts and retained navigators keep their original slots.
- Viewer, selection, keyboard and root/branch modal coverage disable drawer opening. Route observers publish their existing top route after the frame; they do not maintain a second history. Deactivation suppresses the framework's disposal-time close callback.
- Danbooru's actual custom Favorites header now includes the existing profile logo after Search. The shared scaffold moves its existing picker to the same order. The audited other builders (Anime Pictures, E621, Eshuushuu, Gelbooru, both Gelbooru V2 paths, Hydrus, Moebooru, Sankaku, Shimmie2 and Szurubooru) use that scaffold.
- Popup callbacks re-read live profile membership and Favorites eligibility and check the originating destination before selecting. This fixes a reproduced queued-callback regression that could otherwise leave Favorites after an account lost eligibility.
- The real-page 320-pixel/200% tests exposed an overflowing shared post-count label. Giving that label the available width fixes the overflow without changing grids, queries or server actions.

## Local verification

Settings tests were added before implementation and failed behaviorally on the duplicate catalog entry and missing category. The actual Danbooru page test failed on its missing logo; the shared page failed the required action order. A retained callback after eligibility revocation reproduced the incorrect destination change before the live validation fix.

Commands used the pinned FVM SDK (Flutter 3.47.2). `workers="$(python3 scripts/physical_core_count.py)"` detected six available physical cores for ordinary test concurrency:

```bash
fvm dart format <changed Dart files>
fvm flutter test --no-pub --concurrency="$workers" test/core/settings/profiles_entry_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/core/settings test/settings test/core/configs/update_profile_route_test.dart test/application/config_lifecycle_flow_test.dart test/core/navigation/navigation_catalog_test.dart test/application/navigation_redesign_flow_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/core/navigation test/application/navigation_redesign_flow_test.dart test/application/navigation_viewer_lifecycle_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/core/navigation test/core/posts/favorites test/core/posts/listing test/core/routers/profile_scoped_navigation_test.dart test/core/search/navigation_search_profile_test.dart test/application/navigation_redesign_flow_test.dart test/application/navigation_viewer_lifecycle_test.dart test/application/profile_management_context_menu_flow_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/application/download_manager_flow_test.dart test/application/profile_management_context_menu_flow_test.dart test/core/settings/profiles_entry_test.dart
fvm flutter analyze --no-pub --no-fatal-infos lib packages
fvm flutter build apk --no-pub --debug --flavor dev
./scripts/run_regression_tests.sh
git diff --check
```

Completed focused runs: 6 final Settings regression cases, 348 Settings/catalog/lifecycle consumers, 53 drawer/navigation/viewer cases, 131 Favorites/listing/navigation/management consumers, and 15 download/management/Settings consumers. The two actual Favorites page journeys were rerun after adding account-removal, ineligible-account, queued-selection and selection-mode checks, at 320 pixels and 200% text.

The drawer tests use actual pointer drags: edge opening, leftward closing, partial cancellation, 0/5/25/100% preference regions, Menu/swipe combinations, Escape, consumed scrim taps, one-Back dismissal with nested search retained, working shortcuts after auto-hide, vertical menu scrolling, resizing without remounting grids, root/branch modals, selection and viewer clearance. Existing completed-viewer regressions remain intact. Existing profile lifecycle/context-menu tests cover Add, explicit edit, reorder and deletion through Settings. The final Settings regression also duplicates explicit profile B, checks its new persistent ID, and exercises the actual Favorites recovery link from another destination into already-retained Settings.

Full `lib packages` analysis exited successfully with no errors or warnings and 2,805 informational lint diagnostics. Focused changed-source/test analysis also exited successfully with no errors or warnings and seven informational style diagnostics. The final added Settings regression was analyzed separately with no issues. A read-only formatting check confirmed all 22 changed Dart files already formatted; all 13 relative links in the five updated documents resolved. No dependency, SDK, localization input or generated-code change was needed.

The first complete run had one reproducible application-test failure: the shared UI driver returned before the new drawer's closing animation completed, making a download pause control temporarily unhittable. A serial named rerun reproduced it. Replacing the driver's fixed 500 ms pump with its existing frame-based settle helper made the named test and all 15 related consumer cases pass. The complete runner then passed on `3a035d9a7`: 4,102 application tests, all 13 package/CLI suites, both shell tooling suites and 63 Python tooling tests. After adding the final real-recovery/duplicate regression, it was rerun on `3dc9fd989`.

The final complete runner on `3dc9fd989` exited 0: **4,103 application tests**, **1,467 passing package/CLI tests across all 13 package suites**, both repository shell suites, and **63 Python tooling tests**. All suite commands completed; the two pre-existing individual GoRouter skips are listed below. No failures remained. The final companion documentation commit does not change the tested runtime or tests. Raw successful run, analysis and build logs are retained locally in `build/navigation-review/polish/`.

Two existing GoRouter tests remain explicitly skipped by their original `skip: true` declarations: `routing config works with shell route` (`packages/go_router/test/routing_config_test.dart`) and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change` (`packages/go_router/test/go_router_test.dart`). These files and skips were not changed; they are not reported as passed cases.

## Android evidence and limits

The normal Dev APK was built without a navigation define and installed with `adb -s emulator-5554 install -r` under an exclusive lease, preserving app data. The binary was built from the final runtime candidate; the subsequent commit only changes the test driver.

Artifact: `build/navigation-review/polish/app-dev-debug.apk`.
SHA-256: `6c08411a61236c4b2a2ba8ff56f972b298cfb080df93c876171e3e5690845030`.

Maestro MCP checked the installed candidate:

- Compact catalog has no Profiles administration row and no X; Settings retains its own close controls.
- Settings → Profiles → explicit existing profile editor (Save visible) → Back → list → Back → Settings passed. The same journey passed at 320 logical pixels with 200% text, and Settings remained usable in landscape.
- At wide width and 200% text, visual inspection confirmed no Profiles row in the app sidebar, one selected Profiles category inside Settings, one content header and one Add control.
- With three-button navigation temporarily selected, native absolute-coordinate drags from `(40, 900)` to `(900, 900)` over 1,500 ms opened the drawer; `(700, 900)` to `(50, 900)` closed it. Opening again, selecting Following through the still-operable shortcut, reopening Menu and pressing Back kept Following selected.
- With Android gesture navigation, a system edge Back closed an open Menu without leaving the page. Extreme-edge opening swipes were consumed by Android Back on this emulator, including the same slow sequence. This is a native acceptance limit of the original edge-area/system gesture combination; no gesture exclusion, threshold or custom recognizer was introduced. The framework's preference calculation and pointer behavior are covered by the real-controller tests.
- The ordinary Browse viewer had no main navigation bar. Visual inspection showed the viewer controls above the system inset without the former navigation gap; system Back returned to the Browse grid and restored Menu.

The emulators contained only a guest profile. Native authenticated Danbooru/Gelbooru Favorites switching and the native A/B/C management scenario remain unperformed. They are covered by actual-page/headless-app tests with fake external repositories, not claimed as native/live acceptance. No destructive tests ran on live accounts and no credentials were entered or captured.

The original emulator configuration was restored and verified: 1080×2400, density 420, font scale 1.0, portrait, Android gesture navigation (`navigation_mode=2`). The diagnostic VM port forwarding was removed and leases were released. `emulator-5556` was inspected briefly before choosing the test device; it also had only a guest profile and no candidate APK was installed there. No physical phone was operated.

## Delivery boundary

The implementation is committed locally on the requested branch. No develop integration, remote publication, PR or release was performed. The native account checks and gesture-navigation edge-opening limitation above remain explicit acceptance limits; a complete local suite does not turn them into native passes.
