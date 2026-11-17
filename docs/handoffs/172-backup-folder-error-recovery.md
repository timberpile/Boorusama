# Clear Backup Errors After Permission Recovery — Technical Handoff

Issue: [#172](https://github.com/timberpile/Boorusama/issues/172)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence and likely cause

**Source-confirmed:** `lib/core/backups/auto/providers.dart` stores failure in `autoBackupFailureProvider`, whose notifier has `clear()`. `lib/core/backups/auto/widgets.dart` picks an Android folder with `AutoBackupRepositoryAndroid.pickDirectory()` and only updates `userSelectedPath`; it keeps rendering the stored failure. `lib/core/backups/zip/backup_notifier.dart` calls `failure.clear()` at the **start of a later backup**. The reported stale message therefore survives successful folder selection. This does not prove the new destination is writable.

## Suggested implementation

After a folder is selected, use the repository's SAF access check (including persisted URI permission and write capability; inspect existing `AutoBackupRepositoryAndroid.getBackupDirectoryPath` or its equivalent) to validate the **new** location. Update settings as before. If verification succeeds, clear only an access-related previous failure (`failure.requiresFolderAccess`); leave unrelated failures intact. On failure, display the current error instead of stale previous diagnostics.

```dart
final selected = await AutoBackupRepositoryAndroid.pickDirectory();
if (selected != null) {
  final usable = await validateBackupDirectoryAccess(selected); // adapt to repository API
  _updateSettings(settingsNotifier,
      settings.copyWith(userSelectedPath: () => selected));
  if (usable && ref.read(autoBackupFailureProvider)?.requiresFolderAccess == true) {
    ref.read(autoBackupFailureProvider.notifier).clear();
  }
}
```

The validation helper above is **pseudocode**—do not add a second storage-access implementation. Guard async completion against later selections, disposed UI, and a newer backup failure. Do not start an actual backup merely to dismiss a banner.

## Focused verification

- Recover a revoked Android SAF folder by selecting a writable new folder: warning disappears without another backup.
- Invalid or read-only destination does not clear a real error; unrelated backup failure remains.
- Repeated selections, cancellation and concurrent scheduled backups cannot clear/report errors for the wrong directory.
- Verify on Android SAF as well as notifier/widget tests, without modifying existing backups.
