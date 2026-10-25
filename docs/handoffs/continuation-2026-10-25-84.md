# Issue #84 controlled Android provider acceptance

Current combined candidate: `07da2e3183452c6f6967e251a77e5967582116c4`.
Native provider coverage commit: `aa2d84f58`; runtime catalog fix `53468ccee`.
The branch retains the unknown-size, safe diagnostic and partial-picker fixes.
It now includes published develop `a7cdaaff3`. No #68/#77 changes are included.

## Actual DocumentsProvider integration

Installed the app and instrumentation APK on the exclusively leased API 37
emulator `emulator-5554`. The tests invoke the real AutoBackupChannel through its
binary MethodChannel codec and real ContentResolver/DocumentsContract calls to
an installed controlled provider. This is native Android execution, not a
standalone JVM/helper substitution.

`adb -s emulator-5554 shell am instrument -w -r -e class
com.timberpile.boorusama.AutoBackupDocumentsProviderTest
com.timberpile.boorusama.dev.test/androidx.test.runner.AndroidJUnitRunner`
passed all four tests, zero failures, 3.168 seconds:

- Null and negative provider sizes verify by reading actual bytes; known size
  also succeeds, and reopening/listing/size agree.
- Known zero, actual truncation, unavailable read and provider-renamed documents
  fail at verify_backup_document and delete only the failed new document.
- Every failed case preserves the exact older backup bytes and old manifest;
  a subsequent valid retry succeeds.
- Partial and revoked persisted grants fail before writing, and a new valid
  grant recovers without resetting provider history. A separate actual picker
  callback with read-only flags returns access-required at
  persist_folder_permission without persisting it.

Log: `/tmp/boorusama-84-provider-final.log`. The production Android code is
identical across `aa2d84f58` and `07da2e318` (`git diff ... -- android` is empty),
so this native evidence applies to the combined native candidate. Earlier
harness failures (ABI mismatch, standalone test-APK dependencies, automation
connection and grant setup) are not counted as passing runs.

The controlled provider lives only in the instrumentation APK and uses plain
Android/Java dependencies because the test APK omits runtime libraries also
packaged in the app. Real persistable permissions use an Intent grant, with
explicit background-launch opt-in and an Activity monitor completion signal;
there are no fixed sleeps. The receiving debug-only Activity is disabled by
default, accepts only the fixture authority/tree, persists the offered grant and
finishes. Tests restore its default disabled state and release only their own
URI permission. Production release APKs contain neither fixture component.
Maestro's driver was stopped for exclusive native automation, then restored for
subsequent MCP-controlled UI work. No app data or real backups were reset.

## Combined verification and phone artifact

- The actual native `:app:testDevDebugUnitTest --offline` suite passed 47 tests,
  zero failures/errors/skips, on `07da2e318`.
  `/tmp/boorusama-84-native-combined-final.log`.
- Changed i18n inputs from develop were regenerated with `./gen.sh i18n` before
  the combined regression. No generated source was hand-edited.
- Complete regression result is recorded in the addendum below.
- The ARM64 Dev APK built, then an unchanged repeat built in 10.3 seconds without
  the first-build File modified warning. Existing AGP/Kotlin support warnings
  remain. `/tmp/boorusama-84-phone-checked-2.log`.
- Current phone artifact: `build/qa/issue84-current-arm64-debug.apk`.
  SHA-256 `2416596dc27eec01885b3dbf7a09b53044443bb4305ccb2e8d9dc4c64ab3c247`.
  It matches the final local build byte for byte and contains ARM64 libflutter.
  Package identity is `com.timberpile.boorusama.dev`, for side-by-side testing.
- The earlier `build/qa/issue84-arm64-debug.apk` remains preserved as older-source
  evidence (SHA-256 `b86c277b3413cfb793c7cf1a090304fd808350e7779212e82d6b88be53da546e`).

## Physical Android 16 gate

The user can run the phone checks later. Keep the issue and branch open until
that result is available; emulator success does not establish the reported
physical-device case. On the current APK, use a normal writable destination
where regular export succeeds, run Backup Now and a due automatic backup, and
check that the new packages and history entries appear. Automatic backup follows
its due interval, so a no-op immediately after a successful backup is not a
failed creation. Preserve existing backups, settings and real phone data.
If failure occurs, retain only the displayed safe stage/type/code diagnostic.

The previous real DocumentsUI/emulator scenario already established valid ZIP
CRC, manifest hashes/sizes, retention/history preservation, re-entry and retry.
It is documented in the October 24 handoff and remains earlier-source UI evidence.
The combined phone candidate and physical acceptance remain distinct.

Conditional publication authority still applies after all required acceptance.
Do not integrate/close merely because automation passes; retain the branch and
phone artifacts until the original Android 16 gate is resolved.

## Complete combined regression

`./scripts/run_regression_tests.sh` on `07da2e318` passed, exit 0: 4,985
application tests, all 1,535 package/CLI tests across 13 suites, both repository
shell suites and 72 Python tests. Two existing go_router tests skipped.
`/tmp/boorusama-84-regression-combined-final.log`. Documentation-only handoff
updates preserve that checked runtime/test candidate. The worktree is committed
and the physical-device gate remains pending.
