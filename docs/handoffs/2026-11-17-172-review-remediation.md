# Issue #172 review remediation

Refs #172. Extends `f247bf7a92f4e6b754890ff0a9f6eb3a85cc9a53`.

Every accepted retained diagnostic advances its generation. Directory validation
success and failure obey the same generation/request/path ownership checks.
Old backup completions cannot republish transient errors or restore an earlier
selected folder. Error acceptance uses the generation, including generic errors
whose sanitized diagnostic instances may be identical.

The Android prepare probe retains its unique filename and write/delete sequence.
The extracted production helper makes closing, cleanup and preservation of
existing documents executable in JVM tests; it never selects an existing file.

## Verification

New regressions failed before the corrections for same-category validation
replacement, diagnostic generation and stale backup success/error completion.
Independent review identified the canonical generic-error identity case; that
regression failed with the initial correction and passes with generation checking.
Failed settings-save and diagnostic-stage preservation controls also pass.

```sh
fvm flutter test --no-pub --concurrency=6 test/core/backups/auto_backup_directory_recovery_test.dart test/core/backups/auto_backup_failure_test.dart test/core/backups/auto_backup_android_repository_test.dart test/core/backups/auto_backup_stale_operation_test.dart
```

Final Dart result: **31 passed**. Changed-scope analysis: zero errors/warnings,
2 informational findings. Red/green logs are in
`.worktrees/_artifacts/pre-release-remediation-20261117/172-*.log`.
The cumulative preview report supplies the fresh production Kotlin compilation,
JVM test and debug APK results. No device, emulator, real SAF provider, cloud
backup or live-service acceptance was performed. Android acceptance remains with
the owner; no issue closure or develop integration is implied.
