# Independently review the rebased export/import branch

Priority: High

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root` with independent Sol High reviewer

Work branch: `feature/backup-sharing-mockup`

## Problem

The export/import branch was rebased over new profile, feed, and pinned-search
changes. Its current Android experience and integration need an independent
review before delivery.

## Expected behavior

The reviewer checks the branch and live Android flow without editing code.
Concrete findings are verified against the approved product behavior and
corrected on this branch.

## Acceptance criteria

- [x] Record the reviewed Git range, device, exercised flows, and limits.
- [x] Classify each finding against current code and product decisions.
- [x] Implement clear accepted fixes with focused regression coverage where
      behavior warrants it.
- [x] Recheck the affected Android UI with Maestro and run relevant automated
      verification.
- [x] Keep the feature branch clean and linear.

## Dependencies

None.

## Review and completion evidence

The independent Sol High reviewer examined `origin/develop` at `3d907c985`
through branch tip `b7baa3035` and exercised the Dev app on Android emulator
`emulator-5556`: custom export selection, nested pinned-search folder,
recommended import actions, credential-free export, file picker, and back
navigation. They found no verified data-loss or credential-exposure issue.
Applying an import, cross-device profile mapping, external file association,
and Apple runtime were outside the exercised flows. The reviewer could not
prove that the initially installed Dev APK matched the reviewed commit; the
implementer rebuilt and reinstalled the branch APK before final UI checks.

Accepted both concrete findings:

- The import review duplicated a selected folder as a heading and action row.
  The action now lives in the expandable folder row. A widget regression test
  checks that the folder label appears once. Maestro confirmed the same for
  `Folder, café` in a custom pinned-search export.
- The import picker advertised loose JSON although the unified importer rejects
  it. It now requests only `.bsexport` and `.zip`. Android DocumentsUI still
  displayed and allowed choosing a JSON file despite that filter, so a second
  extension check rejects it immediately with the existing friendly message.
  Maestro confirmed it remains on Export & import instead of opening Review
  import. The focused file-type test covers accepted and rejected extensions.

The three focused Flutter test files passed (24 tests), and focused Flutter
analysis found no issues. A debug Dev APK built and was exercised with Maestro.
The full test suite was run twice and each time had one failure in the unrelated
bulk-download session resume test due to a disposed ProviderContainer; that
named test passed in isolation. No import was applied and no remote action was
performed. This completion adds one ordinary linear fix commit to the feature
branch; it does not merge or publish it.
