# Navigation concepts for Boorusama

**Decision proposal · 9 October 2026**  
**Audited base:** `timberpile/Boorusama` / `develop` / `f4972eb54119fce98360c4c2303bbce375b8e722`  
**Delivery:** interactive HTML exploration only; no Flutter code, application data, or production navigation changed.

[Open the interactive concept lab](mockups/navigation/index.html) · [Review and test instructions](mockups/navigation/README.md)

## Recommendation

Choose **B: task navigation** as the product direction, implemented on a shared, state-preserving app shell. Use the fixed **Browse / Following / Bookmarks / More** task bar on compact screens, an expanded persistent sidebar at tablet/desktop widths, and a drawer on phones. Keep the menu available everywhere. **Existing browsing profiles are displayed as a horizontally scrollable row at the very top of the sidebar; one tap switches the profile without a separate picker dialog.**

**A is the easiest absolute change. B is the best balance of implementation effort and everyday benefit. C is the most powerful parallel-browsing model, but not the best default.** These are design judgments based on the inspected architecture and the prototype journeys, not measured findings from a usability study.

The largest improvement is not moving icons to the bottom. It is letting a person leave a search or nested collection and return to the same location, without confusing a change of destination with a change of site account. Build that foundation once. A can be the low-risk rollout shell; B is a presentation and information-architecture evolution on that foundation, not a second router rewrite.

**Prerequisite:** the separate work item merging pinned searches and feeds into **one Following data model and category must already be merged before this navigation redesign is implemented**. Concept B intentionally prototypes that future state. It does not specify or implement the migration, persistence rules, or polling semantics of the unification itself. Concepts A/C remain historical alternative demonstrations using the old fixtures.

## What is wrong with the current boundary?

The inspected `BooruScope` owns the home scaffold, mobile drawer, optional bottom profile strip, and desktop split view. `EntryPage` selects the engine home using a configuration-keyed builder. `Routes.home` declares other page routes under the entry route, rather than around a persistent stateful navigation shell. This explains why simply adding menu buttons to individual pages would not establish a consistent application-wide navigation boundary. This is a structural reading, not a device reproduction. [S1–S3]

There are already two different axes: **profile/site context** and **application destination**. The audited current sidebar mixes globally stored bookmarks, pins and feeds with engine/account-specific features. The separately planned Following migration will change those two content models before B ships. Danbooru contributes Explore, Pools, Forum, Artists, account Profile, Favorites, Favorite groups, Saved searches, and its blacklist; several depend on authentication. A redesign that shows only a generic feed and bookmarks would silently remove useful functionality. [S4–S5]

Important invariants already exist. Bookmark identity is canonical site plus upstream post identity, not profile ID. Viewer changes may be deferred until the viewer closes. Pins retain an owning profile and opening a pin activates that owner, whereas mixed feed viewing uses source snapshots without switching the globally active profile. Feed overviews may initialize never-attempted sources; individual feeds open from their recent cache. The audited base commit also adds nested bookmark and pinned-search folders. The navigation must preserve all of these distinctions. [S6–S8]

## Three alternatives

### A — Familiar sidebar, available everywhere

**Mental model:** “The app has one menu; every section remains where I left it.”

```text
Global menu
├─ Browse                         [current browsing profile]
├─ Pinned searches                [all owning profiles]
├─ Feeds                          [all source profiles]
├─ Bookmarks                      [all sites]
├─ Current-site tools             [capability/account dependent]
└─ Downloads, settings, support    [application-wide]
```

On phones the menu overlays the active page. It remains available within nested folders and, when controls are visible, from the post viewer. A nested page shows Back at the leading edge and a separate menu button next to it; the two actions never impersonate each other. Root pages have no artificial hierarchical Back button. The native Back policy is described below.

The drawer has clear group headings, a highlighted destination, a profile selector explaining its scope, and distinct names for local versus server collections. Frequently used site functions can appear directly, with the complete feature list one level deeper. Desktop keeps an expanded, scrollable list; compact tablet widths can use the drawer without squeezing all destinations into an icon-only rail.

**Why choose it:** least reclassification of existing features, retains image height, and suits users already comfortable with the sidebar. The common shell still needs substantial correctness work, but there is no new workspace lifecycle or major collection reclassification.

**Why not stop here:** most phone destination changes still require opening the menu and selecting an item. The menu is less self-explanatory than visible destinations; its entry point is also farther from the thumb. Moving from one nested collection to another is easier than today, but not as immediately accessible as B.

The mockup uses the same header profile picker in all concepts for comparison. An A implementation can initially retain the existing profile-selector placement preference; that reduces migration further. A is not a promise to remove that preference.

### B — Four fixed tasks and one unified Following collection (chosen)

**Mental model:** “Browse a site, follow topics, or return to saved things. The profile in the menu chooses the site context, not what belongs to my collections.”

```text
Browse                   Following                       Bookmarks             More
├─ Latest / search       ├─ Followed topics                ├─ All                ├─ Site features
├─ Explore               │  ├─ One or more source queries  ├─ No group           ├─ Favorite tags
└─ Site-specific pages   │  └─ Source profile per query    └─ Folders / groups   ├─ App blacklist
                         └─ Nested Following folders                           └─ Downloads / settings / help

Sidebar / drawer, profile row always pinned at the top
[ Personal · Danbooru ] [ Guest · Danbooru ] [ Sketchbook · Gelbooru ] → horizontal swipe
Navigation: Browse · Following · Bookmarks · More
Danbooru tools: Explore · Pools · Artists · Forum · Site profile · Server favorites ·
               Favorite groups · Server saved searches · Site blacklist (all visible)
App: Downloads · Settings · ...
```

**There are no separate Feeds and Pinned searches subviews or tabs in B.** The preceding unification work item owns the conversion; here a single Following topic can have one or multiple profile-bound sources. Open a topic to see its cached timeline and source chips; an entry may have new content, and nested folders remain available. Following does not silently switch the browsing profile when opening a topic owned by another account. Its content and actions retain each source's ownership. Browse profile switching is an independent choice.

The bottom task bar is **fixed at four destinations in this iteration**. Do not add profile-dependent buttons, per-site substitutions, drag-to-customize, reorder settings or an alternate fifth tab. This keeps positions predictable, especially when switching engines. The current profile is shown in the Browse header; on Following and Bookmarks the global header has no misleading active-profile avatar. Site-related screens can open the sidebar directly from the header.

**Phone scroll behavior:** the bottom bar is visible at rest and at the top of a feed. A deliberate downward scroll slides it out; reversing direction shows it again. Use a short displacement threshold/hysteresis to prevent flickering on jitter. The bar overlays the content instead of changing feed viewport dimensions, so image grids and decoding lists do not rebuild/reflow solely because the bar moves. Selection replaces it with bulk actions; immersive viewer and keyboard layout have their own rules. Reduced-motion setting disables the animation. When returning to a destination, showing it again is a sensible default. Apply this to feed/grid scrolling, not to every modal or small settings list. A platform implementation must test pointer/gesture interplay and safe-area treatment.

**Sidebar profile controls:** present every configured profile as a horizontally swipeable row at the top of the drawer/sidebar, above the navigation and tool entries. Display both the configuration name and site (same-site profiles remain distinct), highlight the active one, allow keyboard focus, and keep the row visible while the vertical list of tools scrolls. A tap changes the browsing/site-tool context immediately **without opening a picker or dismissing the drawer**; a second tap on the intended tool navigates there. If a site tool is already open, switching the profile retains the tool type in the new account context when available; otherwise show a clear unsupported/sign-in state. Following, Bookmarks and their filters remain unchanged by this selection. Adding/managing profiles can remain a separate administrative flow; the routine switch is direct.

**Site tools:** list *every supported profile-specific action directly* in the sidebar beneath the navigation group. Do not insert “Show more,” “All site tools,” or a separate expansion screen. The whole tool list scrolls vertically. The native engine capability registry controls availability; demo entries are illustrative. The More destination still includes these site tools for discoverability and provides app-wide settings/support, but a user who opens the sidebar should not need More or another tap to reach any tool.

At intermediate tablet widths, B chooses a readable persistent sidebar over a cramped icon rail, because a horizontal profile row and a labelled full tool list need enough space. At desktop widths it expands modestly. On phone the list remains in a drawer. Layout selection is based on available width, not the operating system name. [F2]

**Why choose it:** stable one-tap major destinations, easy scanning of every site feature, direct profile switching and a single Following destination. There is no extra workspace concept or configuration prerequisite beyond the already-planned Following unification.

**Trade-offs:** visible bar height at rest, and More may still take two taps for less frequent global actions. A long site-tool list requires vertical scrolling, but that is faster and more predictable than an extra expand tap for this feature count. The expanded tablet sidebar reduces space for the post grid; review it in landscape, split-screen and large text before deciding exact breakpoints.

**Possible later additions, not in this first version:** user-customizable task bar, shortcuts/Jump command, Recent locations, or configurable auto-hide behavior. Profile-specific task-bar items need clear cross-engine semantics and stable fallback positions; do not include them now.

### C — Named workspaces

**Mental model:** “Keep several browsing contexts open and switch among them.”

A workspace captures the current profile and destination histories. It does not copy bookmarks, pins, feed definitions, download jobs, or account credentials. Those remain shared application data. Example spaces are “Browse · Danbooru,” “Quiet worlds,” and “Inspiration.”

Desktop shows an open-space strip above the content. Mobile has a **Spaces** button, the current space name, and a Jump action. The picker previews each space’s site/context and allows explicit creation and closing. The menu still changes destination within the current workspace. A new search does not secretly create another workspace.

The lab lets users keep the current context as a new named space, switch profiles independently, close spaces without closing the last one, and use Ctrl/Cmd+K for a searchable destination/pin/group picker. It limits live demo spaces to six. That is a fixture limit, not evidence that six is the correct production limit.

**Why choose it:** genuinely useful for repeated comparisons across sites or several ongoing searches. Switching an already-open space can restore the exact working context instead of retracing it.

**Why not make it the default:** “profile,” “destination,” and “workspace” are three separate concepts. Users must understand which changes are shared. Naming, duplication, stale targets, closing, memory eviction, durable restore, and deep-link placement become product features of their own. A simple image browser should not require tab management before it feels comfortable.

## Comparison in concrete journeys

The counts below describe visible actions in these designs, not timing measurements. They exclude finding a row in a long list and assume the target already exists.

| Journey on a phone | A | B | C |
|---|---|---|---|
| Browse → previous bookmark location | Menu + Bookmarks: 2 taps | Bookmarks: 1 tap | Spaces + existing bookmark space: 2; otherwise menu route |
| Return to a previous followed folder | Menu + Pins: 2 in A | Following: 1; no subtab | 2 through a prepared space |
| Access a secondary site tool | Menu + tool, or + complete tool list | Browse shortcut or More + tool | Menu/Jump or existing space |
| Compare two independent contexts on desktop | Restore/change context manually | Per-profile state helps; multiple same-profile searches remain sequential | Click an open workspace: 1 |
| Learn before first useful action | Low if familiar with drawers | Low: stable named tasks | Higher: spaces need explanation |
| Incremental engineering beyond shared shell | Lowest | Moderate | Highest |

A is the least expensive path to the original “sidebar everywhere” goal. B removes more everyday navigation friction without inventing a new persistence model. C has a narrower but legitimate advantage; it is not simply “B with nicer tabs.”

## Shared interaction contract

### Scope, profile changes and ownership

Every profile-sensitive header identifies the site and account/configuration name. “Profile” in the picker means a local browsing configuration, not necessarily a signed-in website account. Duplicate names need the existing URL/name disambiguation. Do not rely on the letter D or a favicon alone to distinguish two Danbooru configurations.

A global collection labels its scope as all sites/all profiles. An owner filter is a view preference, not an instruction to activate that profile. In **the audited pre-unification app**, opening a legacy pin deliberately switches to its owner and runs the saved query. **In B after the prerequisite merge**, a Following topic may mix several source profiles; opening it must not change Browse, and opening a post retains its captured source profile, including two accounts on the same site. A missing source appears explicitly rather than silently switching to the current profile. Opening a mixed-source bookmark likewise keeps its source context. Server favorites, votes, notes and other authenticated actions must resolve that source’s configuration, never whatever profile the shell happened to select later. [S6–S7]

Changing profiles restores that profile’s Browse state; it does not recreate the entire library. A missing/deleted owner produces a recoverable unavailable state with an explicit profile choice, rather than running the query against an unrelated account. Account-dependent destinations explain sign-in requirements; unsupported engine capabilities are handled through the registry. The reduced Gelbooru capabilities in the demo are explicitly fixtures, not assertions about real API support.

### Back, reselecting destinations and deep links

Native priority is: dismiss the input method when the platform owns that action; close the top transient menu/dialog; guard dirty forms; exit selection; close the viewer or detail; return to the current branch’s parent. At a root destination, Android Back can return to the configured start destination and then leave the application. It must not endlessly replay previously selected tabs. iOS does not get an Android-style “exit app” command.

Reselecting the current tab **does not reset it**. Breadcrumbs provide explicit movement to ancestors. A viewer opened from a collection returns to that collection’s scroll position. Opening a menu over the viewer is not equivalent to leaving the viewer; pending membership changes must not commit merely because an information sheet closed. [S6]

Browser Back/Forward remains chronological. Root deep links should resolve a stable destination ID, route, owner identity and optional collection/post ID; names and list indices are not durable identifiers. Warm incoming shares should open a controlled root task or correct destination, not build a second shell. Invalid or missing targets have a recovery route. Existing external URLs and route aliases require an explicit compatibility map before Flutter implementation. The lab supports only a small documented set of initial hash routes, not every production deep link.

### The sidebar must remain quick, not another navigation hierarchy

Do not introduce an accordion over site tools. Its vertical list is intentionally scrollable, with the profile row anchored above the scrolling region. Profile changes occur in one tap without a popup, and the drawer remains open. Scroll position in the tools list may stay put during that tap; reopening the drawer starts at the top for fast discovery. On a wide sidebar, keep the row visible when tools scroll and the selected profile accessible by horizontal swipe or keyboard focus. In any engine profile, unsupported tools are hidden or indicated using real capability metadata rather than hard-coded general assumptions.

### Global navigation has deliberate exceptions

“Available everywhere” does not mean two navigation bars above every modal. During selection, the header and bottom area become selection controls; global destinations are withheld until selection ends. Dirty forms require a discard decision. The viewer can be immersive; a tap restores controls, including the menu. Zoom/pan, media swipes and range-selection drags own their respective gesture areas.

A menu’s scrim consumes the dismissing tap. It must not dismiss and open the underlying post in the same gesture. Keyboard focus returns to the invoking control, or a sensible nearby control if it no longer exists. Global menu shortcuts must not fire while typing a query.

Keep the visible menu as the dependable mechanism. Android reserves side edges for system Back; do not stretch a drawer gesture over the whole screen or broadly exclude the system gesture area to force it to win. The HTML’s small edge-swipe demonstration is not validation of Android predictive Back, iOS back swipes, or Flutter’s gesture arena. [F3]

## Impact inventory: what implementation would touch

| Area | Required decision / preservation rule |
|---|---|
| Router and destination definitions | One stable destination registry drives compact navigation, rail, drawer, selected state, shortcuts and deep-link aliases. Preserve engine route builders; do not replace them with generic pages. |
| App shell and global scopes | Lift navigation above ordinary destination pages, but keep downloader, notification/error handling, context-menu overlay and profile resolution alive at the right application boundary. Avoid duplicate app bars/scaffolds/safe-area padding. |
| Profiles and credentials | Key state by configuration ID where account context matters; canonical site/post identity where bookmarks require it. Keep per-source auth, image headers, cookies and cache separation. Never store secrets in route state or workspace serialization. |
| Search and tag entry | Keep exact queries, typed-tag presentation, search suggestions/history, counts and pin/follow actions. Returning restores the query and results position, not a newly submitted search. Search within the current list must be visually distinct from searching the booru. |
| Unified Following and folders | After the separate merge, preserve stable topic/folder IDs, each source profile/query, nested breadcrumbs, subtree NEW, source editing, refresh, selection and import/export entry points. Picker hierarchy must be a tree, not slash-separated flat choices. Do not reproduce legacy Pins/Feeds tabs. |
| Following timeline | Preserve source ownership, NEW semantics, bounded initialization and cached reopening from the final merged model. Older history loads after scrolling; new results must not jump an active session to the top. The navigation ticket follows the merged work item’s polling/persistence decisions; it does not redefine them. [S7] |
| Bookmark groups and folders | All and No group are views, ordered separately from ordinary rows. All is never an assignment target. Folder icon totals represent descendants without double-counting a post in several groups. Keep membership and canonical identity rules. [S6] |
| Selection and action surfaces | Long-press/range drag plus a visible menu entry, no permanent extra selection toggle. Do not select special All/No group rows. Replace sorting/nav with relevant bulk actions. Moving a folder excludes itself and descendants. Preserve production multi-group behavior; the demo’s post Move intentionally replaces membership with one group. |
| Viewer and media lifecycle | Retain ordered snapshot, index, source context, gesture ownership, native video/GIF controls and deferred membership updates. Offstage viewers must not keep animating/decoding solely because navigation retains a branch. |
| Site-specific pages | Preserve Explore, Pools/series, Artists, Forum, account profile, server favorites/groups, server saved searches, site blacklist, uploads and other engine-provided pages. Availability comes from capabilities and auth, not hard-coded Danbooru assumptions. Distinguish local Bookmark from server Favorite in labels/icons. |
| Menus, dialogs and forms | Reuse Kurumi menus and typography, one consistent row style, stable controllers and validation. Escape/Back/outside taps respect dirty drafts. Keep forms usable with keyboard, long titles and large text. Dialog completion is not widget disposal. |
| Downloads and background work | Jobs remain global. Switching spaces or signing into another profile must not silently rebind an existing job’s credentials. Queue badge counts jobs, not unread posts. Keep progress/errors and OS permission flows; never restart work on a shell rebuild. |
| Global tools | Favorite tags, app blacklist, backup/restore, exports, download manager, bulk jobs, support/about, donations and conditional premium/FOSS entries retain reachable homes. Preserve build-flavor conditions. |
| Sharing, import and maintenance | Export filename forms, .bsexport mapping/conflict dialogs, device transfer, restore and restart prompts are root tasks. They may outlive the content branch that launched them. Cancelling navigation is not partial import authorization. |
| Settings and migration | Map custom start/home choices explicitly. Preserve stored view preferences and account identity. B replaces the bottom profile strip with the fixed task bar; profile switching moves to the sidebar top row. Do not add a customization setting in the first release or leave contradictory placement toggles. Refresh controls remain in Settings. |
| Adaptive UI and accessibility | Reflow the same model by usable window width; account for safe areas, landscape, split-screen, folds, keyboard, mouse and RTL. Use labelled targets, focus order, selected semantics, reduced motion and adequate contrast; test actual localization rather than shrinking labels to fit. |
| Lifecycle, cache and recovery | Retain route descriptors/scroll anchors independently of expensive page trees. Cancel or suspend offstage animations/listeners where appropriate. Profile edits/deletion and import replacement invalidate affected context safely. Process death recovery requires deliberate serialization and migration, not an IndexedStack alone. |
| Analytics and tests | Keep route observer events meaningful; avoid logging every dormant branch as a visit or any private query/credential into prototype diagnostics. Add routing, ownership, semantics, profile migration and device acceptance coverage. |

This is a targeted navigation investigation, not a claim that every engine’s complete screen implementation was audited. The integration inventory is deliberately broader than the handful of synthetic pages needed to compare the three shells.

## Implementation approach for B

Use the existing routing stack rather than introducing another navigation package. `StatefulShellRoute.indexedStack` is a candidate for the four stable destination branches; it provides separate branch navigators and restores branch stacks on switching. It does **not** automatically scope Riverpod state by account, preserve process-death state without restoration setup, or stop offstage requests and media. [S9, F1]

Following has **one** root, folder tree and topic timeline. There are no Feeds/Pins subview stacks in B. Model the source bindings inside the already-merged Following records and keep their ownership across navigation. Tests should explicitly assert that there is no legacy tab switch.

Do not create an unbounded live navigator and widget tree for every profile. Maintain a small live set and lightweight per-profile Browse descriptors containing exact query, route ancestry, sort/filter settings and an anchor post ID/offset. If a page is rebuilt after eviction, explain cache/network outcomes rather than claiming instant in-memory restoration. C would add another workspace dimension and needs a stricter memory/restore policy; that is a major reason not to start there.

Use manual Riverpod providers, existing engine capability and config scopes, current Kurumi components, and localized strings through the existing i18n layer. Keep the HTML’s warm review frame out of the app; the inner prototype deliberately uses dark/light surfaces, restrained accent color, recognizable icons and existing collection interaction conventions. It is not a pixel-perfect port of Kurumi.

For large text, do not assume dropping in a NavigationBar solves resizing. Flutter documents that the widget’s own size does not follow `textScaler`. The lab uses a two-row labelled fallback at narrow width with 150% text to avoid clipping. Treat the final native fallback and translated labels as an accessibility acceptance decision; never hide labels merely to pass a width test. [F4]

### Staged rollout, without duplicate architecture

1. Introduce the common shell/destination registry and explicit source-context rules behind a reversible navigation preference. Keep A’s familiar hierarchy as the initial presentation. Add route ownership and Back tests before moving features.
2. Move global collections and site functions into their correct scopes; validate nested return paths, import/export roots, account transitions and media suspension. Keep query/data formats unchanged.
3. **After the Following unification work item has landed**, add B’s fixed four-destination bar and readable adaptive sidebar using the same shell. Present the merged Following root directly, not transitional Pins/Feeds tabs. Move profile switching into the sidebar row and remove contradictory bottom-profile settings. Keep a reversible rollout preference if useful, without duplicating routing implementations.
4. Run release-mode device profiling and usability sessions. Add small power-user accelerators where observed friction remains. Reconsider full C workspaces only if parallel-context use justifies their ongoing complexity.

No effort estimates in days are asserted: that needs a route-by-route implementation spike and a buildable local checkout. Relative risk is more defensible here than invented precision.

## What the HTML lab actually implements

All three concepts have separate in-memory fixtures and share most content surfaces. **B uses unified Following fixtures with nested folders and one/multi-source topics**, including local add/edit/move/read actions; A/C still showcase the former Pin/Feed separation as comparison alternatives. All concepts demonstrate global navigation, profile switching, bookmark folders, selection, viewer operations, simulated transfers, settings and empty/offline/account states. B also demonstrates the fixed hide-on-scroll task bar and horizontal always-visible sidebar profile strip. The HTML does not perform or validate the legacy-to-Following data migration.

Browser Back/Forward restores navigation state but does not roll back application data mutations. Refreshing the document resets everything. Source thumbnails, counts, media badges, timestamps, account states, refresh results and download progress are synthetic. SVG landscapes are generated locally; no image service or external asset is contacted.

**Boundaries:** video playback/decoding, real pagination, native gestures, durable persistence, deep-link registration, network scheduling, authentication, file creation/permissions, actual .bsexport serialization, platform share sheets, backup transactions, detailed forum/comment editing and every engine-specific control are not implemented. Their entries either provide a representative navigation surface or explicitly explain the boundary. Prototype selection/pin-folder operations are illustrative and do not replace the complete production CRUD contract.

## Verification and review

The included Node suite checks **20 model behaviors**. The Chromium suite checks **16 browser journeys**, including 24 concept/window/text combinations at 320, 390, 768 and 1440 pixels, plus light theme and a simulated keyboard-height stress case. It asserts a single B Following destination, source ownership without implicit profile switches, navigation restoration, sidebar profile selection/tool availability, hide/show scrolling without viewport jumps, viewer mutation timing, modal focus/outside taps, dirty-form Back, selection targets and C workspace switching. The isolated run observed zero JavaScript page errors and zero network requests. Screenshots were inspected for phone, drawer, Following and wide layouts.

The keyboard control is a layout stress tool, not an OS input method. Automated overflow checks are not a screen-reader, contrast or accessibility conformance audit. No user study, Android/iOS gesture test, Flutter widget/device test, release performance measurement or process-death restore test has been performed.

**Repository verification is incomplete.** A full checkout could not be obtained in the network-restricted execution environment, and the pinned FVM/Flutter SDK is not installed. Consequently the complete application, package/CLI and repository-tooling suites required by `AGENTS.md` and `docs/engineering_guidelines.md` were not run. Passing the isolated HTML tests does not make a future Flutter implementation production-ready. [S10]

### Usability questions to settle with people

Ask a first-time user to find local bookmarks, run and pin a search, locate the pin later, and explain which site will execute it. Ask an existing user to leave a deeply nested group, inspect a cross-profile pin, return to the same group and distinguish a server favorite from a local bookmark. Ask a heavy user to compare two searches and decide whether switching profile/destination is sufficient or they truly need two independent spaces.

Record wrong destinations, lost-context incidents, mistaken account assumptions, ease of finding a topic in the unified Following view, direct sidebar tool access, and time/taps to completion. Rotate concept order rather than always showing the recommended one first. Include large text, one-handed use, keyboard navigation and a signed-out profile. The recommendation should change if the new Following model proves less discoverable or a large share of real sessions genuinely requires C’s parallel state.

## Sources and audit anchors

Repository links below pin the audited commit, not a moving branch. File reads establish the existing contracts; proposed UX and implementation choices above remain recommendations.

- **S1 — Home scaffold / drawer / profile strip:** [booru_scope.dart](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/lib/core/home/src/widgets/booru_scope.dart)
- **S2 — Engine home and profile-keyed subtree:** [entry_page.dart](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/lib/core/home/src/pages/entry_page.dart)
- **S3 — Root and child routes:** [routes.dart](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/lib/core/routers/routes.dart)
- **S4 — Global sidebar entries:** [side_bar_menu.dart](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/lib/core/home/src/widgets/side_bar_menu.dart)
- **S5 — Engine/account-specific destinations:** [danbooru_home_page.dart](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/lib/boorus/danbooru/home/src/danbooru_home_page.dart)
- **S6 — Bookmark identity and deferred viewer updates:** [bookmark_groups.md](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/docs/bookmark_groups.md)
- **S7 — Pin ownership, refresh/NEW, feeds and cache:** [pinned_searches.md](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/docs/pinned_searches.md), including “Organization and navigation” and later feed-overview initialization/history sections; later sections supersede earlier historical design notes.
- **S8 — Nested collections base:** [audited commit](https://github.com/timberpile/Boorusama/commit/f4972eb54119fce98360c4c2303bbce375b8e722)
- **S9 — Existing packages and constraints:** [pubspec.yaml](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/pubspec.yaml)
- **S10 — Verification contract:** [engineering_guidelines.md](https://github.com/timberpile/Boorusama/blob/f4972eb54119fce98360c4c2303bbce375b8e722/docs/engineering_guidelines.md)
- **F1 — Flutter-maintained go_router:** [StatefulShellRoute documentation](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html), consulted 9 October 2026. Latest docs may describe a newer release than the repository’s ^17.0.0 constraint; check the resolved version before implementation.
- **F2 — Flutter:** [General approach to adaptive apps](https://docs.flutter.dev/ui/adaptive-responsive/general), consulted 9 October 2026.
- **F3 — Android:** [Ensure compatibility with gesture navigation](https://developer.android.com/develop/ui/views/touch-and-input/gestures/gesturenav), consulted 9 October 2026.
- **F4 — Flutter:** [NavigationBar API and text scaling caveat](https://api.flutter.dev/flutter/material/NavigationBar-class.html), consulted 9 October 2026.
