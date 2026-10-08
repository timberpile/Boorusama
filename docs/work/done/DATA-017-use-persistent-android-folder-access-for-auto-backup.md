# Store automatic backups using persistent Android folder access

Priority: Normal
Affected feature: Auto Backup on Android

## Problem

Auto Backup stores a filesystem path and uses direct file operations. A folder approved in Android's system picker is not used as a persistent document tree. Selected folders can therefore remain unwritable under Scoped Storage despite approval. Recommending Downloads or Documents describes an implementation limitation, not a general Android rule; the shared path validator also accepts Pictures.

The separate manual export fix does not address Auto Backup. Automatic backups must access the selected folder after app/device restarts without another dialog and manage backup files and their manifest there.

## Reproduction

1. On Android 11 or later, select a folder offered by the system in Auto Backup and grant access.
2. Trigger a backup and inspect the destination folder's actual contents.
3. Restart the app/device and check whether automatic backups can still be written.

Direct filesystem access does not guarantee success despite folder approval. Reproduce specific failures and restart behavior during implementation.

## Expected behavior and acceptance criteria

- [x] Android uses the approved document tree with persisted read/write permission. System-blocked destinations remain blocked; the app does not impose a blanket Downloads/Documents restriction.
- [x] Create, read, list, and delete backup files, subfolders, and the manifest through that access. Preserve retention rules and backup contents.
- [x] Automatic backups work after app/device restarts without another picker while permission and the destination remain available.
- [x] Revoked access, unavailable destinations, and write failures never report success. Show a clear localized error and allow folder reselection.
- [x] Handle legacy saved paths safely: require fresh approval before writes/deletions when needed, preserve existing backups, and leave files unchanged on cancellation.
- [x] Explain actual folder approval without claiming a general Android restriction to Downloads/Documents. Preserve other platforms; add no broad storage permission.
- [x] Focused tests cover permission loss, write failures, manifests, and retention. Android validation covers multiple allowed destinations and a restart retaining access.

## Context

- [Export/import design](../../superpowers/specs/2026-10-01-unified-export-import-design.md)
- `lib/core/backups/auto/widgets.dart`, `lib/core/backups/auto/repo_io.dart`
- `lib/core/downloads/path/src/validator.dart` and shared path warnings
- [Android document access and persistent permissions](https://developer.android.com/training/data-storage/shared/documents-files#persist-permissions)

## Decision

2026-10-06: User requested recording this issue for later implementation. Originally unclaimed; no implementation in that session.

## Claim

2026-10-08: Codex implementing at the user's request.
Branch: `agent/data-017-persistent-auto-backup`
Worktree: `.worktrees/data-017-persistent-auto-backup`

## Implementation and verification

2026-10-08: Implementation and focused checks completed. Device acceptance was initially pending; follow-up verification below resolves that gap.

- Rewrote this task in English before implementation.
- Added a native `ACTION_OPEN_DOCUMENT_TREE` picker with persisted read/write
  grants and a dedicated document-tree channel. Store the selected URI in the
  existing location setting; reject legacy filesystem paths before external
  writes or deletions. Cancelling selection leaves settings and files unchanged.
- Create the backup subfolder and perform backup/manifest reads, writes,
  listing, size queries, and retention deletions through `DocumentsContract`.
  Assemble packages in app cache, transfer them through the document resolver,
  validate the destination name and size, remove incomplete transfers, and
  always remove temporary staging files.
- Preserve full export contents, credentials, collision suffixes, and retention
  ordering. Manifest read/parse failures stop the operation instead of resetting
  history. Write and retention failures propagate, so backup time is not advanced.
- Keep startup backup operations alive until completion and retain their failure
  state for the settings screen. Added English/German localized folder guidance
  and errors, replaced the Downloads/Documents warning, and adapted backup
  controls to narrow screens and enlarged text. Other locales use English fallback.
- Other platforms continue using filesystem storage and their existing picker.
  No Android storage permissions were added.

Checks performed:

- `fvm dart format` on changed Dart files.
- `./gen.sh` to initialize missing generated outputs and updated translations.
- Focused Flutter tests: **23 passed** across repository, service, Android channel
  adapter, and layout tests. Coverage includes legacy-path rejection, permission
  failure, manifest round trip/corruption, write/delete failures, retention,
  naming collisions, overlapping backups, staging cleanup, picker cancellation,
  error persistence without advancing backup time, and 320px width at 1x/2x text.
- Focused analysis of the changed backup code and tests: **no issues found**.
- Android dev debug APK build: successful; an earlier build was installed on
  exclusively leased `emulator-5554`, preserving app data.
- `git diff --check`: passed.

## Android verification follow-up

2026-10-08: Verified on exclusively leased `emulator-5554` using Maestro MCP
and the rebuilt native APK. No implementation changes were needed.

- Diagnosed the reported immediate Change error: the inspected installed APK
  lacked `boorusama/auto_backup`. New Dart code requires a complete Android
  rebuild/reinstall when native channels are added; hot reload/restart does not
  load the new Android implementation. On the rebuilt emulator APK, both Select
  and Change open Android's document-tree picker correctly.
- Diagnosed Maestro discovery separately: `emulator-5556` was offline and the
  installed DADB discovery library threw while constructing that transport,
  causing Maestro to omit all Android devices. Normal discovery recovered once
  the stale offline entry disappeared. A fresh standard MCP session was needed
  after reboot because the earlier session retained a dead device connection.
- Android rejects the storage root. Pictures, Documents, and a dedicated
  `Documents/DATA017-validation` subfolder are selectable, grantable, and writable.
- Cancelling Change preserves the selected Pictures URI and existing backups.
- Repeated backups with retention set to two leave exactly the newest two
  `.bsexport` files and matching manifest entries; earlier files are deleted.
- Full emulator reboot followed by app launch preserves the Documents selection
  and grant. Backup Now creates another valid package without any picker or
  grant dialog. This exercises the same AutoBackupService used by automatic
  launches; the calendar scheduling interval was not accelerated.
- Temporarily renaming only the dedicated test folder reproduces an unavailable
  destination: the localized error appears, status says Backup needed, and the
  existing manifest SHA-256 remains unchanged. Restoring and reselecting the
  folder permits another backup and clears the error. Permission revocation and
  write/delete exceptions are covered by the focused tests; actual native grant
  revocation was not successfully exercised on the device.
- Verified packages on the emulator, without transferring payloads: each package
  has nine source parts whose sizes and SHA-256 digests match its manifest, the
  full-backup credential flag is present, and retention manifests match actual
  package files and sizes. Automatic approval rejected a proposed local copy of
  export packages because they can contain credentials; in-place verification
  completed the required integrity checks instead.
- Restored the original retention limit of three and disabled auto backup as it
  was before testing. Retained the clearly named backup fixtures on the emulator
  for reproducibility, stopped the test app, and removed the temporary validator.
  Emulator leases were released after verification.

All acceptance criteria are supported by focused tests, code/build verification,
and the device checks above. No remote publication or branch integration was
performed as part of this follow-up.

## Readable folder location follow-up

2026-10-08: At the user's request, the Auto Backup location now displays a
readable folder path instead of the persisted `content://` URI. Device folders
show paths such as `Documents/My Backups`; removable-storage paths retain the
volume identifier to distinguish destinations. Opaque document-provider IDs use
the provider's folder display name. Missing or unavailable names use a localized
fallback instead of exposing the URI. Existing filesystem paths remain unchanged.

The saved URI and all backup operations remain unchanged. Native folder-name
queries only read the selected folder's metadata and do not create or require a
backup subfolder.

Verification: 25 focused Android-adapter and widget tests passed, including
encoded/nested names, removable storage, opaque provider IDs, unavailable names,
URI preservation for writes, and 320px layouts at 1x/2x text. Affected-scope
analysis, Android dev debug APK build, and `git diff --check` passed. No phone or
emulator operations were performed for this display follow-up.

## Local integration

2026-10-08: User authorized merging into local `develop`. Integrated all three
task commits as one squash commit. Resolved the shared Android activity setup
conflict by retaining the existing GIF channels alongside the backup channel.
Confirmed task contents and existing GIF/feed changes were preserved.

Regenerated translations for the combined inputs. All 34 focused auto-backup
repository, service, Android-adapter, and layout tests passed; affected-scope
analysis, Android dev debug APK build, and `git diff --check` passed. No phone or
emulator operations or remote publication were performed during integration.
