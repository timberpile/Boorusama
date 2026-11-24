import '../../../foundation/data_mutation_coordinator.dart';
import 'local_events.dart';
import 'notification_outbox.dart';
import 'protocol.dart';

int syncNoticeId(SyncNotice notice) => switch (notice.kind) {
  SyncNoticeKind.device => int.parse(
    syncDigest(syncJsonBytesForDevice(notice)).substring(0, 7),
    radix: 16,
  ),
  SyncNoticeKind.offers || SyncNoticeKind.followingOffers => int.parse(
    syncDigest(syncJsonBytes([notice.bucket, notice.batch])).substring(0, 7),
    radix: 16,
  ),
  SyncNoticeKind.posts || SyncNoticeKind.topics => int.parse(
    syncDigest(syncJsonBytes([notice.bucket, notice.batch])).substring(0, 7),
    radix: 16,
  ),
};

// Preserve the original device notification's (tag, id) during migration.
List<int> syncJsonBytesForDevice(SyncNotice notice) =>
    notice.items.single.publisherKey.codeUnits;

String syncNoticeTag(SyncNotice notice) => switch (notice.kind) {
  SyncNoticeKind.device =>
    'mitemite.discovery.${notice.items.single.publisherKey}',
  SyncNoticeKind.offers => 'mitemite.offers.${notice.items.first.publisherKey}',
  SyncNoticeKind.posts => 'mitemite.posts.v1',
  SyncNoticeKind.topics => 'mitemite.topics.v1',
  SyncNoticeKind.followingOffers =>
    'mitemite.following_offers.${notice.items.first.publisherKey}',
};

/// One serialized delivery path. Stable native tags replace an unacknowledged
/// OS notice after a crash; content tokens protect merges during native awaits.
final class SyncNotificationDelivery {
  final _operations = DataMutationCoordinator();
  final _shown = <String>{};

  Future<void> deliver({
    required SyncLocalEvents events,
    required bool Function() enabled,
    required bool Function() current,
    required Future<bool> Function({bool requestIfDenied}) requestPermission,
    required Future<bool> Function(SyncNotice) show,
    bool Function(SyncNotice)? allowed,
    bool Function(SyncNotice)? select,
    Future<void> Function(SyncNotice)? acknowledge,
  }) => _operations.runExclusive(() async {
    await events.pruneNotificationOutbox();
    final pending = events.pendingNotifications
        .where((notice) => select?.call(notice) ?? true)
        .toList();
    if (pending.isEmpty || !enabled() || !current()) return;
    var permitted = await requestPermission(requestIfDenied: false);
    if (!permitted &&
        !events.notificationPermissionRequested &&
        enabled() &&
        current()) {
      await events.markNotificationPermissionRequested();
      if (!enabled() || !current()) return;
      permitted = await requestPermission(requestIfDenied: true);
    }
    if (!permitted || !enabled() || !current()) return;
    for (final notice in pending) {
      if (!current() || !enabled()) break;
      if (!(allowed?.call(notice) ?? true)) continue;
      try {
        if (!_shown.contains(notice.token)) {
          if (!await show(notice)) continue;
          _shown.add(notice.token);
          if (_shown.length > SyncLocalEvents.historyLimit) {
            _shown.remove(_shown.first);
          }
        }
        if (!current()) break;
        await (acknowledge?.call(notice) ??
            events.acknowledgeNotification(notice));
      } catch (_) {
        // A denied/blocked/failed native display or receipt stays retryable.
        // Other independent categories/publishers are not starved by it.
      }
    }
  });
}
