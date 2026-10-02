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

- Portable bookmark identity, bounded package I/O, source adapters, collection
  actions, profile dependency mapping, complete preflight, and durable rollback
  recovery are implemented.
- Full/custom export, credentials control, local templates, clipboard Base64,
  automatic exports, nearby transfer, legacy import staging, and Android/Apple
  incoming-document bridges all use the unified package flow.
- Focused backup tests passed with 302 tests. The complete Flutter suite passed
  with 1,596 tests. Scoped analysis over every changed production area and
  changed tests completed with no issues; the repository-wide analyzer retains
  only the pre-existing baseline findings on `develop`.
- Android Dev APK build and install succeeded. Maestro verified Full and custom
  selection behavior, template persistence across restart, `.bsexport` save,
  system-picker import, concise preflight, durable apply, and a safe settings
  import reaching “Import complete.”
- File association and incoming-document contracts are covered by Android,
  iOS, and macOS configuration/service tests. Apple runtime validation remains
  unavailable from this Linux workspace.
- Final review identified remaining merge blockers around branch ancestry,
  credential disclosure, payload-selection closure, exact destructive change
  summaries, durable/shared transaction serialization, and nearby navigation.
