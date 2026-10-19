# Navigation follow-up: Settings profiles, legacy drawer gestures, Favorites picker

**Status:** implemented locally on the named branch. See the [verification report](2026-10-19-navigation-polish-report.md) for the checked candidate, results and remaining native acceptance limits. The instructions and required checks below remain the approved specification, not independent evidence that every device scenario passed.

**Branch:** `feature/navigation-direct-destinations-preview` in `timberpile/Boorusama`.
**Audited implementation:** `c6e2f540a5501cf4dc804803c763ee249d350549`.
**Historical drawer reference:** `d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b`.

Implement these three corrections on the existing branch. They supersede conflicting details in the earlier navigation architecture, implementation guide and acceptance matrix; do not restart that migration or restore an old preview. Follow the current `AGENTS.md`, relevant repository skills and development workflow. Use the existing isolated worktree, preserve other changes, and inspect newer branch commits before editing. Do not merge into develop, create a PR or release.

## Approved behavior

1. **Settings → Profiles** is the only normal profile-management entry. Remove Profiles from both compact and wide sidebar catalogs. Replace the old BOORU SETTINGS / Edit current profile section, rather than merely renaming it. The management list makes an explicit profile choice and never selects the last Browse/Favorites account implicitly.
2. Restore opening and closing swipes using the **same framework drawer behavior as the old app**, including its existing swipe-area preference. No custom gesture recognizer, velocity calculation, new swipe threshold or new gesture package. Remove the sidebar X. Keep Menu toggle, scrim dismissal, Back and Escape as non-gesture alternatives.
3. Favorites has the selected profile's logo **beside the Search action**, opening the same compact anchored profile menu used by Browse. Only Favorites-eligible profiles appear. Its selection remains independent of Browse and resumes the selected account's retained Favorites state.

Do not change the compact four-item row, Following badge, menu density, profile-section collapse behavior, absent empty sections, source ownership, or the fixed viewer lifecycle. The post viewer still has no main bottom bar or navigation-specific black gap; its Back returns to the real origin. Sidebar-opening gestures are not enabled over a viewer.

## Source map and confirmed starting points

Paths below are relative to the audited branch unless explicitly marked historical.

| File | What to inspect/change |
| --- | --- |
| `lib/core/settings/src/pages/settings_page.dart` | `_entries`, `SettingsPageOtherSection`, adaptive Settings navigation. The latter still reads `booruBuilderProvider(ref.watchConfigAuth)` and uses `ref.watchConfig` for Edit current profile. |
| `lib/core/navigation/profile_management_page.dart` | Existing `ProfileManagementPage`; already edits the tapped profile explicitly and supports add, reorder, duplicate, delete, icon and host. Reuse it. |
| `lib/core/navigation/navigation_catalog_provider.dart` | Remove the `GlobalNavigationDefinition` for `AppDestination.profiles`, not the actual profile definitions or source menus. |
| `lib/core/navigation/navigation_destination_pages.dart` | Existing Profiles destination and Favorites recovery link. Preserve compatibility while directing normal recovery to Settings/Profiles. |
| `lib/core/settings/src/routes/route_utils.dart` | Existing `openTopicUpdatesSettingsPage` and similar `ref.pushRoute('/settings?initial=...')` patterns. `goToSettingsPage` currently has only `scrollTo`, not an `initial` argument. |
| `lib/core/navigation/app_navigation_shell.dart` | Currently draws a conditional custom panel/scrim in a Stack, includes the X, and keeps bottom shortcuts outside the scrim. It does not currently host the legacy drawer gesture controller. |
| `lib/core/navigation/navigation_chrome_controller.dart` | Shared `menuOpen`, selection/viewer state and bottom-bar state. Preserve one authoritative chrome state. |
| `lib/core/navigation/destination_router.dart` | Recently corrected transient viewer dismissal. Do not undo its guarded pop/completion behavior while integrating drawer Back. |
| `lib/core/navigation/navigation_profile_picker.dart` | Existing `NavigationProfilePicker(favorites: true)`; intentionally requires a Favorites `DestinationScope`, filters eligible profiles, and calls `selectFavoritesProfile`. |
| `lib/core/navigation/profile_context_menu.dart` | Reuse the existing compact icon trigger, popup geometry, rows and focus behavior. |
| `lib/core/posts/favorites/src/pages/favorite_page_scaffold.dart` | The shared Favorites header already includes a picker. Do not add a second one. |
| `lib/boorus/danbooru/posts/favorites/src/favorites_page.dart` | Confirmed custom header: `DanbooruFavoritesPageInternal` builds its own `KurumiSliverAppBar` with Search only. It bypasses the shared Favorites scaffold and lacks the picker. |
| `packages/kurumi/lib/material.dart` | Re-exports `material_ui`. Use this existing import boundary, not an incompatible second Material library. |
| Historical `lib/core/home/src/widgets/booru_scope.dart` | At the historical SHA only: `Scaffold.drawer`, `drawerEdgeDragWidth`, `_calculateDrawerEdgeDragWidth`, and `swipeAreaToOpenSidebarPercentage`. This file is absent from the audited current branch. |

Retrieve the old implementation directly from history, not a stale HTML mockup:

```bash
git show d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b:lib/core/home/src/widgets/booru_scope.dart
rg -n 'FavoritesPageScaffold|NavigationProfilePicker|favoritesPageBuilder' lib/boorus lib/core
rg -n 'AppDestination\.profiles|edit_current_profile|swipeAreaToOpenSidebarPercentage' lib test
rg --files test/core/navigation test/core/settings
```

The Danbooru header omission is a verified source-level difference, not proof that every reported missing picker has that cause. Reproduce on the installed candidate and audit the other custom Favorites builders too.

## Task A — Move profile management into Settings

### A1. Pin the regression before editing

Add `test/core/settings/profiles_entry_test.dart` (or extend its exact equivalent if the branch now has one) using the existing real Settings harness. Test:

- Settings contains Profiles and no Edit current profile or obsolete BOORU SETTINGS section.
- Compact and wide app sidebars contain no Profiles administration row.
- With zero, one and multiple configured profiles, Settings/Profiles remains reachable. One profile still shows the management list; zero profiles still offers Add.
- From Settings/Profiles, tapping account B edits B while Browse remembers A and Favorites remembers C. Opening/closing the editor does not change either remembered account.
- Back from the editor returns to the list; Back from the list returns to Settings in compact mode. Wide Settings shows one selected category and no double toolbar.

Run the relevant test and confirm a behavioral failure before implementing. Do not override the entire Settings widget with a test-only fake.

### A2. Reuse the list as a normal Settings category

In `settings_page.dart`, add Profiles as the first standard `_entries` item, using the existing localized `context.t.navigation.profiles` label. Use the surrounding icon conventions. `_destinations` and `_destinationCatalog` already derive their entries from that list; do not create another settings navigation controller.

The intended entry is equivalent to:

```dart
SettingEntry(
  id: 'profiles',
  name: '/settings/profiles',
  title: context.t.navigation.profiles,
  icon: FontAwesomeIcons.users,
  content: const ProfileManagementPage(showAppBar: false),
),
```

`showAppBar` is a **new optional parameter** to add to the existing page, defaulting to true. In embedded mode, omit its app bar because Settings supplies the category header. Keep the same list/reorder/editor operations; do not make a second profile management implementation.

Keep Add reachable in embedded mode: put one compact Add row in the reorderable list's non-reorderable header, or the equivalent existing Settings action slot. Do not shift the profile item indices or include Add as a draggable profile. The standalone compatibility page can keep its existing app-bar Add action. Avoid two Add controls in the same presentation.

Remove the entire current-profile block and its now-unused `booruBuilder` read from `SettingsPageOtherSection`. Remove imports only after confirming they have no other users in that file. Keep unrelated Other/Contribute/Support entries and the Settings search control intact; the prohibition on sidebar search concerns the app navigation drawer, not Settings' own search.

### A3. Remove the duplicate catalog entry, not working routes

Delete only the Profiles `GlobalNavigationDefinition` in `navigation_catalog_provider.dart`. Both app sidebar presentations must derive from the corrected catalog. Do not add a hidden substitute profile-management row to the Browse/Favorites popup.

Do **not** delete `AppDestination.profiles`, remove all profiles from the catalog data, renumber destination IDs, or invalidate saved paths. Existing compatibility ingress can remain, but the normal UI must open management through Settings.

For the existing Favorites recovery link in `navigation_destination_pages.dart`, add/reuse an `openProfilesSettingsPage(WidgetRef ref)` helper in Settings routes. Follow the current route-helper pattern:

```dart
Future<void> openProfilesSettingsPage(WidgetRef ref) => ref.pushRoute(
  Uri(path: '/settings', queryParameters: {'initial': 'profiles'}).toString(),
);
```

Export it through the existing routes barrel. This is a contextual recovery link to the same Settings category, not a second standalone administration entry. Do not call `goToSettingsPage(initial: ...)`: that argument does not currently exist. Check both a cold Settings launch and an already-open Settings instance so initial-category handling actually opens Profiles without destroying unrelated destination histories.

From within Settings itself, selecting Profiles must use the existing category navigation, **not** `selectDestination(AppDestination.profiles)`. Otherwise the promised local Back behavior is lost.

### A4. Check and commit

Run the new Settings test, the relevant Settings navigation tests, and the real catalog-provider tests. Verify actual provider output as well as a catalog built from hand-authored test fixtures. Check add/reorder/duplicate/delete via existing tests and explicit profile IDs; do not perform destructive tests on the user's live accounts.

Commit the focused change as `fix(settings): manage profiles only through settings`.

## Task B — Reconnect the legacy framework drawer, without custom gestures

### B1. Preserve the exact old gesture configuration

The old app delegated gestures, animation and dismissal to the framework through `Scaffold.drawer`. Its configured edge area was:

```dart
final fraction = (areaPercentage / 100).clamp(0.05, 1);
final width = screenWidth * fraction;
return width < 20.0 ? 20.0 : width;
```

Continue reading **`settings.swipeAreaToOpenSidebarPercentage`** and use that same calculation with the same width basis (`MediaQuery` width). Extract the historical calculation into a small reusable helper if needed. Do not replace it with a new fixed edge width or treat zero as disabling the gesture: the previous calculation clamps it to five percent with a 20-pixel minimum.

Example regression values for a 400-pixel screen are 20 pixels at 0/5%, 100 at 25%, and 400 at 100% or above. A 320-pixel screen at 5% still produces 20. These describe the historical preference calculation, not newly designed thresholds. Preserve the framework's start-edge/RTL behavior.

### B2. Replace the custom overlay host with the existing framework mechanism

Use the `DrawerController`/`Drawer` implementation re-exported by `package:kurumi/material.dart`, i.e. the same implementation that backs `Scaffold.drawer`. Read its **resolved installed source** before wiring it. Do not copy the framework source or upgrade `material_ui`.

For the current shell layout, a direct, statefully owned `DrawerController` in the existing bounded overlay slot is the smallest way to keep the bottom shortcuts outside the drawer barrier. Keep it mounted while compact navigation is eligible, **including while closed**: its closed state owns the edge-swipe hit region. Replacing `if (chrome.menuOpen)` with another conditional that mounts the controller only after opening would leave swiping broken.

The host shape is:

```text
Expanded content Stack (unchanged viewport)
  Existing MediaQuery + retained navigationShell
  Bounded framework DrawerController + existing catalog panel
    top/left/right = 0, bottom = existing bottomExtent
  Existing bottom shortcut overlay, above/outside the drawer barrier
```

Preserve the current panel width/density and profile collapse states. The standard drawer owns its scrim; remove the old custom `GestureDetector` scrim and conditional panel to avoid two barriers or overlapping hit targets. Do not use a full-shell modal drawer that covers/disables the bottom shortcuts. Do not move the post grid into a shorter Column just to make space for the drawer. A framework drawer host must not reintroduce automatically implied top-bar hamburgers.

If a bounded `Scaffold.drawer` host fits the existing tree more cleanly, it is acceptable **only** if it passes the same no-reparenting/no-extra-padding/bottom-shortcuts tests. Do not implement a custom `GestureDetector`, `RawGestureDetector`, drag physics or recognizer to preserve the current overlay.

A stable `GlobalKey<DrawerControllerState>` belongs to the shell state (or a small stateful drawer-host widget). Use the framework's public open/close operations for Menu commands and its `drawerCallback` to reflect user-driven open/close into `navigationChromeProvider`. The `isDrawerOpen` constructor property is documented primarily for restoration; do not assume assigning it alone is the command mechanism. Check the pinned implementation.

### B3. Wire state and Back once

- Menu toggles the framework drawer. A swipe updates the existing chrome state so bottom-bar visibility, active-page work, focus and semantics remain correct.
- Guard callback synchronization against repeating the same value. Do not maintain an unrelated global drawer state, continuously restart animations on rebuild, or issue navigation commands during build.
- The X in **the app catalog panel** is removed. Do not remove Settings close buttons, popup cancellation controls or other unrelated X icons.
- Closing must work by the old leftward drawer swipe in LTR, Menu, scrim, Back and Escape. Delegate the gesture's completion/cancellation and animation to the framework.
- Respect framework local-history handling. Closing the drawer must not also pop a child, switch to Browse, or exit the app. Reconcile the shell's existing `BackButtonListener`/`PopScope` with the framework's drawer handling; do not layer a second Back consumer that executes both actions.
- Preserve guarded destination selection and the recently fixed viewer transition handling. A successful menu selection leaves the drawer closed; a rejected selection must not activate a different page. Await actual framework/navigation completion where needed, never an arbitrary sleep or repeated pop-until-root loop.
- Opening is disabled while a post viewer, selection or blocking input/modal owns the interaction. The main bar remains absent in the viewer, with no new inset. Do not open the drawer behind a root dialog or app lock. When changing to wide layout, close/reconcile any compact drawer state without recreating the retained branch navigators.

The extra work is **host/state integration**, not new swipe behavior. Keep the behavior and preference users already know. Do not broadly exclude Android's system-back gesture area or promise every OS edge configuration can be overridden; test the same old gesture sequence on the available device settings.

### B4. Native regression tests

Add `test/core/navigation/sidebar_drawer_gestures_test.dart` or extend the equivalent current shell integration test. Use real pointer drags and the real controller, not just `setMenuOpen(true)` assertions.

Test edge opening, left-swipe closing, partial-drag cancellation, the historical area preference, Menu → swipe close → Menu reopen, swipe open → Menu close, scrim tap consumption, and one Back closing only the drawer. Vertical scrolling of the menu must still scroll its list.

Also test: preserved nested route/filter/scroll state; Following/Bookmarks shortcuts operable while the drawer is open; opening after auto-hide reveals the bar; wide-to-compact resizing; no drawer opening over viewer/selection/modal; no viewer padding regression. Match stable semantics instead of depending on the removed custom scrim widget's type.

Verify native Android back-swipe coexistence under the emulator lease procedure. This behavior cannot be qualified solely by a test of a boolean controller.

Commit as `fix(navigation): restore legacy drawer gestures`.

## Task C — Show the Favorites profile logo on every supported Favorites header

### C1. Reproduce the actual missing header action

Start with the real Danbooru Favorites page and at least one engine using `FavoritesPageScaffold`, such as Gelbooru. The common scaffold already has a picker; Danbooru's custom header does not. Enumerate other custom Favorites headers with the source-map search before declaring coverage complete.

Add `test/core/navigation/favorites_profile_picker_regression_test.dart` (or extend a matching current real-page test). Mount the actual page under the real Favorites destination scope, use fake repositories to avoid live mutations, and assert exactly one profile-logo trigger beside Search. A generic placeholder header would not detect Danbooru's omission.

### C2. Reuse the existing picker

In `lib/boorus/danbooru/posts/favorites/src/favorites_page.dart`, import the existing navigation picker and add:

```dart
const NavigationProfilePicker(favorites: true),
```

to the custom `KurumiSliverAppBar.actions`, immediately after the Search action in LTR. Apply the same header order to the shared scaffold by **moving its existing picker**, not duplicating it. Where an eligible engine has no Search action, retain the profile logo in its normal toolbar action position.

Audit other engine-specific Favorites headers and make equally small insertions wherever they bypass the common scaffold. Do not replace their page classes, search queries, grids or server actions with a universal Favorites implementation.

Keep the `DestinationScope` guard in `NavigationProfilePicker`. If the scope is wrong, fix the source/host wiring; do not make it read a global active profile to force a visible button. Keep the existing `ProfileContextMenuButton` (logo + compact icon/name rows), eligibility calculation, selected indication, `selectFavoritesProfile` and independent remembered Favorites state.

Do not hide the logo solely because one eligible profile remains: it still identifies the displayed account. Empty or revoked-source views continue using explicit recovery, not an automatic account fallback. Selection must block picker activation. The ordinary viewer remains non-switchable.

### C3. Prove account and state behavior

Test:

- Danbooru and a common-scaffold engine both display one trigger; no double header or duplicate picker.
- Popup shows eligible accounts with icon/name/selection, excludes ineligible ones, and fits narrow/enlarged-text layouts using the already compact geometry.
- Favorites A → B → A preserves each existing state. Browse's profile/query stays unchanged.
- Search launched from Favorites uses the selected Favorites owner and existing source-bound route behavior.
- Profile removal/eligibility changes while the popup is open cannot issue an action under a different account. Selection mode prevents opening/activating the picker.

Run the new real-page test and existing profile-popup, Favorites and source-scoped navigation tests. Commit as `fix(favorites): expose profile switching in custom headers`.

## Final verification and handoff

Read `docs/android_emulator.md` before operating any of the user's running emulators. Discover and address actual serials; acquire exclusive leases. Use Maestro MCP, preserve profiles and do not clear data or shut down devices as routine cleanup. Record the candidate installed on each device. No credentials in logs or screenshots.

Use scoped formatting on changed Dart files. Test commands below assume the proposed test paths were used; equivalent existing tests may replace them with explicit paths in the report:

```bash
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub --concurrency="$workers" \
  test/core/settings/profiles_entry_test.dart \
  test/core/navigation/sidebar_drawer_gestures_test.dart \
  test/core/navigation/favorites_profile_picker_regression_test.dart
fvm flutter test --no-pub --concurrency="$workers" test/core/navigation
# Include the existing Settings/Favorites consumer tests identified above.
fvm flutter analyze --no-pub --no-fatal-infos lib packages
./scripts/run_regression_tests.sh
git diff --check
```

Build using the current branch's actual entry procedure and pinned FVM SDK. Do not assume an old preview flag still exists or that a prior APK contains these changes. Since the shell is shared infrastructure, require the complete local regression suite on the final runtime candidate before claiming integration readiness. Do not weaken/skip failures merely because the visible task is small.

Device acceptance: Settings → Profiles → edit explicit B → Back twice; no Profiles in compact/wide sidebar; left-edge swipe open/leftward close and Menu alternatives; no X; working nested page retained; Favorites logo beside Search with independent switching; viewer retains correct Back and no black navigation gap. Check narrow width, enlarged text, landscape and Android system Back.

Update older tests/docs only where their old expectations conflict with this approved follow-up. Preserve unrelated assertions and the fixed stuck-viewer regression. Commit all scoped runtime changes and report significant decisions, exact commands/results, actual build/device checks and limitations in German. Follow repository publication authorization; no force push, PR, merge or release.

## Reference and verification limits

This guide was derived from the pinned source listed above. The original authoring task did not modify Dart, run native tests or build an APK. The checks above were specified for the subsequent implementation; their executed results and limits now live in the verification report linked at the top. Verify the newer local/remote branch before following exact edit instructions.

Historical drawer source: [booru_scope.dart at d78c0aa](https://github.com/timberpile/Boorusama/blob/d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b/lib/core/home/src/widgets/booru_scope.dart).

Framework behavior references, checked 19 October 2026: [DrawerController](https://api.flutter.dev/flutter/material/DrawerController-class.html) and [isDrawerOpen](https://api.flutter.dev/flutter/material/DrawerController/isDrawerOpen.html). The app uses the `material_ui` export from Kurumi; the installed pinned source, not latest web documentation or a dependency upgrade, is authoritative for its concrete API.
