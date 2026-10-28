# Issue 84 continuation evidence

## Reproduced cause and correction

Runtime candidate: 53468ccee, based on origin/develop 6875e0ce. The earlier nullable SAF-size and safe native diagnostic changes are retained.

Backup Now failed on the leased emulator using a newly selected writable Documents subfolder. A debugger captured only exception classes and source function names: ExportService.createPackage threw StateError before any backup document write. Automatic backup selected the legacy BackupRegistry's topic_feeds descriptor even when exportImportSourcesProvider omitted that adapter because no legacy feeds existed. A provider-level regression reproduced the missing-source failure; ordinary full export used the actual adapter catalog and did not select it.

Full export and automatic backup now share exportSourceCatalogProvider, derived from the actual export/import adapters. Tests exercise both absent and present legacy feeds, real package creation and manifest sizes. This establishes the reproduced emulator cause; the original physical Android 16 report still requires confirmation.

## Executed verification

- fvm flutter test --no-pub --concurrency=6 test/core/backups test/application/backup_restore_flow_test.dart test/core/groups/folder_backup_integration_test.dart: 589 passed.
- ./scripts/run_regression_tests.sh on runtime commit 53468ccee: 4,910 application tests; 1,528 package/CLI tests across 13 complete suites; 72 Python tests; both repository shell suites passed. Two existing go_router skips remain. No suite was omitted or terminated.
- ./gradlew :app:testDevDebugUnitTest --offline: 47 native Android JUnit tests passed, including BackupDocumentSizeTest; zero failures/errors/skips.
- fvm flutter analyze --no-pub lib/core/backups test/core/backups: 75 informational diagnostics; no warnings/errors.
- FVM formatting and git diff --check passed. No generation inputs changed in this fix.
- fvm flutter build apk --debug --flavor dev --target-platform android-x64 --no-pub passed; installed APK SHA-256 matched the local build: 104422a4d4529d29ca5a5e600578f0b8b5ad4e3de129f6ed49c4018144953ad5.
- fvm flutter build apk --debug --flavor dev --target-platform android-arm64 --no-pub passed. Local phone artifact: build/qa/issue84-arm64-debug.apk, SHA-256 b86c277b3413cfb793c7cf1a090304fd808350e7779212e82d6b88be53da546e. The Dev identity permits side-by-side acceptance; do not reset the physical device.

## Emulator evidence and limits

Exclusive serial emulator-5554, Android API 37 (not the reported physical Android 16). Maestro controlled all UI actions; ADB performed targeted installation and file verification. Existing app data was retained. A disposable Boorusama-Issue84-QA folder was created through DocumentsUI and granted through its normal picker.

Automatic backup on restart and Backup Now each produced valid packages. Temporarily renaming only that QA directory caused an access-required failure at check_persisted_permission. The retained diagnostic survived leaving/re-entering the screen. The directory was restored immediately, access reauthorized, and manual retry succeeded; the diagnostic cleared and the UI showed Up to date. Both previous packages remained byte-identical. Three packages passed ZIP CRC, all manifest-part SHA-256 checks and byte-size checks; the backup history contains all three matching entries. Automatic backup was returned to its original disabled preference. The selected QA destination and its three test backups remain available as evidence; no real backup was deleted.

Local screenshots are under build/qa/. Debug exception pausing was restored to None after diagnosis. Any later candidate installation is separate source evidence.

## Remaining acceptance

The user will run the physical Android 16 checks later. The controlled DocumentsProvider and partial-picker gaps have now been closed by actual Android instrumentation; see the [October 25 continuation](continuation-2026-10-25-84.md) for its exact candidate, fresh combined regression and phone APK. The original physical-device acceptance remains open. A restorable-package integrity check is established; a destructive restore into the user's real data was not attempted.

No integration, code publication, issue closure or branch deletion is authorized by this evidence alone. Preserve this branch and phone artifact for the remaining acceptance. An unchanged runtime candidate can reuse its full regression across documentation-only handoffs.
