# Correct import counts, profile IDs, and Android insets

Priority: High

Affected feature: `feature/backup-sharing-mockup`

Agent/session: Codex `/root`

Work branch: `feature/backup-sharing-mockup`

## Problem

Import preview counts conflate bookmark and group records, pinned searches and
organization updates, and the completion screen uses imperative tense. A full
import can overwrite a profile when portable matching reuses an integer ID
already assigned to another imported profile. Export/import controls can be
covered by three-button navigation, and startup shows recovery text during an
ordinary empty-journal check.

## Expected behavior

Counts identify what will change and completion uses past tense. Every exported
profile survives replacement with a unique destination ID, and preflight
rejects invalid mappings before writes. Export/import screens respect system
insets. Recovery language appears only for an actual pending import.

## Acceptance criteria

- [x] Reproduce and fix profile-ID collision with the reported Safebooru and
      rule34.xxx arrangement, including dependent profile mapping.
- [x] Make category counts accurate and completion tense appropriate.
- [x] Keep export/import controls clear of Android navigation buttons.
- [x] Avoid recovery text on normal startup while preserving interrupted-import
      recovery.
- [x] Add focused regression tests and verify affected Android UI with Maestro.
- [x] Run focused analysis, relevant tests, and the complete test suite; record
      any unrelated failures honestly.

## Completion evidence

- Profile projection and dependency tests reproduce an incoming Rule34 profile
  with ID 0, an incoming Safebooru profile with ID 5, and a local Safebooru
  profile with ID 0. Both profiles retain distinct destination IDs and their
  dependent references resolve to the correct profile.
- Import integrity preflight rejects duplicate exported profile IDs before
  application. Count and startup/UI regressions cover typed preview totals,
  completion tense, normal recovery loading, and a safe-area wrapper.
- `fvm dart analyze lib/core/backups/export_import test/core/backups/export_import`
  reported no issues. `fvm flutter test --no-pub --reporter compact` passed all
  1,933 tests. Dev Android x64 APK built successfully.
- Maestro on `emulator-5554` with three-button navigation opened a new
  `.bsexport` and an existing export for review. Both the Done and Import
  buttons ended at y=2232, above the system navigation area starting at y=2274.
  The import was not applied; private live-data import remains a user retest.

## Dependencies

The unified export/import implementation on this branch.
