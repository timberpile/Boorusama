# Unify export and import around `.bsexport`

Priority: High

Affected feature: Data export, import, automatic backup, and device transfer

Agent/session: Codex `/root`

Work branch: `feature/backup-sharing-mockup`

## Problem

Backup/restore and source-level import/export currently expose overlapping
flows, standalone JSON files, and a bulk ZIP format. Package import validates
sources before execution but cannot restore all earlier sources when a later
source fails.

## Expected behavior

Boorusama creates only `.bsexport` packages. Full export is the simple personal
backup and includes credentials. Custom exports can share selected collection
items and recommend receiver-controlled update, merge, copy, replace, or skip
actions. Every import is completely planned and checked before data changes,
then applied with durable package-level rollback.

## Acceptance criteria

- [ ] Implement the approved [design](../../superpowers/specs/2026-10-01-unified-export-import-design.md).
- [ ] Follow the task-by-task [implementation plan](../../superpowers/plans/2026-10-01-unified-export-import.md).
- [ ] Use bookmark origin and post ID identity for new exports.
- [ ] Preserve legacy ZIP and JSON import compatibility without creating new
  legacy exports.
- [ ] Verify focused tests, full tests, analysis, archive memory behavior, and
  the Android flow with Maestro.

## Dependencies

The unified post pipeline is already merged. This implementation owns the
bookmark identity migration required by the design.

## Progress

- Approved interaction mockup and architecture are committed at `5348bbe1d`.
- Fresh worktree generation completed and the 1,481-test baseline passed.
