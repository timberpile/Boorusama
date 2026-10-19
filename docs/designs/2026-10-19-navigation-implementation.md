# Direct-destination navigation implementation guide

> Corrective review supersedes the initial implementation's viewer shortcuts, Topic-search picker exclusion, and standalone Backups entry. The bottom bar and its clearance are absent in viewers; full searches own a local profile menu; Export & Import stays under Settings. Follow [current architecture](2026-10-19-navigation-architecture.md) and [corrective evidence](2026-10-19-navigation-corrective-review.md). Original checklists below are historical implementation intent, not current pass claims.

**Goal:** migrate the real Boorusama pages to retained, explicitly sourced destinations with three bottom shortcuts, a Menu action, shared Favorites, and no empty profile headings.

**Architecture:** one application GoRouter, stable retained destination branches, route-local source scopes, and a catalog independent of the currently selected Browse/Favorites account. Existing engine renderers and domain repositories remain authoritative.

**Stack:** the repository's pinned FVM Flutter 3.47.2, resolved go_router 17.5.0, manually declared Riverpod providers using the pinned 2.6.1 fork, and local Kurumi components. Do not upgrade dependencies as part of this task.

**Spec:** [production architecture](2026-10-19-navigation-architecture.md). **Acceptance:** [validation matrix](2026-10-19-navigation-validation.md).

Continue `feature/navigation-direct-destinations-preview`. Read `AGENTS.md`, `.agents/skills/execute-plan/SKILL.md`, and relevant development workflow sections first. The user authorized preparation on this branch, not a merge into develop, a PR, or a release. Follow the repository's publication rules; never force-push over another agent's work.

## How to execute this guide

Perform the tasks in order. At each task, add the specified behavioral tests, observe the relevant failure, implement, rerun the tests, inspect the scoped diff, and make one cohesive English Conventional Commit. Do not treat a test that never exercised the changed behavior as regression coverage. Use controlled clocks/completers rather than host sleeps. The final migration is broad and requires the complete suite, not just the new navigation tests.

New classes and methods below are contracts to implement, not claims that those APIs already exist. Code blocks constrain signatures or non-obvious behavior; normal idiomatic bodies are deliberately left to the implementing agent. Adapt moved source paths after the initial inventory, but do not silently alter the product decisions. If the pinned router fails a foundational test, record the reproduction and repair that integration before wiring more pages; do not substitute independent unsynchronized routers or a More stack.

The older native preview is useful for geometry and test cases, not a production routing framework. In particular, do not wholesale rename `DirectNavigationShell`: its custom Navigators and sample page dispatch must not coexist as a second navigation authority inside the new GoRouter branches.

## Execution status (19 October 2026)

The real implementation and case-by-case evidence are in the
[implementation report](2026-10-19-navigation-implementation-report.md). The
original detailed acceptance actions below remain useful for independent review;
an unchecked combined test/device action is not a claim that its code is absent.

| Stage | Implemented result | Verification boundary |
| --- | --- | --- |
| 0 | Existing branch/worktree, fetched base, SDK, inventory | Baseline executed |
| 1 | IDs, pure filtered catalog, all-engine capabilities | Model/adapter tests |
| 2 | One real router, retained lazy branches, serial reconciliation | G1 passes with explicitly authorized two-method 17.5.0 backport |
| 3 | Live source scopes, global appearance, repository settings seam | Auth overlay/revocation and legacy consumer tests |
| 4 | Responsive real shell and overlay sidebar | Four widths, 200% text, menu/shortcut tests |
| 5 | Real Browse with compact profile menu | Real grid identity, twelve-profile keyboard popup |
| 6 | Shared independent Favorites | Real common scaffold requests and legacy-alias session retention |
| 7 | Real Following folder/feed/edit routes and explicit Topic search | Following-owned search journey; native nested-folder/Pixiv check pending |
| 8 | Real Bookmarks and normal viewer exit | Existing durable membership/Undo tests; combined native journey pending |
| 9 | Real global pages and all current engine tool adapters | Inventory/registration/zero-profile tests; live engine review pending |
| 10 | Existing names, aliases, payloads and source facade | Router/alias tests; external OS/browser journeys pending |
| 11 | Page/branch/root/background activity and source revocation | Activity, media, generation tests; long-session measurements pending |
| 12 | Reading chrome, safe areas, selection and viewer integration | Widget/policy tests; native Back/IME/accessibility checks pending |
| 13 | Candidate verification, builds and handoff | Full suite and both Android builds passed; Linux dependency/device checks remain open; no integration authorization |

The user's explicit permission supersedes the original Task 2 prohibition on a
router patch solely for the minimal documented fork-local compatibility fix.

## 0. Establish the exact working tree and source inventory

- [x] Fetch `origin` and inspect `git worktree list --porcelain`, `git status --short`, and the branch history. Reuse the isolated worktree for the existing branch. Otherwise create an isolated worktree attached to that branch, not a new unrelated branch. Do not stash/reset the user's primary checkout or overwrite dirty work. Resolve checked-out-branch ownership using the current AGENTS/workflow instructions before editing.
- [x] Confirm that `29942277742cee936932aaf5a4035be2a7f18d72` (the preview build fix) remains in the branch ancestry. Fetch and reconcile a newer `origin/develop` in the task branch when necessary, preserving shared history. At authoring time develop is `d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b` and is already an ancestor.
- [x] Run `fvm flutter --version`; use `.fvmrc`, `pubspec.lock`, and `pubspec_overrides.yaml` rather than guessing from constraints. Run `./init.sh` only when dependencies/generated inputs need initial setup. Use `./gen.sh` later only when changed inputs require generation.
- [x] Inventory routes, helpers, menus, profile readers, observers and tests with these commands. Save a concise classification in the task report, not credentials or a repository-wide dump:

```bash
rg -n 'GoRoute\(|ShellRoute\(|StatefulShellRoute\(' lib/core lib/boorus
rg -n 'ref\.router\.|GoRouter\.of|context\.(go|push)|Navigator\.(of|push)' lib/core lib/boorus
rg -n 'mobileMenu:|desktopMenuBuilder:|desktopViews:|customHomeViewBuilders' lib/boorus
rg -n 'currentBooruConfigProvider|ref\.(readConfig|watchConfig)|watchThemeConfigs' lib/core lib/boorus
rg -n 'RouteAware|routeObserver|didPushNext|didPopNext' lib
rg -n 'favoritesPageBuilder|hasLogin\(' lib/boorus
rg --files test | sort
```

For every navigation contribution, record owner (global or profile), existing entry helper, real page builder, child-route family, account requirement, and root-task exception. Cover all engines in `lib/boorus/registry.dart` and its generated registry, not only the demo's Danbooru/Gelbooru/Pixiv fixtures. Do not edit generated registration directly.

- [x] Historical setup check (the prototype and its tests were subsequently removed when the new navigation became the default):

```bash
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter test --no-pub --concurrency="$workers" \
  test/dev/navigation_preview \
  test/core/routers/profile_scoped_navigation_test.dart
```

Deliverable: a cleanly isolated task checkout, known baseline, and a classified route/menu inventory. No runtime change is needed for this setup task. Report environmental blockers precisely; do not manufacture passing results from the old README.

## 1. Add destination identity and the pure navigation catalog

**Create:** `lib/core/navigation/destination_id.dart`, `destination_definition.dart`, `navigation_catalog.dart`; `test/core/navigation/navigation_catalog_test.dart`.

**Interfaces:**

```dart
// destination_id.dart: constructors are specified in the architecture.
String DestinationId.toStorageKey();
DestinationId? DestinationId.tryParse(String value);

// destination_definition.dart
// NavigationAvailability: available, requiresAccount, unsupported,
// waitingForAccountMetadata. Only available becomes a catalog row.
// LocalizedLabel = String Function(BuildContext context).
// SiteToolDefinition: toolId, LocalizedLabel label, IconData icon,
// availability, bool isUnifiedFavorites; no Widget instance, HTTP operation
// or repository snapshot.
// ProfileNavigationCapabilities: profileId, caption, profileIcon,
// List<SiteToolDefinition> tools, NavigationAvailability favorites.
// ProfileNavigationSection: profileId, caption, profileIcon, rows.

NavigationCatalog buildNavigationCatalog({
  required List<ProfileNavigationCapabilities> profilesInStoredOrder,
  required List<GlobalNavigationDefinition> globalDefinitions,
});
```

`NavigationCatalog` exposes `profileSections`, `globalEntries`, and `eligibleFavoritesProfileIds`. `GlobalNavigationDefinition` includes an app ID or a shared-Favorites entry kind, label, icon, and build/availability policy. A shared entry is not itself a `DestinationId.favorites` until a profile is resolved. Keep entitlement rules at this boundary; do not make every global action unconditionally available on every build.

- [ ] Write tests named `favorites-only profiles do not emit empty sections`, `unavailable tools do not keep a heading alive`, `same-site accounts keep distinct targets`, `catalog order follows stored profiles`, and `shared favorites occurs once`. Include: Gelbooru with only eligible Favorites; a guest with no usable tools; Danbooru with Explore plus Favorites; two same-name Danbooru accounts. Assert the **absence of headings**, not merely zero child rows.
- [ ] Run `fvm flutter test --no-pub test/core/navigation/navigation_catalog_test.dart`; observe a meaningful failure.
- [ ] Implement the value types and catalog. Form sections only after filtering; do not infer tools from built widgets. The critical operation is equivalent to:

```dart
final rows = profile.tools.where(
  (tool) => tool.availability == NavigationAvailability.available &&
      tool.toolId != 'favorites' && !tool.isUnifiedFavorites,
).toList(growable: false);
if (rows.isNotEmpty) {
  sections.add(ProfileNavigationSection.from(profile, rows));
}
```

Define `isUnifiedFavorites` on the descriptor as a semantic flag for legacy engine-specific Favorites IDs; exclude by meaning, not just one spelling. Browse definitions never enter `tools`. A builder-only profile may still contribute eligible Favorites while emitting no section.

- [ ] Run the tests and add a test that constructing the catalog performs no page construction or external fetch. Keep this test at the adapter boundary once real adapters are introduced in Task 9.
- [ ] Commit: `feat(navigation): define explicit destinations and filtered catalog`.

## 2. Prove one-router retained destination routing

**Create:** `lib/core/navigation/destination_router.dart`, `navigation_controller.dart`, `navigation_page_request.dart`, `page_source_context.dart`, `navigation_preferences.dart`, `navigation_route_catalog.dart`; `test/core/navigation/destination_router_test.dart`, `test/core/navigation/helpers/navigation_harness.dart`.

**Modify:** `lib/core/navigation/app_navigation.dart`, `lib/core/router.dart` as the normal application entry.

**Interfaces:**

```dart
// Immutable page request: logicalUri, untouched Object? extra,
// optional explicit PageSourceContext. logicalUri is an existing logical
// route location; the route catalog maps it into the caller's branch.

abstract interface class DestinationNavigation {
  Future<bool> selectDestination(DestinationId destination);
  Future<T?> pushPage<T>(BuildContext caller, NavigationPageRequest request);
  Future<bool> openExternal(Uri uri, {Object? extra});
  void setMenuOpen(bool open);
}

// One long-lived binding owns the notifier and branch cache.
DestinationRouterBinding createDestinationRouterBinding(AppNavigation root);
// Binding: ValueListenable<RoutingConfig> routingConfig;
// reconcile(definitions), indexOf(id), idAt(index), dispose().
// Every surviving ID retains its branch object and navigator key.
```

`PageSourceContext(profileId, originatingTopicId?)` and the immutable in-memory `NavigationPreferences` value type are created in this task so the request/controller interfaces compile immediately. Task 3 adds live source resolution; Task 11 adds preference persistence and revocation integration. `NavigationController` is a manually declared Notifier for navigation preferences/transient shell commands. It does not store a parallel page stack. Bind the active `StatefulNavigationShell` to it from the shell lifetime and unbind on disposal. The current destination is derived from the router/branch registry; never maintained by a competing independent index. Controller async results return false when a guard rejects an action or a source has become invalid.

The harness uses the real router and new shell interfaces with small recording pages. It may fake external account repositories, but must not fake branch restoration or replace GoRouter with an in-memory list.

- [ ] Add tests for A-Pools/detail/draft -> B-Explore -> A-Pools with exact child and draft retained; A-Favorites and B-Favorites independent; primary reselect no-op; secondary targets do not select a primary shortcut; unknown destination returns a recovery route.
- [ ] Add structural tests: add profile C while A/B are open, rename/reorder B, lose B auth, delete inactive C, then delete active B. Assert surviving branch widget identities, drafts and paths remain; an invalid active branch reaches recovery before removal. Assert repeated route-name uniqueness and no duplicate GlobalKey exceptions.
- [ ] Implement `GoRouter.routingConfig`, one stable shell key, a cached `StatefulShellBranch` per destination, `preload: false`, and namespaced child routes under the canonical roots in the architecture. Update routing config only on structural changes. Never derive branch ordering from the current sidebar ordering.
- [ ] Keep recording pages in tests only; the application mounts real destination adapters.
- [ ] Add real browser-history/native Back tests where the harness supports them; test both `goBranch` resume and contextual `push`/`pop`. Do not call `initialLocation: true` for ordinary selection.
- [ ] Run `fvm flutter test --no-pub test/core/navigation/destination_router_test.dart`. Read the pinned 17.5.0 `route.dart` if cache identity/lifecycle fails; do not patch or import its private internals.
- [ ] Commit: `feat(navigation): retain destination branches in one router`.

This is gate G1: no feature migration proceeds until source-specific branches survive structural reconfiguration and nested navigation under the actual SDK.

## 3. Make source scope explicit and global appearance genuinely global

**Create:** `lib/core/navigation/destination_profile_scope.dart`; `test/core/navigation/source_scope_test.dart`, `global_appearance_test.dart`.

**Modify:** `lib/core/configs/manage/src/widgets/current_booru_config_scope.dart`, `lib/core/configs/manage/src/providers/current_booru_providers.dart`, `lib/core/themes/theme/src/theme_buider.dart`, `lib/core/app.dart`, and only consumers identified by the inventory.

**Interfaces:** `PageSourceContext(profileId, originatingTopicId?)`; `DestinationProfileScope({required String profileId, required Widget child})`; `DestinationScope({required DestinationId id, required Widget child})`; `DestinationScope.of(context)`; a profile-generation service returning an in-memory revision for source invalidation.

- [ ] Add tests that execute a search, comment/editor push, and Favorites action from account B while last Browse is account A. Inspect the actual external fake repository/auth argument, not only a label. Add a cross-engine case.
- [ ] Add tests that changing Browse/Favorites leaves global chrome, Bookmark grid defaults, Following and another account's destination configuration unchanged. Use root app settings and distinct profile themes to make leakage observable.
- [ ] Implement live lookup by profile UUID above the branch navigator. Reuse full `CurrentBooruConfigScope` overrides; source-bound children of a global branch receive a narrower child scope. Reject missing profiles before selecting a builder or issuing requests.
- [ ] Separate app-level ThemeBuilder inputs from optional profile content overrides. The root uses global appearance; destination scopes own profile appearance. Preserve entitlement conditions. Profile overrides affect explicit content only, not the root shell. Audit network, search, gesture, layout, viewer, download and transitive Riverpod providers; use existing parameterized families or necessary scoped dependency declarations with tests.
- [ ] Retain the legacy mutable current-profile notifier only as a Browse compatibility/persistence bridge. No catalog, Favorites or global action may use it as a fallback source. Add a focused audit assertion/test for these new modules; do not delete the entire old API blindly.
- [ ] Run the two new tests and `test/core/routers/profile_scoped_navigation_test.dart`.
- [ ] Commit: `refactor(navigation): isolate destination sources from app state`.

## 4. Build the real shell, vertical catalog, and shortcut action row

**Create:** `lib/core/navigation/app_navigation_shell.dart`, `navigation_catalog_panel.dart`, `main_navigation_bar.dart`, `navigation_chrome_controller.dart`; `test/core/navigation/navigation_chrome_test.dart`.

**Historical reference:** the removed prototype informed geometry and activity behavior. Its dispatcher and Navigators are not part of the application.

**Interfaces:** shell consumes `StatefulNavigationShell`, the registry/catalog and navigation facade. `NavigationChromeState` contains menu visibility, measured bottom extent, page mode (ordinary/grid/viewer/selection/form), keyboard state and auto-hide progress. Domain pages publish page mode/selection ownership using scoped, disposable registrations; they do not reach into shell widget state.

- [ ] Test exact labels Browse/Following/Bookmarks/Menu; Menu toggles an overlay without changing router location; secondary pages leave three shortcuts unselected; all catalog rows form one column; no sidebar search/top menu button.
- [ ] Test compact drawer scrim bounds end above the measured bottom bar. Tapping Following while drawer is open must switch exactly once and dismiss the drawer. Outside content taps close the drawer without opening a post. Keyboard focus traversal includes drawer plus shortcuts, but excludes obscured content.
- [ ] Implement breakpoint 1000 using available `LayoutBuilder` width. On wide layouts use the vertical primary rows and persistent sidebar, with no redundant bottom bar. Keep existing sidebar width preference within safe content constraints; do not create a tiny icon-only profile catalog.
- [ ] Place `AppRatingScope`, `DownloaderScope`, bulk-download error and layout-preview notification scopes once above the new branches, reusing the current app-level external effects. Keep the entire shell, including its bottom controls, under the existing AppLockScope. Move required EntryPage one-time startup effects, including changelog/permission notices, into one shell/bootstrap boundary; never run them for every branch. Add construction/disposal counter tests for global services.
- [ ] Add collapsible profile sections with state stored by profile UUID. Rebuild available rows after auth changes; an empty group disappears even if previously expanded. Preserve expansion for surviving groups and omit site-tools decoration if none remain.
- [ ] Introduce semantic/test keys: `nav-shortcut-browse`, `nav-shortcut-following`, `nav-shortcut-bookmarks`, `nav-menu-toggle`, `nav-profile-section:<id>`, `nav-destination:<encodedId>`. Use the framework DrawerController's bounds and dismissal semantics instead of a custom scrim widget key. Do not use translated text as state keys.
- [ ] Add real i18n entries for the short labels and new errors/accessibility copy. Locate the current input resources with `rg --files packages/i18n`; update those inputs and regenerate through the existing tooling. Do not rename full-page Following Topics titles globally just to shorten the bottom label. Do not promote `preview_copy.dart`'s ad-hoc language map.
- [ ] Run `fvm flutter test --no-pub test/core/navigation/navigation_chrome_test.dart` at 320/390/768/1280 logical pixels and 100%/200% text; check focus and touch targets as well as overflow.
- [ ] Commit: `feat(navigation): add direct menu and persistent shortcuts`.

## 5. Integrate real Browse and its compact profile context menu

**Create:** `lib/core/navigation/profile_context_menu.dart`, `browse_destination.dart`; `test/core/navigation/browse_navigation_test.dart`.

**Modify:** `lib/core/home/src/pages/entry_page.dart`, `home_page_scaffold.dart`, `mobile_home_page_scaffold.dart`, `lib/core/home/src/widgets/home_search_bar.dart`, `lib/core/configs/manage/src/widgets/booru_selector.dart`, `lib/core/search/search/src/routes/route_utils.dart` and `routes.dart` where needed.

**Interfaces:** `ProfileContextMenuButton({required List<ProfileMenuEntry> entries, required String? selectedProfileId, required ValueChanged<String> onSelected, required String tooltip})`. Entry contains UUID, icon, localized/disambiguated caption; no prebuilt pages. Add `NavigationController.selectBrowseProfile(String id)` and `selectFavoritesProfile(String id)`; the latter is used in Task 6.

- [ ] Test separate Browse drafts, executed queries and scroll positions for two accounts on one engine and a different engine. Changing profile must not submit or transfer draft text. The selected profile trigger is one icon directly right of the actual search input.
- [ ] Reuse the existing engine `homeViewBuilder`/search content, but do not embed `EntryPage -> HomePageScaffold -> BooruScope` as another shell inside the new shell. Keep the content/host seams and remove the old navigation construction.
- [ ] Keep engine-specific home behavior. Translate global Custom Home choices to startup destinations later in Task 11; never embed a second live Bookmarks/Bulk Download instance in Browse. Use a small per-engine content adapter where an existing home builder assumes the old controller.
- [ ] Implement the anchored menu with `KurumiAnchor`/current Kurumi menu rows, not mixed Material rows. Preserve icons/names, selected indication, menu scrolling, keyboard traversal, outside-tap consumption and focus restoration. Test both top and bottom search placement with 200% text and keyboard inset. No top-bar hamburger remains.
- [ ] Replace the old `ref.router.go('/?cid=...')` behavior only at new Browse selection entry points. Keep the legacy external link accepted via Task 10. Do not route a profile selection in Favorites through Browse.
- [ ] Migrate `goToSearchPage` internally to `pushPage` in a destination scope, leaving its public arguments and `SearchRouteContext` intact. Cold links derive explicit owner safely; do not discard `queryStructure` or `originatingTopicId`.
- [ ] Run the new test plus existing profile-scoped routing/search consumers. Commit: `feat(navigation): host real browse with scoped profile menus`.

## 6. Integrate shared Favorites without rewriting engine Favorites

**Create:** `lib/core/navigation/favorites_destination.dart`; `test/core/navigation/favorites_navigation_test.dart`.

**Modify:** `lib/core/posts/favorites/src/pages/favorites_page.dart`, `favorite_page_scaffold.dart`, `lib/core/posts/favorites/src/routes/route_utils.dart`, `routes.dart`; minimal custom-renderer adapters identified in Task 0.

**Interfaces:** `resolveFavoritesEntry({String? explicitProfileId, String? rememberedProfileId, required List<String> eligibleIds})` returns a typed selected/needs-choice/empty result. It distinguishes no previous choice from a remembered ineligible ID. `FavoritesHostActions` provides the profile icon to the actual Favorites toolbar without duplicate app bars.

- [ ] Test global Favorites row occurs once; no duplicate per-profile Favorites entry; eligible Gelbooru remains selectable but has no empty heading; Browse still lists the profile. Test zero eligible accounts and changing availability.
- [ ] Test A-Favorites/child -> B-Favorites -> A-Favorites resumes the correct child's underlying state; switching Favorites does not alter Browse. An explicit A Favorites alias and the shared selector resolve the same destination ID.
- [ ] Reuse `favoritesPageBuilder` under the live explicit config scope. Use each engine's eligibility rules, not builder existence alone or the demo boolean. Instantiate only the selected/previously visited destination, not every account in the menu.
- [ ] Add the host profile action to `FavoritesPageScaffold` through an optional widget/action injection, defaulting absent under legacy use. Preserve its `favQueryBuilder`, bound origin, fetcher, selection actions and search callback. For custom Favorites pages, use the same small host-action seam rather than rewriting their network or renderer code.
- [ ] Search/detail actions inside Favorites retain that Favorites branch and owner. An actual server mutation checks that owner/generation again. Missing/invalid remembered account yields recovery, never implicit fallback to another account.
- [ ] Run new Favorites/catalog tests plus relevant existing engine Favorites consumers discovered in Task 0. Commit: `feat(navigation): add shared favorites with independent account sessions`.

## 7. Migrate Following hierarchy, Topic search, and folder feeds

**Modify:** `lib/core/search/following_topics/src/routes/routes.dart`, `route_utils.dart`, `src/pages/following_topics_page.dart`, `topic_feeds_page.dart`, and the matching page-factory entries in `navigation_route_catalog.dart`.

**Create:** `test/core/navigation/following_destination_test.dart`.

- [ ] Test Following/folder/Topic-search(Pixiv) -> Browse(Danbooru) -> Following resumes the Topic search on Pixiv with its exact originating Topic UUID. Two identical queries saved as independent Topics must retain independent management targets.
- [ ] Test nested folder/back/breadcrumb behavior and the RSS folder-feed entry separately. A folder tap opens contents; its RSS action opens its feed; neither switches global Browse. The navigation badge reads existing cached `followingTopicHasNewPostsProvider` and never triggers a request.
- [ ] Mount the existing `FollowingTopicsPage`, not a new Feeds/Pins overview. Convert durable folder/feed navigation to declared branch child routes keyed by UUID; reuse existing page bodies and selection behaviors. Keep dialogs as guarded transient routes. Do not carry `_ancestorRoutes` references across replaced navigators; the new branch route hierarchy/breadcrumb helper owns ancestry.
- [ ] Preserve explicit mark-read and initialization semantics, lazy keyed rows, cached mixed-source origins, NEW/lower-bound counts, normal search opening, field controllers and duplicate-topic matching. Do not update old domain field names just because a new navigation label says Following.
- [ ] Preserve stale-definition rejection and the history session's Show updated posts behavior. Source edits/moves/caches invalidation reconcile the displayed feed without rebinding it to Browse.
- [ ] Run the new test and `fvm flutter test --no-pub test/core/search/following_topics`. Commit: `feat(navigation): retain following topics and folder feed journeys`.

## 8. Migrate Bookmarks and its real viewer/Undo contract

**Modify:** `lib/core/bookmarks/src/routes/routes.dart`, `route_utils.dart`, `src/pages/bookmark_group_browser_page.dart`, `bookmark_page.dart`, `bookmark_details_page.dart`, and necessary `src/widgets/bookmark_scroll_view.dart` host seams.

**Create:** `test/core/navigation/bookmark_destination_test.dart`.

- [ ] Test nested group/filter/scroll retention, All/Default ordering, genuine Default identity, and no No group category. All must not become a membership destination. Navigation must not change storage behavior.
- [ ] Test removing membership in the viewer commits before closing it, Undo restores only that membership, the viewer order remains stable, and the original grid updates after exit. Opening/closing an info sheet or the drawer is not viewer exit.
- [ ] Host the existing group browser and real `BookmarkPage` controllers in its branch. Preserve mixed-origin action resolution, manual recovery and unsupported source explanations. Do not fabricate a global profile to satisfy a generic PostGrid API; use its existing mixed-source action overrides and explicit app-level presentation configuration.
- [ ] Preserve route payloads, avoid force-casting absent extras on direct links, and resolve canonical post identity using existing services. Keep folders/groups identified by UUID, not title or position.
- [ ] Run the new test and the existing bookmark test files found by `rg --files test | rg 'bookmark'`; pass the explicit collected paths to FVM, not a guessed directory. Commit: `feat(navigation): retain bookmark journeys without changing memberships`.

## 9. Attach every real global destination and engine tool

**Create:** `lib/core/navigation/engine_navigation_adapter.dart`, `lib/boorus/navigation_registry.dart`, `lib/core/configs/manage/src/pages/profile_management_page.dart`, and engine-local navigation adapter files for engines with secondary menus; `test/core/navigation/engine_navigation_adapters_test.dart`, `global_destinations_test.dart`.

**Modify:** the exact route/helper files recorded by Task 0 under `lib/boorus/` and existing core routes for Blacklist, Favorite Tags, Bulk Download, Download Manager, Profiles, Backups, Donate, Support and Settings.

**Interfaces:** optional `EngineNavigationAdapter` produces locally evaluated capabilities and reusable page/route factories. Its registry sits beside, not inside, generated engine registration. Unchanged upstream `BooruBuilder` implementations must still compile without a new required member. Catalog and route factories share stable tool IDs.

- [ ] Add a completeness test enumerating every configured engine adapter and every inventory entry. Each must map to a real destination or a documented unification/unavailable condition. A generic `UnimplementedPage` does not count as migrating an existing working feature.
- [ ] Integrate Danbooru's actual Explore, Pools, Forum, Artists, account Profile, Favorite groups, server saved searches and blacklist with current account conditions; move its Favorites to the shared host. Preserve the upload scope when extracted page actions need it. Cover all other engine contributions from the inventory, including Pixiv Explore and Szurubooru/Shimmie/other custom route families as applicable.
- [ ] Avoid eager `danbooruCurrentUserProvider` or equivalent fetch-on-watch subscriptions across all profiles merely to determine menu visibility. Reuse cached account identity where available and preserve each engine's credential rules. Test menu building has zero external page/data requests.
- [ ] Mount the actual core pages using their existing exported entry points (`lib/core/blacklists/routes.dart`, `tags/favorites/routes.dart`, `bulk_downloads/routes.dart`, `download_manager/routes.dart`, `configs/create/routes.dart`, `settings/routes.dart`, `donate/routes.dart`, plus existing backup entry helpers). Use exports/Task-0 inventory for exact inner class names; do not invent replacement pages for existing features. Reuse `ProfileManagementPage` as the first Settings category with `showAppBar: false`, a non-reorderable Add header, existing create/update routes, and `BooruConfigNotifier` reorder/duplicate/delete operations. Omit its app-sidebar catalog row while retaining the standalone compatibility destination. Tapping a management row edits that profile; it does not activate Browse. Reuse the existing deletion confirmation and mutation coordination rather than implementing new profile storage.
- [ ] Give Settings and Support independent destination histories. Remove Backups from the catalog and retain its compatibility route; use Settings Export & Import for normal entry. Use `SettingsPage()` for Settings, `SettingsPage(scrollTo: 'support')` for support, and `SettingsPage(initial: 'backup_and_restore')` for Backups. Preserve the existing `SettingsNavigationSeed.hostIdentity` and internal 700-pixel settings breakpoint. Its current `_closeHost()` tries to pop a surrounding page; add an optional `Future<bool> Function()? onCloseHost` host callback for the new destination root, retaining legacy behavior when absent and clearing its closing guard if the close is rejected. Do not leave a retained Settings root permanently `_closing` after an unsuccessful pop. Keep platform settings dialogs, profile editors, import/restore and permission prompts as explicit root tasks when their existing lifecycle requires it. Reuse existing backup transactions.
- [ ] Give a menu-launched Bulk Download form its own source field; do not initialize it from a global active profile. A launch from a source-bound search may prefill that source/query. Test draft retention and user-queued jobs continuing after a destination switch, plus UI reachability of all global functions with zero profiles. Audit current-profile actions inside global Settings, Blacklist and Favorite Tags: use an explicit operation-local source where required, or Settings/Profiles for explicit profile editing; never inject a fake default account merely to keep a global page building. Preserve FOSS/donation/premium gating.
- [ ] Run the new adapter/global tests and existing consumers named in the inventory. Commit: `feat(navigation): connect existing global and engine destinations`.

## 10. Finish the legacy-route and source propagation bridge

**Modify:** `lib/core/router.dart`, `lib/core/routers/routes.dart`, `lib/core/navigation/app_navigation.dart`, `navigation_route_catalog.dart`, the helpers inventoried in Tasks 0/9, and existing profile/deep-link/share ingress adapters.

**Create:** `lib/core/navigation/legacy_navigation_bridge.dart`; `test/core/navigation/legacy_links_test.dart`, `route_ownership_test.dart`.

- [ ] Build table-driven tests for every current named route/root path, including `/topic-feeds` and both older aliases. Test cold and warm entry, unknown IDs, null/old payloads, direct profile Favorites and `/?cid=...`. Verify a single shell exists and the source owner is correct after pushing a child.
- [ ] Extract and reuse route page factories; canonical names are destination-prefixed, legacy names remain at ingress aliases. Rebase only approved route templates. Preserve query/path parameters and `extra` types. Audit builder reads of complete `state.uri.path`, `state.name`, root-captured `Ref`, and `parentNavigatorKey` individually.
- [ ] Convert internal `goTo...` implementations to facade calls while preserving caller-facing signatures. Use caller destination + explicit source for child pushes. Sidebar tool selection is `selectDestination`, not a page push through a universal More route. `ref.router` remains the actual application router; do not override it with a per-profile router.
- [ ] For root tasks, carry source explicitly into the overlay when needed. Route observers and returned Futures must still complete on the right Navigator. A source-bound search/artist/comment/editor must not fall back to the root profile if it exits the first widget scope.
- [ ] Audit remaining raw `ref.router.*`, `GoRouter.of`, and `Navigator.of` usages. Keep intended root tasks and harmless local dialogs, document why; adapt every ordinary page switch escaping the shell. Add an explicit source test for each retained bypass with account-sensitive work.
- [ ] Confirm desktop/web browser Back/Forward does not disagree with native hierarchy or show one URL while another destination is active. Never add a second manual browser-history stack.
- [ ] Run the new tests and `test/core/routers/profile_scoped_navigation_test.dart`. Commit: `refactor(navigation): preserve legacy links through explicit route ownership`.

## 11. Add lifecycle, media, structural invalidation and preference migration

**Create:** `lib/core/navigation/destination_activity.dart`; `test/core/navigation/destination_activity_test.dart`, `navigation_invalidation_test.dart`.

**Modify:** `navigation_preferences.dart` created in Task 2, current RouteAware consumers, `lib/core/search/following_topics/src/pages/topic_feeds_page.dart`, relevant PostGrid/media pages, app theme/settings/custom-home consumers, and profile/import completion hooks.

**Interfaces:** `DestinationActivity` exposes selected, foreground, uncovered and current-route signals plus derived active state. `currentDestinationRouteObserverProvider` resolves a navigator-local observer via a scope; it is not the same object attached to every branch. A source-generation service rejects pending results after source revocation. `NavigationPreferences` persists last Favorites ID and collapsed profile IDs; `autoHideMainNavigation` joins real settings. Last Browse reads/writes the legacy current-config ID until the compatibility transition is complete.

- [ ] Add tests for switching away while a feed-initialization request is blocked on a completer, covering a feed with a viewer/root dialog, returning, and going background. Check lease acquisition/release counts, no offstage page fetch loop, no duplicate resume, and no cancellation of unrelated global queued work.
- [ ] Use a distinct observer per navigator and actual destination/page activity. `TickerMode`, focus and semantics exclusion wrap inactive branches; pause native media, stop route-specific timers/prefetch and release wakelocks explicitly. Do not attach a global observer instance to two navigators or rely only on synthetic root events.
- [ ] Reject late results after auth/instance/engine changes. Handle selected-profile deletion through recovery-before-branch-removal. Retain unaffected histories. A revoked remembered Favorites account remains unresolved until deliberate replacement; the matching catalog row/heading may disappear independently.
- [ ] Apply import/restore reconciliation after durable commit and required provider reload. Test successful import, failed rollback, deleted open folder, and same UUID replaced with another instance. Never interpret navigation disposal as authorization for a partial data transaction.
- [ ] Migrate Custom Home at startup only, and disable obsolete bottom/side profile strips in the new shell without erasing unrelated configuration. Add the independent Favorites preference without altering Topic/bookmark storage formats or reverting existing legacy compatibility.
- [ ] Run both new tests and relevant existing lifecycle/import/profile tests. Commit: `fix(navigation): suspend inactive work and invalidate changed sources`.

## 12. Complete bottom controls, selection, viewer and Back integration

**Modify:** `navigation_chrome_controller.dart`, `main_navigation_bar.dart`, `app_navigation_shell.dart`; actual grid/search/viewer toolbar host seams including `lib/core/posts/listing/src/widgets/post_grid.dart`.

**Create:** `test/core/navigation/navigation_interaction_test.dart`.

- [ ] Add controlled scroll tests for the architecture's 24-down/12-up/8-top thresholds, direction changes, overscroll and programmatic position restoration. Assert the post viewport constraints do not change on animation frames and last-row controls remain reachable.
- [ ] Coordinate real bottom search, keyboard, selection footer, page indicators, scroll-to-top and snackbars through one measured inset. Organizational pages do not auto-hide. Honor `autoHideMainNavigation` and reduced motion. Four shortcut items stay in one row, including enlarged text.
- [ ] Connect actual selection controllers and Following selection state to the shell. Back/Escape exits selection first; failed mutations retain it. Disable stale profile-switch/context-menu actions during selection.
- [ ] Keep the viewer inside its source branch; hide compact shortcuts and their clearance for the entire viewer lifetime. Remove viewer Home. A different-destination request normally closes viewer-owned transient routes and the viewer, awaits the transition and branch-cache update, then switches. An ordinary tool's nested page is not popped during switching.
- [ ] Implement Back priority: native IME dismissal, top transient surface, guarded editor, selection, viewer/current child route, then configured startup/Browse fallback at a destination root; leaving the app is not cross-destination history playback. Respect nested PopScopes and predictive Back rather than unconditional `Navigator.pop`.
- [ ] Test no top hamburger anywhere in the migrated pages, no invisible sole navigation trigger, and no duplicate activation through a popup scrim. Test 320-width/200% text and keyboard with real widgets.
- [ ] Run `fvm flutter test --no-pub test/core/navigation/navigation_interaction_test.dart` and the complete new navigation directory. Commit: `feat(navigation): coordinate viewer selection and reading controls`.

## 13. Produce a real review candidate, not another demo

- [ ] Audit each row of the validation matrix. Replace all fixture bodies under the production preview entry with real page adapters. Move useful recording widgets to test fixtures; do not ship `NavigationPreviewCopy` as localization or fictional profiles as runtime capability checks.
- [x] The user has approved activation: retained navigation is the only regular entry, without a define or Dev gate. No routing change may break an incoming link during startup normalization.
- [x] Review the full branch diff against current develop, particularly root service lifetimes, upstream renderer edits, route aliases, dependency changes and missing engine menu entries. Do not include unrelated cleanup or test skips to obtain a pass.
- [x] Format changed Dart paths with FVM, generate only required inputs, analyze the actual changed source/test scope, then run the final commands below. Fix failures and rerun affected checks; a changed runtime candidate needs a new complete pass before integration qualification.

```bash
workers="$(python3 scripts/physical_core_count.py)"
fvm flutter analyze --no-pub --no-fatal-infos lib packages
fvm flutter analyze --no-pub --no-fatal-infos test/core/navigation
fvm flutter test --no-pub --concurrency="$workers" \
  test/core/navigation \
  test/core/routers/profile_scoped_navigation_test.dart \
  test/core/search/following_topics
./scripts/run_regression_tests.sh
review_dir="$(mktemp -d "${TMPDIR:-/tmp}/boorusama-navigation-review.XXXXXX")"
fvm flutter build apk --debug --flavor dev
cp build/app/outputs/flutter-apk/app-dev-debug.apk "$review_dir/"
printf 'Review artifacts: %s\n' "$review_dir"
# On the repository-supported desktop host, build/run its normal target too.
# For Linux, use the repository's existing main target and:
fvm flutter run -d linux
git diff --check
```

- [ ] Read `docs/android_emulator.md` before any emulator operation; acquire the exclusive lease and use Maestro MCP. Use existing signed-in profiles without exposing `.test_credentials`. Test the device journeys in the validation file with the real enabled build, then verify the normal disabled build still starts.
- [ ] Exercise a release/profile build using the existing repository build procedure for performance. A debug APK cannot establish media/memory performance. Record memory after repeated revisits and after opening many distinct destinations; distinguish expected cached pages from continued growth on revisiting the same pages. Do not call this measured if the device/host cannot run it.
- [x] Commit the final scoped changes. Hand a reviewer the exact commit, diff range, commands/results, unresolved failures, remaining platform checks and artifact path. The complete runner covers app, packages/CLI and repository tooling; focused tests and CI do not replace it.

Review-ready means real pages, source isolation and required checks are demonstrated, with any genuinely unavailable platform checks called out. A branch that still uses samples or has unrun native analysis/build is an implementation draft, not the promised review candidate. Merge/release authorization remains separate.

## Handoff summary to the implementing agent

Start with Task 0 and the architecture; do not reopen the chosen A/B/C/More/workspace debate. The latest product decision is shared Favorites and headings only for nonempty remaining tool lists. Work through G1 before migrating features. Preserve current Topic ownership, Default/Undo, source-scoped server actions and global background jobs. Use the existing engine renderers and route helpers where possible, not a new universal page implementation. End with a tested native branch and an honest reviewer handoff, not another HTML-only or sample-only preview.
