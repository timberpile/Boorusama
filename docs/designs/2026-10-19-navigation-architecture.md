# Direct-destination navigation: production architecture

Status: approved product direction, implementation contract; not a statement that the native migration is complete.

Read the [implementation guide](2026-10-19-navigation-implementation.md) next, then the [acceptance matrix](2026-10-19-navigation-validation.md). These three documents supersede the navigation concept lab and earlier direct-destination proposals wherever they disagree. In particular, shared Favorites is now required, not an optional experiment.

> Corrective review, 19 October 2026: the latest viewer, search-local profile, badge, density, and Export & Import requirements supersede the initial implementation. See [corrective report](2026-10-19-navigation-corrective-review.md) for executed evidence.

## 1. Baseline and scope

Repository: `timberpile/Boorusama`. Continue `feature/navigation-direct-destinations-preview`.

Audited references on 19 October 2026:

| Reference | Commit / version |
| --- | --- |
| `develop` | `d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b` |
| Existing preview branch | `29942277742cee936932aaf5a4035be2a7f18d72` |
| Original native preview | `97e33a638b5de17a08578fe49356a7a8d9f20948` |
| `.fvmrc` | Flutter `3.47.2` |
| Resolved `go_router` in `pubspec.lock` | `17.5.0`, not merely the `^17.0.0` constraint |
| Resolved Flutter Riverpod | `2.6.1`, Git override `5a513c5aeee5a91d7cf5aa9a6e6a414b822bdee9` |

Preserve the later preview build fix. Do not copy an older native-overlay ZIP over this branch. The original prototype and its build records remain available in Git history; they do not qualify a changed candidate.

The goal is a real, reviewable app: existing feature pages inside one retained navigation system. No fake accounts, sample feature bodies, new backend, Favorites aggregation, Topic migration, or replacement bookmark model. The retained navigation is now the only application entry in every flavor. No navigation define or Dev gate is required.

## 2. Locked product contract

### 2.1 Navigation surfaces

Compact layouts have one horizontal row: **Browse / Following / Bookmarks / Menu**. The first three are shortcuts to destinations; Menu is an overlay action, never a fourth destination or a More parent. A secondary destination leaves all three content shortcuts unselected. Reselecting the current shortcut is a no-op, not a refresh, pop-to-root, or scroll-to-top. The no-profile Browse recovery belongs to the Browse shortcut; Favorites recovery is a secondary destination.

There is no sidebar search, no top-bar hamburger, no selectable global profile, no two-column action catalog, and no configurable bottom shortcut slots. The compact catalog has no close X. Its framework drawer retains the historical swipe-area preference and supports opening/closing swipes, Menu toggle, scrim dismissal, Back and Escape.

Use compact presentation below 1000 logical pixels of available shell width. At or above 1000, use a persistent sidebar and omit the bottom bar. This is a starting breakpoint matching the latest interaction study, not a platform check. The wide sidebar includes the three primary destinations as vertical rows because no bottom shortcuts exist there. The compact drawer omits those duplicate rows.

The compact drawer covers only the content above the bottom bar: its scrim must not cover the shortcuts. All four bottom controls remain operable while the drawer is open. Opening it reveals a previously auto-hidden bottom bar. Sidebar rows remain a single vertical list at every width and text scale. Profile groups may be collapsed independently; expansion state survives closing the drawer.

After the wide-only primary rows, order the catalog as profile-specific tools, a divider, general tools, a divider, then Settings, Get support and Donate. Omit dividers for absent sections. Management actions occupy the end of the same scrollable list, as in the former sidebar. The wide sidebar is 240 logical pixels; the compact drawer is at most 280, retaining 48 pixels beside it and the existing 240-pixel minimum. English labels use Blacklist, Favorite Tags, Bulk Download and Download Manager.

### 2.2 Shared Favorites and empty profile groups

Provide one application-level **Favorites** menu entry. It hosts existing engine-specific Favorites pages, one account at a time. Its remembered account is independent of Browse. Do not add Favorites to the fixed bottom row or merge remote Favorites with local Bookmarks.

Build profile groups in this order:

1. Enumerate the profile's engine-advertised secondary tools.
2. Remove tools unavailable under that engine's local capability/account rules.
3. Remove Favorites, which now belongs to the shared entry. Browse is not a secondary tool either.
4. Emit the profile heading only if at least one row remains.

A configured Gelbooru profile with Favorites as its only tool therefore has **no sidebar heading**. It still appears in Browse's picker, and in Favorites' picker when eligible. Do not show empty headings, disabled placeholders, or a special explanatory empty group. If no profile has secondary tools, omit the enclosing site-tools section too. This is independent of whether a heading is currently collapsed.

Render profile sections in stored profile order. Use existing site icons and profile-name/host disambiguation. Within each profile, use stable adapter order. Identical display names are never identity keys.

### 2.3 Complete destination inventory

| Surface | Destinations |
| --- | --- |
| Compact shortcuts / wide primary rows | Browse, Following, Bookmarks |
| Global library/tools section | Favorites; Blacklist; Favorite Tags; Bulk Download; Download Manager |
| Application management | Settings (including Profiles and Export & Import) |
| Assistance | Donate; Get support |
| Profile sections | Remaining available engine tools, such as Danbooru Explore, Pools, Forum, Artists, Profile, Favorite groups, server saved searches, site blacklist; Pixiv Explore; all other existing engine navigation contributions |

Keep Donate/premium eligibility and FOSS conditions unchanged. Get support opens `SettingsPage(scrollTo: 'support')`; Export & Import remains in Settings. The former Backups destination remains a compatibility route only, with no sidebar row. Profiles is the first normal Settings category, embedding the existing management list with its add/update/reorder/duplicate/delete operations and no second toolbar. The old Profiles destination remains a compatibility route only, with no compact or wide sidebar row. Existing backup management and data-transfer contracts remain unchanged. Omit a global Favorites row when there is no eligible account, but retain a valid recovery route for an existing/deep link. Always keep Settings/Profiles and local data management reachable with zero profiles.

A generic app Blacklist is different from a site's blacklist. Favorite Tags, server Favorites, favorite groups, local Bookmarks, local Following, and Pixiv's native following features must retain those distinctions. Do not generalize all similarly named features into one domain.

### 2.4 Browse and Favorites profile menus

Browse has one compact profile-icon button immediately to the right of its search input, not a prominent horizontal selector. It opens a Kurumi anchored context menu with icon, profile name, selected indication, and host disambiguation when needed. Browse lists every configured profile. Favorites uses the same menu component but only eligible Favorites profiles; place its trigger in the Favorites toolbar, not in a fictitious search input.

A bottom-positioned Browse search bar anchors its menu upward when necessary. Clamp menu geometry to usable bounds and keyboard insets, allow vertical scrolling, provide at least 48-logical-pixel targets, consume outside taps, and return focus to the trigger. Arrow keys/Home/End/Enter/Escape operate the menu. Do not fall back to a full-screen profile dialog.

Changing a picker resumes that profile's own destination session. It does not submit, copy, or translate the other profile's draft query. A full search opened from Following keeps that branch history and has the same compact menu, with a search-local profile owner. Switching preserves executed query tokens and draft text without changing Browse, Favorites, or saved Topics. Replacement keyed renderers discard late results from the previous owner. Switching detaches the originating Topic association; the existing profile/query matching rules govern Follow management. Ordinary source-bound pages use a source caption when needed, not an account switcher that silently rebinds the page. Global forms may request a source for that one operation: a Bulk Download draft owns its own profile ID, and a source-less launch requires deliberate choice rather than inheriting last Browse. A launch from a sourced page may prefill its owner/query.

On first Favorites entry, when no selection has ever been made, select the first locally eligible profile in stored order. Merely choosing this read view must not mutate server data. After a remembered account becomes missing or ineligible, do not auto-select another: show recovery and require a deliberate replacement. Preserve the unavailable selection until resolved. The explicit alias for an account targets that account, never the remembered one.

## 3. Identity and state ownership

Use typed immutable IDs in `lib/core/navigation/`; use `equatable`, not translated labels or numeric menu positions.

```dart
enum AppDestination {
  following, bookmarks, blacklist, favoriteTags, bulkDownload,
  downloadManager, profiles, backups, donate, support, settings,
  browseRecovery, favoritesRecovery,
}

// Constructors of a proposed value type, not existing application APIs.
DestinationId.app(AppDestination destination);
DestinationId.browse(String profileId);
DestinationId.favorites(String profileId);
DestinationId.tool(String profileId, String toolId);
```

Use compact JSON arrays as the canonical storage key: `[1,"app","following"]`, `[1,"browse","<profile UUID>"]`, `[1,"favorites","<profile UUID>"]`, or `[1,"tool","<profile UUID>","danbooru.pools"]`. Reject unsupported versions and malformed arity/kinds without throwing into the UI. Preserve the configured UUID as an opaque identity. Do not use raw concatenation with ambiguous separators. `toolId` is namespaced, for example `danbooru.pools`, `pixiv.explore`; it is not an integer index. Shared Favorites is a UI entry resolving to `DestinationId.favorites(profileId)`, not another competing history above those sessions.

Distinguish three kinds of state:

| Kind | Owner and lifetime |
| --- | --- |
| Durable domain state | Existing repositories/notifiers: Topics, folders, bookmarks/memberships, credentials/configs, download jobs, settings. Never copy into navigation state. |
| Destination session | Navigator history, route-local source, scroll controllers, filters, input drafts, loaded content. Created on first visit; retained across normal destination switches in the process. |
| Navigation preferences | Last Browse ID, independent last Favorites ID, collapsed profile IDs, existing sidebar width, auto-hide choice. Small preferences, no post snapshots or secrets. |

Keep `currentBooruConfigId` readable as legacy last-Browse selection during migration. Its old name must not authorize reading a global account elsewhere. Add `lastFavoritesProfileId` separately. Profile editing/reordering must not change destination identity.

**Do not promise complete process-death restoration in this first change.** Store only safe lightweight preferences initially. Keep session state while switching normally; do not silently evict live destination histories in version one. Suspend work and release disposable media/cache resources first. Measure memory after visiting many real destinations. An eviction policy that loses drafts or hierarchy is not an acceptable last-minute fix.

## 4. Routing architecture: one router, many retained destinations

Use the existing `go_router`, with one application `GoRouter` and a `StatefulShellRoute` whose branches represent destination sessions. The number of retained branches is **not** the number of bottom buttons. In particular, do not implement four branches with every secondary page stacked under More; that recreates the rejected UX.

The production path uses `GoRouter.routingConfig` for structural profile changes and a small stable branch registry. Preserve the `GoRouter` object, shell state key, surviving `StatefulShellBranch` objects, branch navigator keys, and route definitions. Update menu labels/availability separately from routing structure. Do not rebuild the router when selected Browse account, theme, unread count, profile name, or login loading state changes.

The pinned 17.5.0 source keeps branch state keyed by branch object and builds branch proxies keyed by that object. Cached keys alone are insufficient if branch objects are regenerated. This design therefore requires executable lifecycle tests before real pages are migrated. See source F1 and implementation Task 2; do not use private go_router classes or internal match-list mutation.

### 4.1 Branch construction and profile changes

Generate pure route definitions for global destinations and registered profile destinations; set `preload: false`. Creating definitions must not construct page widgets, start repositories, fetch current users, or load feed caches. Branch order is stable for its lifetime; sidebar reorder only changes catalog order. New profiles append new branches. Auth/availability changes hide menu entries but retain the existing guarded route definition.

Profile deletion or engine/instance replacement is structural. First revoke the affected session's activity and invalidate pending work. Navigate an affected active session to its recovery destination, then remove obsolete branch objects from routing config. Only dispose an old branch's owned resources after its navigator has unmounted. Other branches and their drafts must remain intact. A same-ID replacement after import is a new source generation; it must not inherit authenticated work merely because the UUID is equal.

Use the custom `StatefulShellRoute.navigatorContainerBuilder` to wrap each supplied branch widget in source/activity/focus policy while retaining keyed children. It must not replace the supplied navigators with a second set of hand-written navigators. Do not create one GoRouter per profile.

### 4.2 Canonical local locations

The new implementation owns one internal namespace:

| Session | Root location |
| --- | --- |
| Global | `/_nav/app/<appDestination>` |
| Browse profile | `/_nav/profile/<profileId>/browse` |
| Favorites profile | `/_nav/profile/<profileId>/favorites` |
| Site tool | `/_nav/profile/<profileId>/tool/<toolId>` |

Use these explicit app wire names, in enum order: `following`, `bookmarks`, `blacklist`, `favorite-tags`, `bulk-download`, `download-manager`, `profiles`, `backups`, `donate`, `support`, `settings`, `browse-recovery`, `favorites-recovery`. Use `Uri`/component encoding and UUIDs. No credentials, account tokens, names, widgets, or controller handles in URLs. Within each branch, register the needed child route families with unique names scoped to its destination key. Common families include search, details, single post, artists/characters, and relevant engine detail pages. Register source-aware page factories once and instantiate route definitions from them; never copy an engine page implementation per branch.

`selectDestination(id)` resumes its branch with `goBranch(index, initialLocation: false)`. It does not call `push` for another destination. `pushPage(request)` opens a contextual child in the caller's branch. A rendered search page can therefore belong to Following, Favorites, or Browse without creating an unrelated Browse history.

A Topic search remains in Following, retains its Topic UUID and explicit owner, and returns to its originating folder. A Favorites search remains in that account's Favorites session. Opening a tool from the catalog is a destination switch. Following a link within that tool is a child-page push unless the action explicitly asks to open a different destination.

### 4.3 Existing route helpers and external entry points

Add a typed navigation facade rather than changing every upstream widget's public API. Preserve existing `goTo...` helper signatures where possible; change their implementation to use the facade when a destination scope is present, with the legacy path available while the old shell remains enabled. New production code uses the facade directly.

A page request carries logical route name/path, untouched domain `extra`, parameters, explicit source where required, and originating destination. Do not wrap all `extra` values in a new envelope: existing builders cast `SearchRouteContext`, `DetailsRouteContext`, records, and maps. Keep those payloads valid. Do not synthesize undocumented `GoRouterState` instances to make legacy builders appear compatible.

Extract reusable page factories from route declarations when necessary; give canonical routes their own unique names. Preserve original names at legacy redirect/entry aliases. A factory reading the original URI path, root-captured `Ref`, or navigator key needs an explicit adapter and regression test; it cannot be blindly cloned. Query strings and typed-tag representation must keep their current parsing rules.

Legacy `/`, `/?cid=...`, `/search`, `/favorites`, `/bookmarks`, `/following-topics`, `/topic-feeds`, `/pinned-searches`, `/following-feeds`, and all current engine URLs remain accepted. Resolve them once at the ingress boundary to a destination and source. An old `cid` link explicitly selects Browse only. Missing owner information may use the documented Browse/Favorites host entry selection, but not an unrelated account for a source-specific tool or mutation. Such tools require explicit recovery.

Native Back operates on the current branch; browser Back/Forward remains chronological. A cold direct link may reconstruct a known folder's parents from stored UUIDs, but cannot reconstruct an in-memory multi-post viewer payload. That case opens a safe source-resolved single-post view or a clear unavailable state. Never force-cast absent `extra`.

The entire shell remains below the existing app-lock boundary; its bottom controls cannot bypass a lock. Root-only transient tasks remain above the shell where necessary: authentication, import/restore conflict/recovery dialogs, platform pickers, and equivalent guarded flows. Ordinary browsing and viewers must not accidentally escape above the shell and lose their only menu. Keep a narrow explicit list of root-task routes, not a default root push for every child.

## 5. Profile scopes, global appearance, and account safety

`CurrentBooruConfigScope` is the compatibility adapter for existing renderers. Introduce a live profile-ID scope above each profile branch navigator. Resolve current config by UUID on each relevant update; build the guarded branch with the full read-only config override. A profile-specific child inside global Following receives its own nested explicit source scope.

Do not rely on wrapping only the first page: pushed children and popup overlays must inherit or explicitly receive the same source. Account-bound actions require the selected post/request owner; there is no fallback to last Browse. Existing `SearchRouteContext.config` and `originatingTopicId`, details payloads, and post origins remain authoritative.

The old read-only providers currently derive from `currentBooruConfigProvider`, and root `ThemeBuilder` reads profile theme configuration. Fix those *consumers*, not just the picker UI. Root chrome and profile-independent pages use application settings. Profile presentation overrides may apply inside explicit content scopes; changing Browse must not recolor/reconfigure Bookmarks, Following, Menu, or another account's Favorites.

Audit Riverpod dependencies under the pinned fork: a parent-created provider is not made local merely by placing its consumer below an override. Use already parameterized auth/config families, or declare and test the necessary scoped dependencies. Do not duplicate global repositories, the mutation coordinator, analytics, downloads, or import recovery in each branch.

A source generation changes on engine/instance replacement, credential identity change, logout, or profile removal. Reject late results for revoked generations, disable stale account actions, and stop issuing requests with revoked credentials. Cached content may remain readable with a warning; it does not authorize an action. No automatic migration to another configured account on the same host. Keep network/account details out of route logging and error fixtures.

## 6. Catalog and upstream boundary

Keep engine builders, repositories, and optional `favoritesPageBuilder` intact. Add fork-local optional navigation adapters rather than a new mandatory abstract method every upstream engine must implement. An adapter advertises stable tool IDs, labels/icons, locally evaluated availability and reusable route/page factories.

A non-null Favorites builder is only one part of eligibility. Combine it with that engine's own account checks. Do not use the prototype's generic `signedIn` flag. Do not subscribe to fetch-on-watch user providers for every profile just to build the catalog. Consume locally parsed credential rules and already available identity metadata; a tool requiring unknown account metadata stays absent until its ordinary identity flow resolves it.

For a new upstream engine, generic Browse and an explicitly supported Favorites adapter should require minimal wiring. New secondary pages still need an adapter and tests. There is no safe automatic extraction of capabilities from arbitrary `mobileMenu` widget trees. In the implementation inventory, every existing engine menu contribution must be mapped, intentionally unified, or explicitly unavailable; never silently lose a page.

Highest upstream overlap remains Home/scaffolds/router/profile selection. Keep patches concentrated there and in route helpers. API parsers and domain repositories should not change solely for this navigation migration. An upstream merge that is textually clean still needs the source-scoping and navigation contract tests.

## 7. Activity, overlays, selection, and media

Define explicit destination and page activity. Work tied to visibility is permitted only when the app is foreground, the destination is selected, the page is the active visible route, and no blocking drawer/root overlay covers it. Mounted/offstage status alone is insufficient. A page under its own viewer is not active even when its branch is selected.

Use one actual `RouteObserver<ModalRoute<dynamic>>` per navigator. Migrate RouteAware consumers to the observer of their navigator; do not attach the same observer instance to multiple navigators. Keep app-level analytics/performance observers without counting inactive branches as visits. Do not infer activity solely from root observer forwarding.

`TopicFeedPage` currently owns feed-initialization interest through RouteAware callbacks. Integrate that lease with destination activity. Release it when leaving/covering the page and reacquire idempotently when appropriate. Keep the existing foreground refresh scheduler global; do not add a scheduler per branch or cancel genuine user-queued download work on a tab switch. Mark-read stays at the existing explicit open/read boundary, not catalog rendering or offstage mounting. Resuming a history view must not discard its update banner or jump to latest posts.

Retained videos, GIFs, timers, scroll-prefetch listeners, and wakelocks must pause/release their visibility work. `TickerMode` and focus exclusion are necessary but do not stop native media or HTTP. Preserve history state while suspending work.

Selection disables unrelated destination/profile actions and swaps the shared bottom area to existing selection actions. Back/Escape first exits selection; failures keep it. Never create a second selection controller disconnected from `PostGrid` or Following's folder selection. Persistent edit pages may retain drafts while switching; transient dialogs block switching or explicitly guard discard. A tab switch must not be implemented as unconditional `maybePop`, which could destroy the very page being retained.

## 8. Chrome and viewer behavior

One shell owns catalog, shortcut bar, and shared bottom clearance; each page owns its actual toolbar/search controls. Inject the Browse profile button beside `HomeSearchBar`/search input and the Favorites button through the existing common Favorites scaffold or a small engine adapter. Avoid double scaffolds with two app bars, two safe areas, or two menu buttons. Keep existing Kurumi menus/toolbars.

Use a measured bottom-area extent shared with page footers, snackbar offsets, page indicators, scroll-to-top controls, selection actions and bottom-positioned search. Do not animate content viewport height. Overlay the bar; reserve a constant trailing scroll inset so the last item is reachable. Layout changes caused by a real width/text/keyboard change are valid; bar animation itself must not cause repeated grid relayout.

Initial scroll policy: on genuine vertical user scrolling in post grids, hide after 24 logical pixels downward and reveal after 12 upward; reveal at top (within 8 logical pixels). Reset accumulation on direction change and ignore subpixel noise, nested/horizontal scrolling, programmatic restore, and overscroll bounce. Use a 160 ms transition or no animation under reduced motion. Organizational lists and forms keep navigation visible. An `autoHideMainNavigation` setting defaults true; false keeps it visible.

The keyboard takes priority: hide main shortcuts while editing; pin the usable search/form controls above the real inset. Restore navigation when the keyboard closes. With no top hamburger, navigating away requires finishing/dismissing input or using existing Back; do not add an invisible edge-only escape mechanism.

The viewer remains in the originating branch. The bottom main-navigation bar is absent for the entire viewer lifetime, including while viewer controls or owned dialogs are visible. Remove its reserved clearance only for the viewer; retain genuine system insets and ordinary grid padding. The redundant viewer Home button is removed; Back returns to the actual origin. Wide layouts retain their existing sidebar. A different-destination request through the facade or a public alias dismisses owned transient surfaces and the viewer through normal Navigator pops, respects guards, awaits route completion and the subsequent GoRouter branch-cache build, and then selects the destination. The observer records Flutter routes, not a competing navigation history. Ordinary non-viewer children remain retained.

Bookmark membership mutations still persist immediately with Undo. The viewer's ordered post snapshot remains stable while its originating grid updates according to existing behavior after exit. Never revive the old prototype's deferred-write model or the obsolete No group category.

## 9. Recovery, migration, and rollout

Preserve Default bookmark identity, group membership rules, Topic UUIDs and source ownership, provenance, refresh caps, cache definitions, legacy import decoders and external share formats. This work changes navigation, not storage identity.

After imports/restores, await existing durable transaction/repository reload boundaries before reconciling open routes. Removed folders fall back to their nearest surviving ancestor or collection root; changed source definitions invalidate only affected sessions. Rollback must not leave navigation displaying half-imported data. Profile removal is allowed while global views remain useful; no-profile startup must not block local bookmarks or data management.

Translate existing Custom Home preferences into a startup destination: default/search to Browse; bookmark to Bookmarks; bulk_download to Bulk Download; engine-specific entries to their explicit tool destination when equivalent, otherwise the existing engine home adapter. Apply only at startup without an incoming explicit link, not on every profile switch. Preserve old preference values for compatibility until the release migration is qualified. The old bottom/side *profile selector placement* must not create a second strip or move the new task bar.

The user authorized removal of the old navigation and activation as the normal app entry. The old router, sidebar/tab hosts, profile rail, and prototype have been removed. Public route aliases and stored preference decoding remain compatible. This local implementation does not authorize a merge, PR, publication, or release.

## 10. Evidence and limitations

Implementation finding (19 October 2026): G1 exposes two pinned-router failures
under structural reconfiguration: nested pushed routes are lost, and cached
branches restore obsolete shell definitions. See the
[implementation checkpoint](2026-10-19-navigation-implementation-report.md#g1-router-compatibility-fix)
for executable regressions and the user-authorized minimal local backport. The stable
branch-object requirement remains necessary but is not sufficient on unmodified
17.5.0. The local 17.5.0 backport resolves both failures in the G1 harness; it is the
explicitly authorized exception to the original no-router-patch constraint.

The normal application now mounts real application destinations. Execution evidence
and unperformed platform checks are recorded in the implementation report; this
design document is not itself a passing acceptance report.

Implementation refinements:

- Existing public page factories are rebased through a central route catalog.
  A small GoRouter subclass normalizes imperative legacy ingress before calling
  public APIs, preserving typed extras that redirects would discard. Direct root
  aliases resume the same retained session; contextual pushes stay in their owner.
- Profile compatibility scopes cover branch Navigators and local overlays. Global
  child source leases revoke old immutable payloads when account/instance identity
  changes. Shared media defaults remain global in the destination shell.
- Root-owned repositories receive source-specific listing settings through an
  auth-keyed adapter. Widget presentation providers have explicit Riverpod scope
  dependencies. This avoids moving repositories into arbitrary widget scopes.
- Analytics/performance observers are separate per Navigator and publish only for
  active destinations. Coverage/activity is independent of Offstage/TickerMode.
- Existing settings hosts implement Settings and Support; the old Backups route remains compatible while Export & Import is reached through Settings.
  Profile management reuses existing mutations. No new persistence/domain format
  or mandatory engine-builder interface was introduced.

Key repository anchors (paths relative to the audited branch):

- `lib/core/router.dart`, `lib/core/navigation/app_navigation.dart`, `lib/core/routers/routes.dart`: current root router and navigation scope.
- `lib/core/navigation/app_navigation_shell.dart`, `lib/core/home/src/pages/entry_page.dart`: navigation chrome and one-time application effects. The old HomePageScaffold and BooruScope were removed.
- `lib/core/configs/manage/src/widgets/booru_selector.dart`: existing profile controls and the current `/?cid=...` jump.
- `lib/core/configs/manage/src/widgets/current_booru_config_scope.dart`, `lib/core/configs/manage/src/providers/current_booru_providers.dart`: read-only compatibility overrides and current global fallbacks.
- `lib/core/themes/theme/src/theme_buider.dart`: actual filename; root profile-theme dependency.
- `lib/core/posts/favorites/src/pages/favorites_page.dart`, `favorite_page_scaffold.dart`; `lib/boorus/gelbooru/gelbooru_builder.dart`, `lib/boorus/gelbooru/favorites/widgets.dart`: existing Favorites host/builder and engine account rules.
- `lib/core/search/search/src/routes/route_utils.dart`, `routes.dart`: typed Topic source context.
- `lib/core/search/following_topics/src/pages/following_topics_page.dart`, `topic_feeds_page.dart`: local folders, Topic opening and feed lifecycle.
- `lib/core/bookmarks/src/pages/bookmark_page.dart`, `bookmark_details_page.dart`, `docs/bookmark_groups.md`: controllers, stable viewer snapshot, Default and Undo contracts.
- `lib/core/posts/listing/src/widgets/post_grid.dart`, `lib/core/home/src/pages/mobile_home_page_scaffold.dart`: selection, footers and lower search integration.
- `test/core/routers/profile_scoped_navigation_test.dart`, `test/core/search/following_topics/following_topic_navigation_test.dart`: useful existing regression entry points.

F1: Flutter-maintained `go_router` 17.5.0 source, reviewed 19 October 2026: https://github.com/flutter/packages/blob/go_router-v17.5.0/packages/go_router/lib/src/route.dart . See branch identity, navigator container, observers and `goBranch`; do not import internal classes.

F2: Flutter-maintained configuration guidance, reviewed 19 October 2026: https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html . Use the pinned package API during implementation, not a silent upgrade to whatever latest documentation describes.

F3: Flutter nested Back handling: https://api.flutter.dev/flutter/widgets/NavigatorPopHandler-class.html . Native predictive Back and nested PopScopes still require device acceptance.
