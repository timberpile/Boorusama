# Navigation implementation and verification report

> Historical verification record. The subsequent default-navigation change removes the preview define and old startup path; normal builds now use retained navigation. See [default-navigation handoff](2026-10-19-navigation-default-handoff.md).

Branch: `feature/navigation-direct-destinations-preview` in
`.worktrees/navigation-direct-destinations-preview`. Base: `d78c0aa09` (local and
origin develop inspected after fetch on 19 October 2026). Original specification:
`877846816`; preview build fix `299422777` remains an ancestor. No merge, push, PR,
release, or physical-device operation is part of this implementation.

## Implemented application

The development preview flag now selects the production application shell with
configured profiles and existing feature widgets. It no longer opens the fictional
navigation demonstration. Flag off retains `Routes.home` and the legacy router.

- One GoRouter owns a lazy `StatefulShellBranch` for each global function, each
  Browse profile, each eligible Favorites profile, and each available engine tool.
  Stable branch objects, Navigator keys and shell Page identity preserve nested
  routes, drafts, grids and returned push Futures. Rename/reorder does not reorder
  the registry. Structural changes reconcile serially, recovering before removal.
- Mobile controls are Browse, Following, Bookmarks and Menu. Menu is an overlay;
  wide layouts use one vertical sidebar. Filtering precedes profile headings.
  The compact anchored Browse/Favorites profile menus preserve independent sessions.
- Real Following folders/feed/edit pages use declared child routes. Topic search
  retains explicit config and Topic UUID. Bookmarks use their existing durable
  membership/Undo pipeline, and leaving a viewer through a destination shortcut
  pops it normally before switching. Ordinary child pages remain retained.
- Global pages include blacklist, favorite tags, bulk downloads, download manager,
  profile management, Settings, Backups, Support and existing donation/premium
  pages under the existing entitlement rules. Profile management reuses add/edit,
  duplicate, delete and reorder operations. Zero-profile startup keeps these local
  management and organization destinations reachable.
- Compatibility scopes resolve live profiles by UUID, propagate all read-only
  config inputs, and keep global appearance independent of Browse. A source lease
  revokes a retained global child when its source credentials/instance change.
  Removed profiles never select another account as a mutation target.
- Existing helper signatures and typed extras are retained through a centralized
  routing facade. Legacy aliases, named routes and single-post links use the same
  router; direct Favorites aliases resume its independent session. Root profile
  editors, changelog/debug and native import/picker flows retain their root role.
- Route-local activity combines selected branch, current child, root coverage,
  drawer coverage and app foreground. Feed interests, media and preload dispatch
  follow it. Pending native playback checks intent again after initialization.
  Global download and mutation services remain outside branch scopes.
- Bottom chrome uses 24-down/12-up/8-top scroll hysteresis, 160 ms/reduced-motion
  transitions, keyboard/selection/viewer coordination and trailing safe-area
  insets. `autoHideMainNavigation` is backward-compatible and defaults true.
  New UI labels use the existing i18n resources (English/German).

## Engineering decisions and upstream seams

### G1 router compatibility fix

Unmodified GoRouter 17.5.0 drops nested imperative matches on route reconfiguration
and restores obsolete shell definitions from cached branches. Both failures were
reproduced by unskipped real-router tests before dependent page migration.
The user explicitly authorized a minimal local router fix. `packages/go_router`
retains 17.5.0, its license and upstream tests; the override changes only two
methods, documented in `packages/go_router/FORK_NOTES.md`:

1. Recursively preserve imperative page keys, extras and completers during reparse
   (also fixed by later upstream 18.0.2).
2. Reparse a cached branch against the current configuration before restoration.

The application uses public routing APIs. It does not mutate private match lists,
maintain a second history, recreate surviving navigators, or upgrade dependencies.
The full vendored package suite passed 436 tests with two unchanged upstream skips
before production integration. The final complete runner includes it again.

### Adapters rather than new feature implementations

`navigation_route_catalog.dart` flattens existing route declarations into namespaced
child routes, retaining public page factories, transitions, payloads and onExit.
`NavigationGoRouter` normalizes imperative legacy ingress before the public call;
redirects alone lose imperative extras. A synchronous alias selects an existing
session; contextual pushes keep their originating branch. Settings/query-bearing
notification ingress carries its existing seed/filter into the real page.

The engine inventory is fork-local and optional; no mandatory BooruBuilder method,
API client, repository interface or domain model was added. Existing repository
settings callbacks now read an auth-keyed listing-settings adapter, since a root
repository cannot inherit a widget ProviderScope. Widget thumbnail/presentation
providers declare their actual Riverpod scope dependencies. Legacy shared-media
settings retain selected-profile behavior; the new shell uses global shared-media
defaults and source-owned page presentation. These small settings seams and route
helper changes are the principal upstream-sensitive edits outside navigation.

Global actions that require a profile use a local choice or explicit payload;
choosing an operation source does not change Browse. Source-less mixed bookmark
viewers rely on existing per-post provenance instead of assigning Browse as owner.
The existing raw dialog/sheet paths remain for transient feature interactions;
they inherit branch scope or explicitly wrap their captured config. Existing
Following raw pushes remain only in the flag-off path. The Danbooru share listener is mounted once above the shell and resolves the
selected profile destination explicitly. Global destinations do not borrow Browse
for uploads; confirmation rechecks that the captured account still exists.

## Engine inventory

| Engine | Existing secondary pages | Local eligibility / special seam |
| --- | --- | --- |
| Danbooru | Explore, Pools, Forum, Artists, Profile, Favorites, Favorite groups, Saved searches, site blacklist | Public first four; login for account tools; Profile additionally needs known user ID. Preserve upload scope. |
| Gelbooru | Favorites | `gelbooruLoginDetailsProvider.hasLogin`; no remaining heading |
| Gelbooru V2 | Favorites | engine login details; no remaining heading |
| Gelbooru V1 | none | generic Browse |
| Moebooru | Popular, Hot, Favorites | first two inline native pages; Favorites requires engine login |
| e621 | Popular, Favorites | Popular inline native page; Favorites requires engine login |
| Anime Pictures | Top, Favorites | Top inline native page; Favorites requires passHash and current-user ID scope |
| Eshuushuu | Profile, Favorites | local login plus userId parsed from extra data |
| Shimmie2 | Extensions, Favorites | Favorites requires resolved capability metadata; do not fetch it for the catalog |
| Szurubooru | Pools, Favorites | Pools public; Favorites requires engine login |
| Hydrus | Favorites | existing engine contribution; no remaining heading |
| Sankaku | Favorites | configured login; no remaining heading |
| Pixiv | Explore | preserve Pixiv native tools under Explore |
| Zerochan, Philomena, Hybooru, Nozomi | none | generic Browse |


The descriptors account for all 17 registered engines. Capability enumeration is
local and does not construct pages or fetch account metadata. Already-known
Danbooru/Shimmie metadata may refine eligibility; visited pages own discovery.
This inventory and descriptor coverage do not constitute live endpoint tests of
all engines. Unknown adapters leave basic Browse available and contribute no tools.

## Verification evidence

Pinned toolchain: FVM Flutter 3.47.2 / Dart 3.13.2; existing Riverpod fork;
GoRouter 17.5.0 with the authorized compatibility fix. Physical-core concurrency: 6.
Fresh ignored outputs were initialized with `./init.sh`; i18n regenerated after
translation changes. No generated source is fabricated or manually patched.

Baseline: 14 legacy preview/profile-navigation tests passed. The pre-fix full app
run passed 4070 and failed exactly the two G1 tests, before package/tooling stages.
The first production full-suite attempt exposed a legacy thumbnail Riverpod scope
dependency assertion and was interrupted after confirming the repeated cause.
It is a failed/incomplete run. The corrected legacy targeted run passed 32 tests. The next full app run
finished with 4090 passed and two failures: a migration fixture missing the new
auth-keyed settings dependency, and flag-off Topic navigation losing its legacy
selected-profile update. Both were corrected without changing their assertions.
A new real-app Back test then found menu priority ahead of a local child; the
shell BackButtonListener correction passes that previously failing test.

Focused commands executed during implementation:

```sh
fvm flutter test --no-pub --concurrency=6 test/core/navigation test/application/navigation_redesign_flow_test.dart test/core/routers/profile_scoped_navigation_test.dart
fvm flutter test --no-pub --concurrency=6 test/downloads/download_metadata_regression_test.dart test/application/search_history_flow_test.dart test/application/navigation_redesign_flow_test.dart
fvm flutter test --no-pub test/core/navigation/source_revocation_test.dart
fvm flutter test --no-pub --concurrency=6 test/core/navigation/navigation_policy_test.dart
```

The combined focused run passed 38 tests before the additional source-revocation
and asynchronous playback tests; those additional files passed separately. Real
application journeys assert retained widget identities, actual fake-transport
request URLs/queries, Favorites independence, viewer exit and zero-profile pages.
They use the existing headless application's fake engine adapter and common real
feature widgets, not live credentials or all engine-specific renderer variants.

Final complete-run, analysis and native-build results are recorded below. Full analysis retains informational lints; vendored upstream parameter
assignments have a package-local style exception documented in FORK_NOTES.md. Do not infer integration qualification from focused results.

## Acceptance traceability

`A` = automated behavior evidence; `P` = partial automated/inventory evidence with
remaining native or broader journey checks. None of the following rows claims a
live account, Android, desktop-browser or memory measurement.

| Case | Evidence and remaining boundary |
| --- | --- |
| C01 | A: catalog unifies Favorites exactly once. |
| C02 | A: favorites-only engine descriptors omit headings. |
| C03 | A: unavailable tools/empty sections filtered; structural auth reset tested. |
| C04 | A: engine capability tests distinguish public and authenticated Danbooru tools. |
| C05 | A: empty profile sections omitted, globals retained. |
| C06 | A: separate Browse and eligible Favorites inputs; zero-profile journey. |
| C07 | A: UUID identity, stored ordering and retained branches. |
| C08 | A: shell layout tests at 320/390/768/1280 and 200% text. |
| C09 | P: actual global page adapters; zero-profile management/Settings/Backups journey. Native interactions remain. |
| C10 | P: all-engine inventory and descriptor tests; live engine rendering remains. |
| C11 | P: pure local descriptor boundary; no live multi-account request tracing. |
| N01 | A: opening/closing drawer leaves router location unchanged. |
| N02 | P: real-router nested draft/identity test; real Pools/Explore device journey remains. |
| N03 | A: branch reselect is a no-op and identity retained. |
| N04 | A: explicit destination identity drives primary/sidebar selection. |
| N05 | P: real Following-owned search retains source/query/page across Browse changes; nested Pixiv/folder device journey remains. |
| N06 | A: real common Favorites scaffold requests both owners and resumes via legacy alias without changing Browse. |
| N07 | P: independent Browse grids and router child drafts; real account search-bar draft/scroll device journey remains. |
| N08 | P: explicit auth overlay test and actual source request assertions; broader engine mutation controls remain for review. |
| N09 | A: add/remove/reset/reorder retain unaffected branch instances and child state. |
| N10 | P: legacy alias matrix, factory registration, guarded malformed payloads and actual Favorites alias; exhaustive external platform links remain. |
| N11 | P: real router push/pop completion and actual Menu/child/root Back hierarchy; browser Back/Forward and predictive Back remain native checks. |
| N12 | P: single-post factory resolves explicit UUID without controller payload; device external launch remains. |
| N13 | P: existing root flows retained and config scopes revalidate; native share/auth/import journeys remain. |
| U01 | A: localized controls and real search profile picker replace the migrated hamburger. |
| U02 | A: drawer scrim ends above interactive primary shortcuts and a shortcut closes it. |
| U03 | P: wide/narrow shell coverage; live resize and all retained forms remain a device check. |
| U04 | A: anchored twelve-profile popup at narrow/wide width, 200% text and keyboard inset. |
| U05 | A: keyboard End/Enter/Escape, focus restoration and hidden-branch focus exclusion. |
| U06 | P: independent persisted collapse IDs and filtered sections; native twelve-section traversal remains. |
| U07 | A: controlled scroll-policy thresholds, bounce/noise and selection coverage. |
| U08 | P: stable viewport with trailing inset; native snackbar/last-row/gesture geometry remains. |
| U09 | P: keyboard/selection bridges and existing application keyboard tests; native failed-selection journey remains. |
| U10 | A: real viewer exits normally when switching and underlying real grid survives; native immersive gestures remain. |
| U11 | P: unchanged durable bookmark membership/Undo subsystem covered by existing tests; combined new-shell viewer journey remains. |
| U12 | P: persistent child draft and guarded normal pop; native dirty-editor/Escape journey remains. |
| U13 | P: widget dimensions/large text/targets; native contrast, semantics and reduced-motion inspection remain. |
| L01 | P: route activity and existing feed-interest tests; blocked real feed initialization across full shell remains for review. |
| L02 | A: real router child/root-cover activity tests. |
| L03 | A: app-background activity and late playback tests; root singleton services retained. |
| L04 | P: distinct observers and active-only analytics/performance gating; production analytics sampling remains. |
| L05 | P: scoped/global provider separation and legacy regressions; visual cross-profile theme comparison remains. |
| L06 | A: branch generation reset and global child source-replacement revocation. |
| L07 | A: explicit/remembered/first-use Favorites recovery policy tests. |
| L08 | P: source-generation reconciliation plus existing import/rollback tests; combined restore/navigation journey remains. |
| L09 | A: actual zero-profile Bookmarks/Following/Profiles/Backups/Settings journey with no post requests. |
| L10 | P: startup Custom Home mapping and legacy placement bypass; platform cold incoming-link precedence remains. |
| L11 | P: retained identities and lazy branches; native long-session memory/media measurements unavailable. |
| L12 | P: real flag-on common page journeys and flag-off regression suite; APK results below. |

## Environment and remaining platform checks

On 19 October, elevated `adb devices -l` returned no devices. The configured SDK
`/home/timber/Android/Sdk` has no emulator executable or emulator package. No
emulator was started, no device lease acquired, and no Maestro/device actions
were performed. No physical phone was operated. Android installation/launch,
predictive Back, live share/IME behavior, native visual/accessibility inspection,
browser chronology, release/profile media performance and retained-memory growth
remain unperformed. A debug build is not performance or runtime-device evidence.

Keep the feature gated pending independent review and these checks. Passing local
tests does not close the native acceptance gate or authorize integration/release.


## Final candidate verification

Checked runtime commit: `bef7ea98789c72c7ce4706068da886752104826e`.
A final origin fetch confirmed both develop refs still at
`d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b`. Subsequent report-only commits do not
change the checked runtime tree. Working tree was clean before native builds.

- `./scripts/run_regression_tests.sh`: **exit 0**. Application **4093 passed**;
  all 13 test-bearing packages/CLIs passed **1465** tests, including GoRouter
  **436 passed / 2 unchanged upstream skips**. Total **5558 Dart/Flutter tests**.
  Both shell policy/release test scripts passed, and Python tooling **63 passed**.
  Log: `/tmp/navigation-regression-final-3.log`.
- `fvm flutter analyze --no-pub --no-fatal-infos lib packages test/core/navigation
  test/application/navigation_redesign_flow_test.dart
  test/migrations/review_regressions_test.dart`: **exit 0**, **no errors or warnings**;
  **2821 informational lints**, predominantly inherited/vendored style findings.
  Log: `/tmp/navigation-analysis-final-3.log`. The vendored lint exception is
  style-only and recorded in `packages/go_router/FORK_NOTES.md`.
- `fvm dart format --output=none --set-exit-if-changed` over the **146 application
  and test Dart files changed since 877846816**: **exit 0**, no changes.
  A broader base comparison also identifies three inherited sample-preview
  formatting differences; those pre-existing files were intentionally preserved.
- `git diff --check` and staged whitespace checks passed.
- Direct comparison against the cached upstream 17.5.0 `lib` directory confirms
  **only two runtime files/methods differ: 11 inserted / 10 removed lines**.
  The global pub cache was not patched.

The two unchanged upstream GoRouter skips are `routing config works with shell
route` and `Obsolete branches in StatefulShellRoute are cleaned up after route
configuration change`. The application's unskipped tests exercise both structural
regression scenarios. No application tests were newly skipped or disabled.


## Native artifacts and execution

Both builds succeeded on runtime commit `bef7ea987`:

```sh
fvm flutter build apk --no-pub --debug --flavor dev --dart-define=BOORUSAMA_NAVIGATION_PREVIEW=true
fvm flutter build apk --no-pub --debug --flavor dev
```

The enabled artifact was copied before running the disabled build. They are local,
ignored build outputs, not published releases:

| Artifact | Path relative to the task worktree | SHA-256 |
| --- | --- | --- |
| Enabled preview | `build/navigation-review/bef7ea987/enabled/app-dev-debug.apk` | `20fb36181612962cf843185f37e01d63cfe3b613a2c7361fb571e3e055dc6614` |
| Flag off | `build/navigation-review/bef7ea987/disabled/app-dev-debug.apk` | `b19c0abaaddc7ec695a08a4779c8f37c848bfdd6dc271ee745f6684bf5253c48` |

Enabled APK metadata checked with Android build-tools `aapt`: package
`com.timberpile.boorusama.dev`, version `4.6.1-timberpile.1-dev` / code `190`,
minimum SDK 24, target SDK 36, ARM64/ARMv7/x86_64. Version was not bumped.
Gradle reported existing AGP/Kotlin future-support and SDK XML compatibility
warnings, but both builds exited 0. These are compilation/artifact checks, not
Android installation or launch evidence.

Desktop command attempted:

```sh
fvm flutter build linux --no-pub --debug --dart-define=BOORUSAMA_NAVIGATION_PREVIEW=true
```

**Exit 1, environmental dependency failure:** CMake cannot find `json-glib-1.0`
required by `ffmpeg_kit_flutter_new_min/linux/CMakeLists.txt:32`. GTK, CMake and
Ninja are available, but this development dependency is missing. No Linux runtime
or desktop-browser acceptance is claimed. The system package set was not modified.

Passed-suite, analyzer, both Android build logs and the failed Linux build log
are copied to `build/navigation-review/bef7ea987/logs/` for local review.

To run the redesign from this worktree after normal dependency initialization:

```sh
fvm flutter run --flavor dev --dart-define=BOORUSAMA_NAVIGATION_PREVIEW=true
```

Omit the define to run legacy navigation. The enabled APK is also available for
manual installation; no device was installed, launched or modified by this task.

## Final disposition

The real application implementation, local regression checks and both Android
artifacts are ready for independent code review. Native journeys, broader live
engine operations, browser chronology, Linux host dependencies, accessibility and
long-session memory/performance remain explicit acceptance limits. This is **not
an integration/release qualification or permission to merge**. Review the full
base-to-branch diff and the [independent handoff](2026-10-19-navigation-review-handoff.md).
Only verification/report documentation changes follow the tested runtime commit.
