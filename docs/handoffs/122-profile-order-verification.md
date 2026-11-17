# Profile ordering verification (#122)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/122-profile-reordering`.

Flutter 3.47.2's `onReorderItem` already supplies the final index. The extra
increment skipped downward destinations and rejected a move to the last item.
Pass that index through unchanged. Use one synchronous projection of the stored
order for navigation and profile pickers, including Search, cross-profile lookup,
Favorites Sync (through navigation), Following, links and export/import selection.
The legacy asynchronous ordered provider delegates to the same projection.
Ignore stale/duplicate IDs, append unlisted profiles, and persist the displayed
order on a drag. New profiles retain existing order and append after known IDs.
Repository order, profile identity and active selection remain independent.

## Checks

- `fvm dart format` on all changed Dart files: passed.
- `fvm flutter test --no-pub --concurrency=6 test/application/profile_management_context_menu_flow_test.dart`: 7 passed.
- `fvm flutter test --no-pub --concurrency=6 test/core/configs/profile_order_test.dart`: 1 passed.
- `fvm dart analyze` limited to changed files and the neighboring links directory:
  zero errors, zero warnings, 32 informational lint findings.
- `git diff --check`: passed.

Tests exercise actual final-index callbacks (first-to-last and last-to-first),
persisted settings, stable active selection, real drag/context-menu compatibility,
and stale/duplicate/incomplete order restoration in independent containers.
Fresh-worktree compilation printed a build-hook invalidation message before
successfully running the tests. No interrupted run is counted as a pass.

Not run: full regression suite, emulator/Maestro, live APIs, APK build/install,
Android visual/manual acceptance. Full verification remains required before any
future develop integration. Owner QA: drag three profiles in both directions,
restart and compare Browse/Search/Favorites, Cross-Profile Lookup, Favorites Sync
and export selectors. Confirm adding a profile appends it without changing the
active account. This branch is prepared for owner testing, not merge-ready.
