# Default navigation handoff — 19 October 2026

The user explicitly requested removal of the old navigation and activation of
retained destinations as the normal application entry. This continues
`feature/navigation-direct-destinations-preview` in its existing isolated
worktree. The primary checkout, remote branches, and physical phone are unchanged.

## Implementation

- Deleted the compile-time preview define/provider and the old router branch.
  Dev and non-Dev startup now construct the same retained destination router.
- Removed the old home/navigation host, sidebar, profile rail, tab controller,
  engine home wrappers, and unused sample prototype. Engine content builders,
  public route aliases, and legacy stored preference decoding remain compatible.
- Removed settings and search entries that controlled the deleted profile rail
  or sidebar. Existing Custom Home values still select startup destinations.
- Migrated old application flows to the actual bottom bar, compact profile picker,
  and Profiles page. Profile reordering has an explicit drag handle, independent
  of its long-press context menu. Prototype-only tests were deleted; their fake
  routing is not application coverage.
- Direct public pushes to a destination root select that destination instead of
  stacking a second shell. Query parameters remain available to the destination.
  Filtered download-manager task details remain children of their opener.
- Preserved lateral system safe areas in landscape. Backup selection hides the
  shared navigation and keeps Export above system insets.
- Source-less mixed posts use an inert generic scope with no credentials or
  explicit account identity. Mixed viewers retain their sheet controller while
  changing presentation profiles. Live source checks still reject removed or
  replaced accounts; search renderers retain their explicit identity keys.
- Shortcut arrows stay in their row while Tab can leave it. The shared Kurumi
  directional action now prefers an aligned visible pane over an unrelated
  diagonal pane; a component regression covers both aligned and fallback cases.
  Empty Favorites recovery offers the existing Profiles destination.

## Verification

Runtime/test candidate: `94713407b` (`feat: make retained navigation the default
and remove legacy hosts`). The subsequent documentation commit does not change
runtime or test inputs. The earlier flag-enabled/disabled reports are historical
evidence only; this candidate was independently rebuilt and checked.

- All changed Dart files formatted with `fvm dart format`; `git diff --check`
  clean. Runtime/test/script searches contain no preview define or enable provider.
- Focused checks include the real application flows, scoped source revocation,
  generic and mixed viewer media/gestures, export selection, narrow/large-text/
  keyboard layouts, profile management gestures, and keyboard traversal. The
  shared directional-focus suite passes all eight tests.
- `fvm flutter analyze --no-pub lib test
  packages/kurumi/lib/src/components/cross_scope_focus.dart
  packages/kurumi/test/directional_focus_test.dart`: zero errors/warnings,
  215 informational lints.
- `./scripts/run_regression_tests.sh` (six physical cores): application suite
  passes 4,083 tests; package/CLI suites pass 1,467 tests (two existing
  upstream go_router skips). Both shell suites pass, and all 63 Python tooling
  tests pass. The complete runner exits zero.
  Discovery runs exposed the regressions described above; they were not reported
  as passes. The final complete run uses the committed runtime/test inputs.

## Native candidate

Built with `fvm flutter build apk --no-pub --debug --flavor dev`, without any
navigation define. Artifact: `build/navigation-review/default/app-dev-debug.apk`.
SHA-256: `0f3f936ef45feafc1b0c7783227dd8dd023fe07ec6ed4d7e9ad6a44db9d5819f`.

Installed with data-preserving `adb -s <serial> install -r` on `emulator-5554`
and `emulator-5556`. The installed base APK hash on each device exactly matches
that artifact. Package: `com.timberpile.boorusama.dev`.

Maestro checks on the final artifact:

- Both devices: ordinary cold launch exposes Browse, Following, Bookmarks, Menu.
- 5554: open a post from Browse; all four shortcuts are absent in the viewer.
  Android Back restores Browse. Bookmarks -> Browse does not restore that closed
  viewer, and the search bar and Menu remain usable.
- 5556: Following opens Following Topics; Bookmarks exposes All; Android Back
  returns to Browse search.

Both leases were released with the final candidate left installed, profiles and
credentials preserved. Native checks cover the Dev APK; non-Dev startup is also
covered by the normal application-shell widget test. No signed production build,
iOS/desktop native qualification, publication, or develop integration was performed.

The test migration keeps the existing persistence, profile ownership, popup,
viewer, keyboard, and backup assertions. Fixtures now register real, unique
profile identities. Keyboard audits exclude covered route scopes and inspect
circular Tab order without assuming the initial focus lies outside a retained
destination.
