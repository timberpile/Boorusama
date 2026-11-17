# Backup folder recovery verification (#172)

Base: `4542aaa44e5002f7d546fb4ec96bf4cb0523cee5`.
Branch: `bug/172-backup-folder-recovery`.

The folder picker previously updated settings without validating the new location
or clearing its stale access warning. A shared recovery controller saves the new
selection through the existing settings queue, then calls the existing repository
prepare operation. Only the same retained access-related failure is cleared after
successful validation. Invalid replacements publish current sanitized diagnostics;
unrelated failures and newer failures remain. Request/revision guards reject old
folder completions and older in-flight backup failures. Cancelled/dismissed pickers
do not start recovery. No backup export is needed to dismiss the stale warning.

Android prepare already checked the persisted URI grant and listed/resolved the
backup directory. Extend it to check directory-create capability and write/delete
a uniquely named probe containing one byte. Existing documents are never selected for
this probe. Failed cleanup is a validation failure. This is actual provider write
validation, not a second permission subsystem; the stage is sanitized like other
backup diagnostics. The native probe has **not been compiled or run on Android**.

Final checks:

- `fvm dart format lib/core/backups/auto/providers.dart lib/core/backups/auto/widgets.dart lib/core/backups/auto/failure.dart lib/core/backups/zip/backup_notifier.dart test/core/backups/auto_backup_directory_recovery_test.dart`: passed.
- `timeout 30s fvm flutter test --no-pub --concurrency=6 test/core/backups/auto_backup_directory_recovery_test.dart test/core/backups/auto_backup_failure_test.dart test/core/backups/auto_backup_android_repository_test.dart`: 23 passed. Valid/invalid replacement, unrelated/newer errors, rapid selections, stale backup reports, sanitized diagnostics and mocked platform contracts.
- `timeout 20s fvm dart analyze lib/core/backups/auto/providers.dart lib/core/backups/auto/widgets.dart lib/core/backups/auto/failure.dart lib/core/backups/zip/backup_notifier.dart test/core/backups/auto_backup_directory_recovery_test.dart`: zero errors/warnings, one informational test lint.
- `git diff --check`: passed.

Earlier fixture/interface and provider dependency failures were corrected. Guarded
startup attempts were interrupted and are not counted as passes. The final short
run above completed on the final Dart candidate; Kotlin received source review
only, including explicit bitmask precedence and probe cleanup review.

Not run: native Kotlin/Android build, APK build/install, emulator/Maestro, actual
SAF picker/providers, real backups/user files, complete regression suite or Android
visual/manual acceptance. Owner QA must cover writable, revoked and read-only
folders (including the deployed provider), picker cancellation, rapid replacement
and an in-flight backup; verify cleanup and warning recovery without creating a
backup. Full develop-integration qualification remains deferred. #173 must wait
for owner acceptance and publication of #172 into develop.
