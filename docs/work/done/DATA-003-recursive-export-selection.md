# Add recursive export selection and import recommendation hierarchy

Priority: High

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root`

Work branch: `feature/backup-sharing-mockup`

## Problem

Pinned searches and suggested import actions are displayed as flat lists. This
loses folder and profile context, becomes difficult to scan for large exports,
and would require another redesign if nested folders are added later. The
template dialog and no-op warning state also do not match the approved flow.

## Expected behavior

Export selection and recommendation editing use one arbitrary-depth tree.
Pinned searches retain folder membership, search and feed rows identify their
profile, template saving is a separate two-action dialog, loose JSON imports are
rejected, and import review never presents an empty problem section.

## Acceptance criteria

- [x] Recursive tree selection distinguishes dynamic subtrees from explicitly
  selected current descendants at every level.
- [x] Pinned-search folders and Home expand to their searches; subset exports
  preserve their folder shell.
- [x] Pinned searches and following feeds show their profile context.
- [x] Suggested import behavior mirrors the export hierarchy and remains
  editable per exported item.
- [x] The template dialog uses `Save as template`, `Cancel`, and `Save` only.
- [x] Loose JSON imports are rejected without removing supported archives.
- [x] No-op imports need no warning acknowledgement and show no empty problems.
- [x] Focused tests, analysis, the complete suite, and Android Maestro checks
  are recorded before completion.

## Dependencies

- [Unified export/import implementation](DATA-001-unified-export-import.md)
- [Independent UX review](DATA-002-unified-export-import-ux-review.md)
- [Approved design](../../superpowers/specs/2026-10-02-recursive-export-selection-design.md)

## Completion evidence

- `fvm flutter analyze --no-pub lib/core/backups/export_import lib/core/backups/sources test/core/backups/export_import`: no issues.
- `fvm flutter test --no-pub test/core/backups/export_import`: 149 tests passed.
- `fvm flutter test --no-pub`: 1,659 tests passed.
- `./gen.sh`: completed successfully after the translation changes.
- `fvm flutter build apk --debug --flavor dev --target-platform android-x64`: built `app-dev-debug.apk` successfully.
- `adb -s emulator-5556 install -r build/app/outputs/flutter-apk/app-dev-debug.apk`: installed successfully.
- Maestro on `emulator-5556` verified the recursive pinned-search path
  `Pinned searches` -> `Folder, café` -> `Quoted "title"`, the subdued profile
  label `Donmai Fixture`, the bookmark-group partial label `1 of 2 selected`,
  the explicit `All current` label, and the same hierarchy in Suggested import
  behavior with an editable `Automatic` action.
- Maestro verified that `Save as template` opens a dialog containing only
  `Cancel` and `Save`; saving `Task 6 UI check` returned to Create export and
  made the new template available there.
- `git diff --check`: no whitespace errors.
- `git rev-list --min-parents=2 origin/develop..HEAD`: no merge commits.

## Android limitations

- The emulator fixture contained only one pinned search, so the partial state
  was exercised with the two bookmark groups. Recursive partial and dynamic
  subtree behavior, including `All, including future items`, is covered by the
  focused model and widget tests.
- No safe no-op `.bsexport` file or matching clipboard fixture was available on
  the emulator. The warning-only no-op state and the absence of an empty
  Problems section are covered by the focused import widget and preflight tests.
