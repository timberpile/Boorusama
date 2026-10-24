# Independent navigation review handoff

Runtime candidate: `bef7ea98789c72c7ce4706068da886752104826e` (complete local
regression suite and both Android debug builds passed; subsequent report-only
commits retain that runtime tree).

Review branch `feature/navigation-direct-destinations-preview` in its existing
isolated worktree. The final candidate and verification outcomes are recorded in
[the implementation report](2026-10-19-navigation-implementation-report.md).
Compare the entire branch with `d78c0aa09`, not only its last commit. Do not merge,
push, publish, create a PR or operate a physical phone without new authorization.

## Read first

- `AGENTS.md`, the applicable verification skill and development workflow.
- Architecture, implementation guide and all 49 validation cases alongside this
  document. The implementation report distinguishes automated evidence from
  incomplete device/platform acceptance; do not infer acceptance from a checkbox.
- `packages/go_router/FORK_NOTES.md`. The user explicitly approved this minimal
  local fix after two independent routing failures. Version remains 17.5.0.

## Architecture to verify independently

The gated entry is `routerProvider` -> `createProductionNavigationRouter`.
One router owns stable, lazy StatefulShellBranches and their actual Navigators.
The shell paints chrome and menu overlay; it does not own another page stack.
Actual engine builders and existing global feature pages form the destinations.

Review `destination_router.dart` with both changed GoRouter methods. Prove that
nested pushes, extras, completion Futures, onExit/PopScopes, active deletion,
auth replacement and successive queued reconfigurations preserve every surviving
branch. Cached route reparsing must not restore an obsolete shell definition.

Review the route catalog's public Page cloning and flattened child paths. Check
all custom Page semantics, route identity, legacy paths/names and query-bearing
ingress. Settings shortcuts may remain contextual children; sidebar Settings,
Backups and Support have independent hosts. Explicit root editors and OS pickers
must retain their source and completion behavior. Browser chronology still needs
an actual supported browser run; widget push/pop evidence is narrower.

Review source propagation from `navigation_facade.dart` through live UUID scopes,
source leases and the unchanged typed extras. Verify same-site/different-account
profiles, Topic and mixed bookmark provenance, artist/comment/editor actions,
late async completions and root sheets. A deleted/replaced source must become
unavailable, never borrow the selected Browse account. The auth-keyed repository
listing-settings adapter exists because root repositories cannot inherit widget
ProviderScopes; inspect all transitive Riverpod scope dependencies and legacy
settings overrides.

Review lifecycle across local pushed pages, raw overlays, root tasks, the global
menu and app background. Feed interests must remain idempotent; downloads and
the mutation coordinator remain global. Inspect native playback initialization,
preload cancellation/restart, wakelock behavior and retained media disposal.
Observers must be distinct per Navigator and inactive branches must not publish
analytics/performance activity. Do not mistake Offstage for inactivity.

## High-priority real application journeys

Use the validation document's eight device journeys after acquiring an emulator
lease. No device was available during implementation. In particular:

1. Independent Browse and Favorites drafts/scroll positions across accounts, with
   the anchored popup at 320 px, 200% text, bottom search and keyboard.
2. A-Pools/detail -> B-Explore -> Following nested folder/Pixiv Topic search ->
   return; inspect actual repository/auth arguments and retained child state.
3. Multi-group bookmark removal and source-group Undo, then leave the viewer via
   the shell. Verify durable membership, fixed viewer order and grid refresh.
4. Native Back priority: IME, popup, guarded dirty edit, selection, viewer/local
   child, destination root fallback. Check predictive Back and desktop Escape.
5. Settings/Backups/Support, native import rollback, profile deletion/replacement,
   account logout and zero-profile operation; no silent account retargeting.
6. Repeated media revisits and many distinct real destinations in a profile or
   release build. Measure memory and active requests. Do not silently evict live
   histories or claim debug/widget timings as native performance evidence.

## Review discipline and evidence

Validate findings before fixing them. Preserve existing verified work and keep
repairs on this task branch. Rerun affected tests; relevant runtime changes
invalidate the prior complete-suite candidate qualification. The full runner
includes application, every test-bearing package (including GoRouter), CLI and
repository tooling. Both flag-on and flag-off native builds matter.

The tests use synthetic identifiers and fake transports. No account credentials
belong in logs, fixtures, screenshots or the handoff. Local APK paths are supplied
in the report. Native installation, live accounts, browser history, accessibility
and long-session memory are separate unperformed checks, not implied passes.

## Artifact and environment summary

Local enabled/disabled APKs and logs: `build/navigation-review/bef7ea987/`.
No emulator/phone was available. Linux compilation was attempted and failed
because `json-glib-1.0` is missing for the FFmpeg plugin. No native device,
browser, Linux-runtime, or long-session memory result may be inferred from the
5558 passing Dart/Flutter tests, 63 Python tests, shell checks or Android builds.
