# Sidebar layout follow-up — 19 October 2026

Branch: `feature/navigation-direct-destinations-preview`.
Runtime candidate: `e156da329`; final test candidate: `a6b3263fa`.
This follows the [navigation polish report](2026-10-19-navigation-polish-report.md); its older native checks do not validate this candidate's new dimensions or ordering.

## Changes

- Compact and wide catalogs order profile-specific tools first, general tools second, and Settings, Get support and Donate last. Dividers separate populated sections. The wide layout retains its primary Browse, Following and Bookmarks rows above these sections. Empty profile headings remain absent.
- Management actions remain at the end of the same scrollable list, matching the previous sidebar's structure. They stay reachable when profile tools or enlarged text extend beyond the viewport.
- The compact drawer's maximum width decreases from 340 to 280 logical pixels; the existing 48-pixel outside area and 240-pixel minimum remain. The wide sidebar decreases from 280 to 240.
- English localization values now read Blacklist, Favorite Tags, Bulk Download and Download Manager. Existing localization keys are reused, so page titles using those values change consistently. Other locales remain intact.
- Donate was not deleted. Its existing FOSS/premium conditions remain: FOSS displays Donate; the normal build's premium entry requires the existing premium-upsell conditions. This fork currently forces premium, suppressing that normal-build entry. The provider test covers both FOSS and normal-build availability.

## Verification

Commands use the pinned FVM SDK. `workers="$(python3 scripts/physical_core_count.py)"` detects six available physical cores.

```bash
./gen.sh i18n
fvm dart format --output=none --set-exit-if-changed lib/core/navigation/app_navigation_shell.dart lib/core/navigation/navigation_catalog_provider.dart test/application/favorite_tag_flow_test.dart test/application/support/app_flow_driver.dart test/core/navigation/navigation_review_visual_test.dart test/core/navigation/sidebar_drawer_gestures_test.dart test/core/navigation/sidebar_catalog_layout_test.dart test/core/search/search_profile_switch_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/core/navigation test/core/settings/profiles_entry_test.dart test/application/profile_management_context_menu_flow_test.dart test/application/config_lifecycle_flow_test.dart test/application/favorite_tag_flow_test.dart test/application/download_manager_flow_test.dart test/application/navigation_redesign_flow_test.dart test/application/navigation_viewer_lifecycle_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/application/keyboard_navigation_flow_test.dart --name 'remote can open settings from the sidebar|Tab goes through the whole wide sidebar'
fvm flutter test --no-pub --concurrency=1 test/core/search/search_profile_switch_test.dart
fvm flutter analyze --no-pub --no-fatal-infos lib/core/navigation/app_navigation_shell.dart lib/core/navigation/navigation_catalog_provider.dart test/application/favorite_tag_flow_test.dart test/application/support/app_flow_driver.dart test/core/navigation/navigation_review_visual_test.dart test/core/navigation/sidebar_drawer_gestures_test.dart test/core/navigation/sidebar_catalog_layout_test.dart test/core/search/search_profile_switch_test.dart
fvm flutter test --no-pub --concurrency=1 --dart-define=NAVIGATION_VISUAL_STAGE=sidebar-layout test/core/navigation/navigation_review_visual_test.dart
fvm flutter build apk --no-pub --debug --flavor dev
./scripts/run_regression_tests.sh
git diff --check
```

Localization validation/generation passed. All eight changed Dart files are formatted. The focused navigation/consumer run passed 88 tests; the named keyboard run passed three tests; all four search-profile-switch cases passed. Both visual fixtures passed. Visual inspection of the 390-pixel sidebar fixture confirmed the requested groups, dividers and labels; this fixture includes an eligible Donate entry.

Analysis of all eight changed Dart files exited successfully with no errors or warnings. It retained two pre-existing informational `unnecessary_null_checks` diagnostics in the visual fixture's router builders. The earlier six-file focused analysis reported no issues.

The new layout tests use the actual application catalog and shell at 320, 390 and 1280 pixels, with 100% and 200% text. They verify widths, scrollable ordering, exact localized labels, omission of empty profile headings and successful navigation to Settings. The shared application driver now reveals off-screen catalog actions by scrolling, rather than assuming Settings precedes all profile tools.

The drawer regression uses continuous, sampled pointer swipes and verifies the actual panel is closed/reopened as well as checking chrome state. During diagnosis, a single synthetic update spanning the entire narrower drawer exposed the installed framework controller's existing sparse-input corner: after programmatic opening, it can reach the dismissed endpoint without reporting a close callback. Continuous sampled swipes pass. The framework controller and application gesture implementation were not changed; the synthetic corner is not claimed fixed or tested natively.

The first complete run exposed one additional consumer assertion still expecting the previous `Bulk download` translation in the selected-tag overflow. Updating it to `Bulk Download` made all four cases in that search-profile-switch file pass serially. The already-failed full run was stopped, and the complete runner was restarted on `a6b3263fa`.

The complete runner on `a6b3263fa` exited 0: **4,111 application tests**, **1,467 passing package/CLI tests across all 13 package suites**, both repository shell suites, and **63 Python tooling tests**. The two original GoRouter `skip: true` cases remain skipped: `routing config works with shell route` and `Obsolete branches in StatefulShellRoute are cleaned up after route configuration change`. No failures remained. Subsequent report-only edits do not change the tested runtime or tests. All six relative links in the three changed documents resolved, and `git diff --check` passed. Raw verification logs are retained in `build/navigation-review/sidebar-layout/`.

## Artifact and limits

The normal Dev debug APK built successfully:

- Path: `build/navigation-review/sidebar-layout/app-dev-debug.apk`.
- SHA-256: `7452bbe0bf7f15fe3a8477446d13679b49277987eeae2750e043e272ff35e8f9`.
- Visual fixture: `build/navigation-review/corrective/visuals/sidebar-layout-sidebar.png`.

This follow-up performed no emulator, physical-device or live-account checks. Native acceptance limitations recorded in the prior polish report remain separate. No keyboard inset behavior was changed; focused remote-keyboard and wide-sidebar traversal tests passed. No dependency, routing, profile ownership or drawer recognizer changed.

## Approved local integration

The user approved local integration after the complete verification above. Local `develop` was still `d78c0aa09`, an ancestor of the feature tip `2db459b61`. The prepared squash tree was exactly `efba8371fd7e6483c70a2590cefd163be54e4982`, matching that feature tip. Runtime, tests and dependencies also matched the fully tested `a6b3263fa`; only the report documents had changed. The existing complete pass therefore qualifies this integration. This integration note is documentation only.

The feature is integrated into local `develop` as one Conventional Commit. The primary checkout remains detached at its existing commit. No push, remote branch deletion, PR or release was performed. No work-queue items were changed by this feature.

Before task-worktree cleanup, all navigation review artifacts were preserved under `.worktrees/_artifacts/navigation-direct-destinations-preview-2026-10-19/navigation-review/`. The APK above is now at `sidebar-layout/app-dev-debug.apk` below that directory; its SHA-256 is unchanged. Historical logs, APKs, screenshots and local editor/FVM configuration were retained. The completed local task branch and its worktree are removed after verifying integration; the remote branch is retained.
