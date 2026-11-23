# Notify When Automatic Backups Fail — Technical Handoff

Issue: [#173](https://github.com/timberpile/Boorusama/issues/173)
Source reviewed: [`develop` at `55cec5ae2b69`](https://github.com/timberpile/Boorusama/tree/55cec5ae2b697612a68af40ed3a8bc4ba1caedbb) (2026-11-17).
Audience: local implementation agent. Code snippets are **unapplied proposals**, not verified patches.

## Evidence and integration points

**Feature request:** no system-notification behavior was claimed to be implemented. The backup failure stream already exists as `autoBackupFailureProvider` in `lib/core/backups/auto/providers.dart`; the backup operation reports it in `lib/core/backups/zip/backup_notifier.dart`. Prior repository review identified an existing `flutter_local_notifications` / `DownloadNotifications` integration; find and reuse its app-wide setup rather than registering a second plugin instance.

## Suggested implementation

Make a dedicated, stable Android notification identity and channel, e.g. channel `auto_backup.failure.v1`, fixed notification ID, `ongoing: true`, `autoCancel: false`, `onlyAlertOnce: true`. Show it for actionable **automatic** backup failures; update the same notification for further failures. Use a localized generic title/body without directory URI, names or private content. Notification tap navigates to Backup settings.

```dart
AndroidNotificationDetails(
  'auto_backup.failure.v1',
  'Backup failures',
  ongoing: true,
  autoCancel: false,
  onlyAlertOnce: true,
)
```

Integrate with the backup scheduler/service or a long-lived app-level observer, **not** a Backup settings widget that disappears when navigated away. Reconcile notification state on app startup and after folder permission recovery; record only minimal persistent failure/recovery state if needed. Cancel the fixed notification when a successful backup or independently validated repair proves recovery, not merely when settings is opened. On Android 13+ a denied notification permission must not block backups or in-app warnings; do not request an unrelated foreground service.

## Focused verification

- Failure while app UI is closed creates one persistent notification; repeat failure updates rather than multiplying alerts.
- Tap opens the correct settings route; app restart and device reboot restore/clear appropriate state.
- Valid folder repair or successful backup cancels; an unresolved failure remains visible; notification-denied path leaves in-app warning intact.
- Exercise Android channel/notification permissions and duplicate-instance handling in tests where possible.
