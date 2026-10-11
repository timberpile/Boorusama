# Allow longer automatic backup retention

Priority: Normal
Affected feature: Automatic backup settings and retention
Status: In progress
Agent/session: ChatGPT (GitHub connector, 2026-10-09)
Branch: `feature/extended-auto-backup-retention`
Worktree: Not available in the connector environment; changes are isolated on this branch.

## Problem

The **Maximum Backups** selector currently offers only 2, 3, 4, or 5 files. For daily backups, this provides too little recovery history. The backup service already accepts a configurable `maxBackups` count, but the constructor and settings parser also disagree on the default (3 versus 5).

## Expected behavior and acceptance criteria

- [ ] The automatic-backup settings offer **2, 3, 4, 5, 7, 14, 30, 60, and 90** retained backup files, using the existing localized count labels.
- [ ] **30** is the default for new settings and settings records that omit the retention field. Existing valid positive saved values, including legacy values, remain unchanged and can be displayed/edited even when they are not among the standard options.
- [ ] Retention settings round-trip through persistence; changing backup frequency or other settings does not reset retention.
- [ ] A successful backup keeps the newest configured number of files and deletes only older managed backups. Failed exports or manifest failures must not delete backup history. Existing Android Storage Access Framework behavior and desktop paths remain unchanged.
- [ ] Verify the selector on narrow screens and with enlarged text. Cover default and legacy settings, selectable larger limits, and cleanup when the history exceeds 30 files with focused tests.

## Technical context and constraints

- [Settings model](../../../lib/core/backups/auto/types.dart) — `AutoBackupSettings.maxBackups`, parser, and serialization.
- [Settings UI](../../../lib/core/backups/auto/widgets.dart) — `_BackupOptionTile` currently restricts the option list.
- [Retention service](../../../lib/core/backups/auto/service.dart) — already cleans up after successful backup using `settings.maxBackups`; avoid unnecessary rewrite.
- [Service tests](../../../test/core/backups/auto_backup_service_test.dart) and [responsive UI tests](../../../test/core/backups/auto_backup_layout_test.dart).

This is **count-based**, not age-based, retention: 30 daily backups usually represent about a month only when the app actually creates one per day. Retaining more backups increases local storage usage. No grandfather-father-son rotation, storage quota, or new UI flow is in scope.

Dependencies: None.

## Decision

2026-10-09: Expand the existing retention selection instead of introducing a second retention mechanism; use 30 as the new default without overriding explicitly saved values.

## Progress and verification

2026-10-09: Implemented the settings and UI changes, preserving saved positive values, and added focused settings, retention-service, and responsive UI tests on the dedicated feature branch. Verification is incomplete: Flutter/FVM is unavailable in this environment, so neither focused tests nor the complete local test suite have been run. Keep this work item in progress until local checks and acceptance criteria have been verified.
