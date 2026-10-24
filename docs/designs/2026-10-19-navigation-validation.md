# Navigation migration acceptance and reviewer handoff

Companion to the [architecture](2026-10-19-navigation-architecture.md) and [implementation guide](2026-10-19-navigation-implementation.md). This is a specification of checks to perform, **not an executed test report**. The authoring task changes documentation only. A prior sample-preview test/build pass does not prove any migration check below.

## 1. Shared fixtures and evidence rules

Use real routing, scopes, controllers and feature page code. Fake external repositories/account services/media transports, not the navigation mechanism being tested. Tests must inspect actual source arguments or request counters where ownership matters; correct visible labels alone are insufficient.

Use fixed synthetic UUIDs for:

- Danbooru account A and Danbooru account B on the same site, with the same display name but different account identity.
- A Danbooru guest with no usable account-only tools.
- Gelbooru G with Favorites as its only secondary function.
- Pixiv P with its current supported exploration behavior and a Topic source.
- An unknown/new engine whose basic Browse builder works but which supplies no secondary adapter.

Add a second fixture with twelve configured profiles to exercise long menus without reintroducing sidebar search. Do not commit real `.test_credentials`, real account names, tokens, cookies or private content into tests/screenshots.

Topics must include duplicate profile/query definitions in different folders with distinct UUIDs. A folder feed contains multiple owners and a nested folder. Bookmarks include All, the reserved nil-UUID Default group, two normal groups, a multi-group post, an independent source from another engine and a source whose profile is later removed. Include a paginated list, a dirty edit, a queued download and a late API response blocked by a completer.

Dimensions: 320, 390, 768 and 1280 logical pixels; text scale 100% and 200%; light/dark; portrait and landscape where supported; search top and bottom; with/without a real keyboard inset. Not every pure-model case requires every dimension. Layout/focus cases require both narrow enlarged text and a wide configuration. Use stable keys and semantic labels; assert account UUIDs and concrete operations rather than translated text for identity.

## 2. Catalog and product decisions

| ID | Scenario and observable pass condition | Owner task / test |
| --- | --- | --- |
| C01 | Shared Favorites occurs exactly once; no profile section repeats it. | 1, 6 / catalog + Favorites |
| C02 | Gelbooru G has only Favorites. No G heading is rendered, including after reopening the drawer; G still appears in Browse and eligible Favorites menus. | 1, 6 |
| C03 | A profile's final available tool disappears after logout. Its heading disappears too; collapse state does not keep an empty heading alive. | 1, 4, 11 |
| C04 | Danbooru guest retains its public tools but omits account-only entries. Builder existence alone does not imply eligibility. | 9 / engine adapters |
| C05 | No profiles have secondary tools. The site-tools section/divider is absent, while global destinations remain. | 1, 4 |
| C06 | Every configured profile is offered by Browse, even if it has no tools or Favorites. Favorites offers only eligible profiles. | 5, 6 |
| C07 | Same-name accounts have distinct rows, sources and sessions. Reorder/rename changes presentation, not identity. | 1, 2, 11 |
| C08 | No sidebar search; all sidebar groups/actions remain one column; four bottom controls remain one row. No global selected-profile heading/picker. | 4 / chrome |
| C09 | Blacklist, Favorite Tags, Bulk Download, Download Manager, Donate, Get support and Settings have working entries under their existing build/entitlement rules. Profiles and Export & Import are normal Settings categories; their old standalone destinations remain compatibility ingress only. | 9 / global destinations |
| C10 | Adapter inventory accounts for all existing engine menu contributions. New unknown engine does not crash; no working existing page is silently dropped. | 0, 9 |
| C11 | Opening/expanding the catalog or profile menu makes zero API/page-initialization requests across unvisited accounts. | 1, 6, 9 |

## 3. Navigation and scope

| ID | Scenario and observable pass condition | Owner task / test |
| --- | --- | --- |
| N01 | Menu is an overlay action: location/history stays unchanged. Closing it does not create a More page or extra Back step. | 2, 4 |
| N02 | A-Pools/detail -> B-Explore -> A-Pools preserves detail, draft, filter and scroll anchor. No manual Back-through-More is needed. | 2, 9 |
| N03 | Reselect Browse/Following/Bookmarks while active causes no fetch, pop, scroll reset or duplicate page. | 2, 4 |
| N04 | A secondary tool selects none of the three primary shortcuts. Sidebar highlighting and source caption identify the real target. | 2, 4 |
| N05 | Following folder -> P Topic search -> A Browse -> Following preserves exact query, typed-tag representation and originating Topic UUID on P. | 3, 7 |
| N06 | Every supported Favorites header shows one selected-profile logo after Search (or in its normal action slot when Search is absent). Favorites A -> Favorites B -> Favorites A restores A's position; Browse remains independently selected. Direct account alias and shared entry use the same session. | 6 |
| N07 | Browse account change preserves each draft/executed query independently; no implicit search submission or query translation. | 5 |
| N08 | A Topic/Favorites child search, artist, comment/editor or viewer action uses its actual owner even after a different Browse profile is selected. Assert actual repository/auth arguments. | 3, 10 |
| N09 | Adding a profile while other branches are open preserves surviving branch instances and paths. Renaming/reordering does not rebuild GoRouter or remap by index. | 2 |
| N10 | Legacy names/paths, `/?cid`, Following aliases and direct Favorites links resolve to the right owner/destination with one shell. Unknown IDs/null extras produce recovery rather than unsafe casts. | 10 |
| N11 | Browser Back/Forward is chronological; native Back pops local hierarchy rather than replaying selected destinations. No URL/content divergence. | 2, 10, 12 |
| N12 | Cold single-post links work without a controller payload; multi-post history is not falsely reconstructed. Legacy query and raw syntax stay intact. | 10 |
| N13 | Existing root authentication/import/share/picker flow preserves explicit source and completes its Future once; it cannot acquire a different default account from the shell. | 3, 10 |

## 4. Controls, accessibility and state retention

| ID | Scenario and observable pass condition | Owner task / test |
| --- | --- | --- |
| U01 | Labels are Browse/Following/Bookmarks/Menu. Page-specific full titles may differ. No top hamburger remains on migrated pages or viewer. | 4, 5, 12 |
| U02 | The framework compact drawer keeps historical opening/closing swipes and the swipe-area preference, has no X, and leaves bottom shortcuts visible and interactive. A shortcut tap switches once; scrim click only dismisses and never opens the underlying post. | 4 |
| U03 | Wide layout replaces the bottom bar with one vertical primary list and catalog. Resizing does not recreate active destinations or lose drafts. | 2, 4 |
| U04 | Browse picker is one icon immediately right of the search field. Anchored menu has icon/name/selected state, fits 320/200%, scrolls, and flips above bottom search as needed. | 5 |
| U05 | Profile popup supports arrows/Home/End/Enter/Escape, consumes outside clicks and restores trigger focus. Drawer focus excludes hidden content but includes its operable shortcuts. | 4, 5 |
| U06 | Profile headers collapse independently, retain state on reopen, and are omitted after filtering leaves no tools. No search control is needed to find all twelve-profile fixture sections. | 4 |
| U07 | User scroll 24 down hides, 12 up reveals, near-top reveals. Programmatic restoration, horizontal/nested scroll and overscroll bounce do not toggle the bar. | 12 |
| U08 | Bar animation does not resize/rebuild the grid viewport on each frame. Last item, page controls, snackbar Undo and scroll-to-top stay reachable. | 12 |
| U09 | Keyboard hides navigation while preserving a usable real search/form. Closing keyboard restores it. Selection actions replace main navigation; failed operations retain selection. | 12 |
| U10 | Viewer hides the bottom bar and navigation-only clearance, with visible or immersive controls and owned dialogs. Back returns to origin; Home is absent. Facade/alias destination changes respect guards, complete owned transient routes once, and never restore a completed viewer. Ordinary children retain history. | 8, 12 |
| U11 | Membership removal is durable before viewer exit, Undo is source-group-scoped, viewer order remains fixed, and original grid refreshes after exit. No No group regression. | 8 |
| U12 | Persistent draft survives a destination switch. Closing/discarding a transient edit or leaving a guarded page cannot silently lose edits. Escape/Back does not bypass async guards. | 2, 12 |
| U13 | 48-logical-pixel control targets, usable enlarged labels, selected/expanded semantics, dark/light contrast and reduced motion are checked natively, not assumed from HTML. | 4, 5, 12 |

## 5. Lifecycle, recovery and compatibility

| ID | Scenario and observable pass condition | Owner task / test |
| --- | --- | --- |
| L01 | Hidden destination stops visibility-bound feed initialization/prefetch/media. Repeated enter/leave acquires/releases interests once, without stale work or duplicate startup effects. | 4, 11 |
| L02 | Covered child page is inactive behind its viewer/root modal even though its branch is selected. Restore activity after dismissal, not before route completion. | 11, 12 |
| L03 | App background pauses appropriate route work. Explicit user download jobs and the existing global scheduler keep their independent policies. No scheduler or mutation coordinator is duplicated per destination. | 11 |
| L04 | Each Navigator owns a distinct observer; active analytics/performance events are not multiplied by inactive branches or forwarded twice. | 2, 11 |
| L05 | Root appearance/global grid defaults do not follow Browse/Favorites account changes. Source-specific presentation and credentials still follow the explicit page owner. | 3 |
| L06 | Logout/deleted/replaced profile revokes requests/actions. A late response cannot update the wrong generation. Another account on the same host is never selected as a silent mutation target. | 3, 11 |
| L07 | Missing remembered Favorites account produces deliberate recovery, not selection of the next eligible profile. First-ever entry may choose the first eligible account. | 6, 11 |
| L08 | Import commit/reload reconciles removed folders and changed sources; failed rollback leaves prior usable state. Same UUID with a different instance does not inherit stale credentials/history. | 11 |
| L09 | Zero-profile startup leaves local Bookmarks, Following organization and Settings (including Profiles and Export & Import) reachable. Actions requiring an account request one locally or remain unavailable. | 4, 9, 11 |
| L10 | Startup Custom Home migrates once without duplicate global pages. An explicit incoming link takes precedence. Old profile-position preference does not create another bottom strip. | 5, 11 |
| L11 | Ordinary revisits stop creating duplicate sessions/controllers. Measure many distinct real destinations and media workloads; do not silently evict live histories to conceal memory growth. | 2, 11, 13 |
| L12 | Normal Dev and non-Dev startup uses retained navigation without a define; no old router or prototype remains. No dependency upgrade, Topic/bookmark identity migration or entitlement change is smuggled into the refactor. | 13 |

There are **49 original acceptance cases** above, amended by the corrective review. See [executed corrective evidence and limits](2026-10-19-navigation-corrective-review.md); this matrix is not a claim that all 49 passed. The named test files in the guide are minimum ownership boundaries, not a required test count. Combine related cases when one integration test proves them clearly, but retain this traceability in the final report.

## 6. Native device review journeys

After the automated gate, use the exclusive emulator procedure and Maestro MCP. Do not claim device review from HTML screenshots or widget tests.

1. In Browse, execute a query under A, scroll, open the compact profile popup, switch to B, type a draft, return to A. Check the two independent positions/drafts and inspect popup placement with a bottom search bar and keyboard.
2. Open Following, a nested folder, its RSS feed, and a post. Switch through Menu to A-Pools, then return. Check source-bound viewer actions and feed history/updates behavior; repeat with P as a Topic owner while Browse stays A.
3. Open Favorites, select G, scroll, switch Favorites to A, return to G. Confirm no G profile heading in the sidebar and no change to Browse. Temporarily remove eligibility in a controlled fixture and verify explicit recovery.
4. Use an A-Pools nested page and B-Explore repeatedly through Menu without backing out first. Confirm the secondary page is not labelled as More and the bottom shortcuts are operable under the drawer.
5. Open a multi-group Bookmark in the viewer, remove one membership, immediately inspect Undo, and navigate elsewhere through Menu. Confirm durable state, stable viewer order and correct grid update. Test selection cancellation before navigation.
6. Keep a Bulk Download draft, visit Download Manager, return, then queue a controlled job and switch destinations. Verify the draft is retained and the job does not change owner. Open Settings/Backups/Get support via their real entries.
7. Use large text, landscape and a wide desktop window; inspect focus order, popup clipping, collapse controls, keyboard, pinch/media gestures, predictive Back, native selection drag and reduced motion. Android edge navigation must remain usable without a top hamburger.
8. With fixture data, delete an inactive profile and the selected Favorites profile, restore/import organization changes, and start with zero profiles. Verify safe fallback and no disappearance of global management.

Use development fixtures or needed existing signed-in accounts, never actual destructive operations as a casual UI demonstration. Read-only live endpoints do not replace deterministic failure tests.

## 7. Gates and evidence

**G0 — baseline:** exact branch/worktree, SDK/dependency versions and pre-existing failures recorded. Do not overwrite the preview build fix.

**G1 — routing:** Task 2 source-specific state and structural mutation tests pass using the actual router. Stop feature migration if this boundary is unreliable.

**G2 — source/account correctness:** Tasks 3, 5, 6 and 10 prove actual request owners across engine/account changes, including child/root transitions. Labels alone do not qualify it.

**G3 — feature completeness:** Tasks 7–9 map every existing destination to the real feature page, with no invented generic replacement. No empty headings and all global functions accounted for.

**G4 — interaction/lifecycle:** Tasks 11–12 plus native device journeys demonstrate Back, inactivity, media, keyboard, drawer geometry, selection and stale-source recovery.

**G5 — review candidate:** changed Dart formatted, analysis results reviewed, focused tests passed, `./scripts/run_regression_tests.sh` completed on the candidate, normal builds without a navigation define checked, device/performance/platform limits recorded, and all task changes committed. A successful old baseline build cannot be reused after runtime changes.

A reviewer may still find bugs; that is not permission to omit G1–G5 or call unbuilt source review-ready. Separate implementation readiness, integration qualification, and permission to merge/release. Where a platform is genuinely unavailable, identify the exact unperformed checks; never turn them into passes. The existing repository rules govern whether that remaining scope blocks integration.

## 8. Reviewer handoff template

Use the normal task report; do not add a verification cache or new status subsystem.

```text
Branch:
Candidate commit:
Base develop commit / combined candidate:
Scope: real migrated pages and intentional exclusions
Architecture deviations: decision, reason, affected cases
Route/menu inventory: mapped contributions and retained root-only exceptions
Changed profile/global-state reads: source path and explicit replacement
Acceptance coverage: Cxx/Nxx/Uxx/Lxx -> test/device evidence
Commands actually run: exact command, outcome, skips, environment
Native artifacts: exact local paths; normal build without a navigation define
Device journeys and measured performance: conditions and observations
Unperformed checks / failures / existing baseline issues:
Upstream-sensitive touched files and adapter additions:
Review focus: source leakage, lost history, observer/media lifecycle, imports
Merge/PR/release: not authorized by this guide
```

The acceptance file and implementation guide are written in English to match repository conventions. User-facing UI must use the normal i18n resources. Keep screenshots and logs free of profile secrets and unnecessary personal content.

## Corrective review additions

- Following full-search profile switching preserves the folder return path and query, keeps Browse/Favorites independent, and detaches the old Topic association. Cover same-site accounts, a cross-engine source, delayed old responses, missing owners, and safe Follow management.
- Following shortcuts use the cached all-profile NEW selector; selection does not clear unread state. Check compact/wide, selected/unselected, and enlarged text.
- Profile popup uses compact 48-pixel minimum rows and content width, duplicate-name disambiguation, scrolling, focus restoration and usable bounds with top/bottom anchors and keyboard. Profile headings show site icons; sidebar has no standalone Backups.
- Reproduce stale viewer before hiding shortcuts; separately record warm foregrounding with PID/isolate identity and a fresh process launch.
