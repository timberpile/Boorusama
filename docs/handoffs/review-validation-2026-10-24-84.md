# Review validation: issue #84

Branch: `bug/84-android-backup-creation`
Reviewed parent: `7dee0e35b58ad19f810475d32f07887a6e8a4025`

## Confirmed findings and changes

Android DocumentsContract explicitly permits null COLUMN_SIZE. Previously null
became zero, so a nonempty completed backup was deleted by size verification.
Preserve nullable sizes and count bytes through a bounded read buffer only when
the reported size is unknown. Use the same fallback for the manifest size lookup.
Known zero/truncated files still fail the exact source-size check. Name/URI checks,
permission checks, cleanup of only the newly created document, and retention order
are unchanged. This proves a provider-contract defect, NOT the root cause of the
reported physical Android 16 failure.

The persistent failure provider previously retained only a boolean; the UI showed
a folder-access message for every error. It now retains a sanitized failure code
and allowlisted native stage. Both manual and automatic backups use this path.
Only permission failures suggest granting folder access; other errors show the
existing localized export-failure message with a stable diagnostic identifier.
The picker uses the same classification. Exception messages, paths, arbitrary
native details, and provider URIs are not retained or displayed. No translation
schema change or regeneration is required for these diagnostic identifiers.

## Verification actually performed

The production BackupDocumentSize helper was compiled using the available Kotlin
compiler and exercised by a standalone JVM assertion harness. Known/zero sizes,
null/negative unknown sizes, multiple buffers, empty/unavailable streams, read
failure propagation, and closing the stream passed. This was NOT an Android
Gradle/JUnit run and did not exercise a real DocumentsProvider.

Added native JUnit tests for that helper and Flutter classification/UI tests for
permission versus storage failures, safe diagnostics, retained state and clearing,
including 320px width and enlarged text. Flutter/Dart/FVM, Android builds, Gradle
unit tests, analyzer and device tests were unavailable and have NOT run.

## Required local continuation

Read current AGENTS.md and earlier #84 handoffs. Format the changed Dart files;
run test/core/backups (including export/import consumers) and the Android unit
suite. Search all autoBackupFailureProvider consumers after changing its state
from bool to AutoBackupFailure?. Verify failure -> retry -> success and screen
re-entry with both automatic and manual backups. Add/execute DocumentsProvider
integration coverage for null size, known zero/truncation, failed reads, renamed
documents and partial grants. Check manifest sizes, restorable packages, and that
failed creation never deletes previous backups or runs retention.

Reproduce the original failure on Android 16 with a normal writable folder and
capture only sanitized stage/type diagnostics. Validate narrow-screen rendering
of the diagnostic identifiers. Run the complete regression suite against the
final combined candidate before any separately authorized integration. No merge,
issue closure, or claim that the original device failure is resolved was made.
