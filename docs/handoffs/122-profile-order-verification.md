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
- `fvm flutter test --no-pub --concurrency=6 test/application/profile_management_context_menu_flow_test.dart`: 6 passed.
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

## Drag-handle follow-up (2026-11-17)

Owner Android review found that a stationary hold on the drag handle still
opened the profile menu. The menu wrapped the whole ListTile, so its long-press
recognizer received handle pointer events until movement resolved the gesture.
The previous drag regression moved immediately and missed this case.

The keyed row now contains the profile-body Kurumi menu and a separate drag
handle. The handle's entire 48x48 target is hit-testable, including its empty
corners, and is outside the menu recognizer. Existing themed ListTile insets,
title gap, RTL positioning, body editing, menu actions and reorder persistence
are retained. No shared Kurumi API, provider, storage or ordering changes.

Checked state: follow-up to `d3e936887b286b1b76ae74c0eeb15a030891b994`, with
only `profile_management_page.dart`, its existing flow test and this report
changed. The final unchanged Dart candidate is committed with this report;
exact source/replay SHAs are recorded in the preview execution inventory.

- Before fix: `timeout 45s fvm flutter test --no-pub --concurrency=6 test/application/profile_management_context_menu_flow_test.dart --plain-name 'holding the profile drag handle without moving never opens a menu (cancel=false)'` failed as expected: menu visible after a stationary hold.
- `fvm dart format lib/core/navigation/profile_management_page.dart test/application/profile_management_context_menu_flow_test.dart`: passed.
- Final: `timeout 45s fvm flutter test --no-pub --concurrency=6 test/application/profile_management_context_menu_flow_test.dart`: 11 passed. Controlled-clock holds, wobble, release/cancel, held upward/downward drags (including the handle corner), stored order/active profile, normal body editing/long press, desktop handle exclusion/body right-click, keyboard menu and 320px/200% RTL layout.
- `timeout 25s fvm dart analyze lib/core/navigation/profile_management_page.dart test/application/profile_management_context_menu_flow_test.dart`: no issues.
- `git diff --check`: passed.

Durable evidence: `.worktrees/_artifacts/122-drag-handle-followup-20261117/`.
The successful runner also emitted an existing native finalizer diagnostic;
no test failed. Not performed: Android/emulator/Maestro, live services, APK
build/install or full regression suite. Owner acceptance: hold the handle well
past the long-press threshold, release or begin dragging, then compare a normal
profile-body long press. The handle must never open a menu or edit the profile.
#166 is deferred and unchanged by this follow-up. No develop integration, issue
closure, PR or branch deletion is authorized.
