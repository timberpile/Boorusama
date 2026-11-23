import 'dart:convert';

import 'local_events.dart';
import 'notification_delivery.dart';
import 'notification_outbox.dart';
import 'protocol.dart';

int syncDiscoveryNotificationId(SyncDiscovery discovery) => int.parse(
  syncDigest(utf8.encode(discovery.key)).substring(0, 7),
  radix: 16,
);

/// Compatibility entry point for discovery consumers. All delivery uses the
/// same typed outbox and coordinator as collection/Post notifications.
final class SyncDiscoveryDelivery {
  final _delivery = SyncNotificationDelivery();
  Future<void> deliver({
    required SyncLocalEvents events,
    required bool enabled,
    required bool Function() current,
    required Future<bool> Function({bool requestIfDenied}) requestPermission,
    required Future<void> Function(SyncDiscovery) show,
    required Future<void> Function(Set<String>) acknowledge,
  }) => _delivery.deliver(
    events: events,
    enabled: () => enabled,
    current: current,
    requestPermission: requestPermission,
    select: (notice) => notice.kind == SyncNoticeKind.device,
    show: (notice) async {
      final item = notice.items.single;
      await show(SyncDiscovery(item.publisher, item.fingerprint));
      return true;
    },
    acknowledge: (notice) => acknowledge({notice.items.single.publisherKey}),
  );
}
