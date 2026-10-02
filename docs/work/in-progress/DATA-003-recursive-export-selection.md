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

- [ ] Recursive tree selection distinguishes dynamic subtrees from explicitly
  selected current descendants at every level.
- [ ] Pinned-search folders and Home expand to their searches; subset exports
  preserve their folder shell.
- [ ] Pinned searches and following feeds show their profile context.
- [ ] Suggested import behavior mirrors the export hierarchy and remains
  editable per exported item.
- [ ] The template dialog uses `Save as template`, `Cancel`, and `Save` only.
- [ ] Loose JSON imports are rejected without removing supported archives.
- [ ] No-op imports need no warning acknowledgement and show no empty problems.
- [ ] Focused tests, analysis, the complete suite, and Android Maestro checks
  are recorded before completion.

## Dependencies

- [Unified export/import implementation](../done/DATA-001-unified-export-import.md)
- [Independent UX review](../done/DATA-002-unified-export-import-ux-review.md)
- [Approved design](../../superpowers/specs/2026-10-02-recursive-export-selection-design.md)
