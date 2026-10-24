# Navigation corrective review — 19 October 2026

> Historical verification record. The subsequent default-navigation change removes the preview define and old startup path; normal builds now use retained navigation. See [default-navigation handoff](2026-10-19-navigation-default-handoff.md).

This independent review continues `feature/navigation-direct-destinations-preview`
in `.worktrees/navigation-direct-destinations-preview`. No merge, PR, publication,
release, physical-device operation, or profile/credential reset was performed.

## Reviewed baseline and scope

Fetched origin before inspection. Baseline HEAD and origin task branch were
`c9e1ce93ea73314302a7ed5a3a02e068c358b716`; develop, origin/develop, and the merge
base were `d78c0aa09eac22dea9eaede9d5bbf92fe8686c7b`. The original runtime tree was
`bef7ea987`; its enabled APK SHA-256 was
`20fb36181612962cf843185f37e01d63cfe3b613a2c7361fb571e3e055dc6614`.
The primary checkout and unrelated worktrees were preserved.

Verified runtime/test commit: `df2fc193e7c0113c5ed7b9ce3264820af17b25ba`
(`fix: correct retained navigation and search ownership`). The final
documentation-only commit does not change the tested runtime candidate.

Inspected the navigation diff and its consumers: branch identity/reconciliation,
legacy ingress and scoped helpers, root/branch observers, source leases and
Riverpod dependencies, engine catalog/page adapters, search renderers, Following
hierarchy/feed activity, bookmark viewer mutations, selection/scroll chrome,
media suspension, Settings/Export & Import, and the narrow vendored router fork.
Existing engine renderers, bookmark/Topic storage, scheduler policies, codecs,
external contracts, and the router fork were retained.

## Confirmed findings and corrections

| Priority | Finding and evidence | Cause and correction | Regression evidence |
| --- | --- | --- | --- |
| P1 | Browse viewer is restored after it was dismissed; later exits throw `Bad state: Future already completed`. Reproduced on the baseline emulator and in the real-app test. | Switching branches immediately after `maybePop` lets GoRouter retain its pre-pop match list. Wait for normal transient-route completion and the following frame before branch selection. Serialize overlapping selection attempts. | `navigation_viewer_lifecycle_test`: repeated Browse/Bookmarks transitions, Bookmark and Following viewers, public aliases, preserved grids, exactly-once results. Original test failed with `/browse/details` instead of the Browse root. |
| P1 | A viewer with a covering child/dialog was not recognized by a top-route-only check. | Record observed Flutter routes and dismiss owned root popups, branch popups, children above the viewer, and the viewer normally. Preserve ordinary non-viewer histories and honor `PopScope`. Root editor/import pages block a switch instead of being discarded. | Real-app root/local dialog completion, bookmark mutation session exit, and `destination_transient_test` guard/child result assertions. |
| P2 | Startup error was visible above a working timeline. | `appAnnouncementsProvider` read scoped auth without declaring its dependency. Declare `currentReadOnlyBooruConfigAuthProvider`; keep actual error handling. | `announcements/source_scope_test` failed with the Riverpod assertion before the correction; enabled native cold launch has no error panel. |
| P2 | Viewer retained navigation clearance and a redundant Home control. | Track viewer presence independently of immersive controls and route activity. Omit the compact bottom bar and only its injected padding/viewPadding while the viewer, including its owned dialogs, is present. Remove Home; preserve Back and unrelated home APIs. | Shell safe-area tests with real system inset, visible/scroll-hidden chrome, enlarged text, actual viewer lifecycle tests, native portrait/landscape and Back checks. |
| P2 | Following full search had no local profile picker. | Search owns its initial/current config and a keyed renderer; reuse the existing snapshot, engine/query handling, and compact menu. Do not update Browse or Favorites. Drop the originating Topic association after switching. Search owns its own source lease instead of retaining the launch owner's outer lease. | Real-app independent Browse/Favorites state; same-site different accounts and cross-engine source tests assert request auth, exact raw query, draft/selection, suggestions, late-response isolation, safe Follow management, branch retention, and folder Back. |
| P2 | Missing explicit search owner could fall back to another profile. | An unavailable explicit owner renders the existing unavailable-profile state. It cannot silently inherit global Browse. | Canonical Following search ingress with a missing profile produces no SearchPage. |
| P2 | Download Manager destination omitted filter/group parameters accepted by existing routes. | Forward both parameters to the actual gateway page. | Production-router ingress regression asserts `filter=failed` and the explicit group. |
| P2 | Keyboard insets were counted twice by the profile popup. | Let RawAnchor account for system/keyboard insets once; bound scroll height inside the usable overlay viewport. | Geometric assertions at 320/1280 pixels, 200% text and a 300-pixel keyboard inset. The pre-fix menu extended above the screen. |

The startup error was:

```text
Tried to read FutureProvider<List<AppAnnouncement>> from a place where one of
its dependencies were overridden but the provider is not.
... add currentReadOnlyBooruConfigAuthProvider to dependencies ...
riverpod/src/framework/container.dart:452
```

The baseline native completion stack ended in:

```text
_AsyncCompleter.complete
ImperativeRouteMatch.complete (go_router/src/match.dart:462)
GoRouterDelegate._completeRouteMatch (delegate.dart:190)
GoRouterDelegate._handlePopPageWithRouteMatch (delegate.dart:153)
_CustomNavigatorState._handlePopPage (builder.dart:437)
NavigatorState.pop / maybePop
NavigationController.selectDestination (navigation_controller.dart:60)
AppNavigationShell.build.select
```

A sanitized read-only Dart VM snapshot confirmed separate navigator owners:
root = `navigation-shell`; Browse = its namespaced `/details`; Bookmarks = its
namespaced `/bookmarks/group`; Following = its own root. The three branches had
distinct observers/navigators. This supports stale branch restoration, not a
viewer pushed onto the root navigator. No independent shadow history was added.

Baseline Home/foregrounding preserved PID `6563`, main isolate
`6019019053519411`, selected Browse branch index `13`, and the viewer route.
Android Back and foregrounding were also exercised; the exact permanently
unresponsive state was intermittent. Do not equate foregrounding with process
restoration or claim every detail of the original report reproduced identically.

## UI and source decisions

- Browse uses the approved preview's existing `grid_view` glyph.
- Following uses `followingTopicHasNewPostsProvider` and the existing NEW badge
  semantics, without a second counter or a navigation-triggered request. The
  existing all-profile/read-state tests are retained. Merely selecting Following
  does not mark its Topics read.
- Sidebar rows follow the old compact typography/icon spacing with 48-pixel
  minimum targets; collapsible profile headings include their site icon.
  Empty headings/account-only placeholders and duplicated Favorites stay absent.
- Popup width follows content (180–320 pixels, clamped to the viewport), rows
  have 48-pixel minimum targets, duplicate names include host/ordinal context,
  many entries scroll, and existing Kurumi focus/outside-click behavior remains.
- Backups is absent from the sidebar. Settings retains the existing Export &
  Import section (native accessibility label: “Export and Import”). The old
  destination/route, backup implementation, codecs, and data contracts remain.
- Full searches own their profile; mixed-source feeds, Bookmark lists, and
  viewers do not acquire a generic switcher. Wide layouts retain their existing
  sidebar; the requested compact viewer bar and clearance are absent.

## Verification record

Toolchain: FVM Flutter 3.47.2 / Dart 3.13.2. Ordinary test concurrency: six detected
physical cores. No generation was needed for these corrective inputs.

Final `./scripts/run_regression_tests.sh` result: exit 0; 4101 application tests,
1465 package/CLI tests, both repository shell-script suites, and 63 Python tooling
tests passed. The vendored router retains two upstream skips. Package counts in
runner order: booru_clients 102, boorusama_cli 254, cache_manager 59, coreutils 191,
dtext 59, extended_image 47, filename_generator 31, flutter_sqlite3_migration 45,
foundation 65, go_router 436 (2 skipped), i18n_cli 32, kurumi 128, retriable 16.
The final application segment took 5m47s. All 30 changed/new Dart files pass
`fvm dart format --output=none --set-exit-if-changed`; `git diff --check` passes.
This report does not claim all 49 old acceptance cases passed. The
architecture/acceptance documents now supersede contradictory old
viewer, profile-menu, and Backups requirements.

Focused evidence includes the navigation directory, real-app navigation/viewer
flows, scoped announcements, legacy/local profile switching, and cached Following
badges. The first 62-test focused group had one incorrect localized expectation;
the corrected ownership/ingress group passed 7/7, and the visual captures passed
2/2. Original red tests and intermediate logs remain in the local review evidence.

The first complete application run finished 4100 passing / 1 failing: the legacy
browsing test still tapped the deliberately removed Home button. It now asserts
Home is absent and taps the real Back button; its two-test file passes. A following
run was explicitly interrupted to remove the final analyzer-only unused import;
it is not counted as a complete pass. No skipped/relaxed regression assertion was
used to conceal either result.

Analysis command:

```sh
fvm flutter analyze --no-pub --no-fatal-infos lib packages test/core/navigation \
  test/core/announcements/source_scope_test.dart \
  test/core/search/navigation_search_profile_test.dart \
  test/application/navigation_viewer_lifecycle_test.dart \
  test/application/navigation_redesign_flow_test.dart \
  test/application/booru_browsing_flow_test.dart \
  test/application/support/headless_app_harness.dart
```

Result: exit 0, no errors/warnings, 2836 informational diagnostics across this
broad scope. Some test subprocesses emit the Dart VM finalizer diagnostic
“Callbacks into the Dart VM are currently prohibited” while passing; this was
not suppressed. Locale fallback notices also occur. Native logs are checked
separately from host test-process diagnostics.

## Native and artifact evidence

Both exclusively leased emulators are addressed explicitly, with Maestro for UI
control. Package: `com.timberpile.boorusama.dev`, version
`4.6.1-timberpile.1-dev` / code 190. Data-preserving installs retain existing
profiles and credentials. Neither emulator is shut down.

- `emulator-5554`: original enabled baseline preserved for exception/VM evidence;
  corrected cold startup, Browse viewer Back, Bookmark viewer Android Back,
  return to Browse, same-process foregrounding, compact profile menu/outside
  dismissal, sidebar without Backups, Settings Export & Import, and a temporary
  local Topic's full search/picker/return path. The Topic fixture is removed.
  The available three-button overlay was also checked (navigation_mode=0),
  then the original gesture mode (2) restored. A final positive viewer/Share
  warm-resume check retained PID 9495 and Back returned to Browse; a separate
  stop/launch produced PID 10053 and a clean configured Browse startup.
  Offline Following/Bookmarks navigation worked with Wi-Fi and mobile data
  disabled, then both original enabled settings were restored. This does not
  constitute a native uncached request-error/retry check; the complete suite
  includes the controlled network-recovery flows.
- `emulator-5556`: flag-disabled launch first; corrected cold startup and viewer
  portrait/landscape/Back, gesture navigation, system font scale temporarily 2.0,
  profile popup and input-dialog checks. Font scale is restored to its original
  1.0. Native account switching is limited by the preserved one-profile fixture;
  same-site/cross-engine ownership is tested with controlled services.
- Initial native script failures were a post tap before network loading, an
  overly literal `Export & Import` accessibility matcher, a quick-search dialog
  mistaken for a full search, Topic-menu label matching (`Unfollow`), a Home
  matcher that matched Android's three-button system Home control, and
  absence-only viewer checks immediately after a configuration change.
  Final warm-resume and landscape checks require a positively loaded post
  and visible Share control. These failed attempts are not counted as passing
  runs; the corrected flows were rerun successfully.

Final installed base-APK checksums on both emulators match the enabled artifact
below. A final PID-filtered Flutter log scan (5554: PID 10053; 5556: PID 8743)
found zero framework-exception, unhandled-exception, assertion, RenderFlex
overflow, Bad-state, or VM-finalizer markers. This is bounded log evidence,
not an assertion that every possible path is exception-free. Sanitized metadata
is in `build/navigation-review/corrective/evidence/native-final.json`; suite,
analysis, build, reproduction, and focused logs are beside it.

Cleanup exposed one stale Bookmark grid after a successful bulk removal; reopening
the All view showed zero bookmarks. Two subsequent controlled repetitions,
including a Bookmark-viewer round trip before removal, immediately refreshed to
zero without reopening. The one-off observation remains an unreproduced risk,
not a confirmed correction. Temporary local Topics/bookmarks are removed;
profiles, credentials, and pre-existing data are preserved. Both devices finish
with font scale 1.0, gesture mode 2, Wi-Fi/mobile data enabled, and remain running.
The review's temporary ADB forwarding is removed and both exclusive leases are
released after the final checks.

Safe comparisons use real Flutter widgets, loaded fonts/bundled icons, synthetic
profile names, and identical catalogs at 390 logical pixels:
`build/navigation-review/corrective/visuals/comparison.html` (self-contained),
with `before/after-sidebar.png` and `before/after-profile-popup.png` beside it.
The baseline components were read from HEAD, rendered, and restored in a `finally`
block. The fixture catalog is identical for density comparison; production menu
removal is verified separately. No real posts/accounts appear in these captures.

Build/run:

```sh
fvm flutter build apk --no-pub --debug --flavor dev --dart-define=BOORUSAMA_NAVIGATION_PREVIEW=true
fvm flutter run --flavor dev --dart-define=BOORUSAMA_NAVIGATION_PREVIEW=true
```

Enabled APK: `build/navigation-review/corrective/enabled/app-dev-debug.apk`.
Legacy APK: `build/navigation-review/corrective/disabled/app-dev-debug.apk`.

Final SHA-256:

- Enabled: `a2a6c76ed82f2bfea2186a4d8869d12624c1f64ac45ecc0a8fc5185d80552ac4`.
- Disabled: `65d0ccd186358975ff727be58e009398194c81062d8153c97a5a800ae2cc3191`.

Both final builds succeeded; Gradle/Kotlin future-support warnings were retained.
The earlier native runs used the same runtime corrections before removal of an
unused import. Both devices were then reinstalled with the exact final enabled
APK and the cold/viewer/Back checks repeated; emulator-5556 also ran the exact
final disabled APK before returning to enabled.
The second build uses the same command without the navigation define.

## Limits

This is a corrected native review candidate, not a release/merge approval. Native
server mutations, every supported engine/account entitlement, a physical phone,
Linux packaging, exhaustive long-session memory profiling, and every combination
in the original acceptance matrix were not exercised. Source/profile replacement,
media activity, deep links, bookmark Default/membership/Undo and other domain
contracts have automated coverage; that is not a claim of exhaustive live-device
acceptance. No arbitrary real server favorite/upload/delete action was performed.
