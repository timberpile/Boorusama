import 'dart:async';

import 'package:boorusama/core/backups/mitemite/local_events.dart';
import 'package:boorusama/core/backups/mitemite/notification_delivery.dart';
import 'package:boorusama/core/backups/mitemite/notification_outbox.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const publisher = '11111111-2222-4333-8444-555555555555';
  const source = '22222222-2222-4333-8444-555555555555';
  final at = DateTime.utc(2026);
  late _Store store;
  late SyncLocalEvents events;
  var now = at;
  setUp(() {
    now = at;
    store = _Store();
    events = SyncLocalEvents(
      preferences: store,
      mutations: DataMutationCoordinator(),
      now: () => now,
    );
  });
  SyncActivityLog posts(int count) => const SyncActivityLog.empty().append([
    for (var i = 0; i < count; i++)
      SyncEvent(
        kind: SyncEventKind.received,
        at: at,
        publisher: publisher,
        source: source,
        fingerprint: 'a' * 64,
        added: 1,
        notificationMembers: {'member:$i'},
      ),
  ]);
  test('merge during native await retains later changes and a later genuine batch has a new stable ID', () async {
    await events.consume('bookmarks', posts(1));
    final first = events.pendingNotifications.single;
    final entered = Completer<void>();
    final release = Completer<bool>();
    final delivery = SyncNotificationDelivery();
    final sending = delivery.deliver(
      events: events,
      enabled: () => true,
      current: () => true,
      requestPermission: ({requestIfDenied = true}) async => true,
      show: (_) {
        entered.complete();
        return release.future;
      },
    );
    await entered.future;
    await events.consume('bookmarks', posts(2));
    release.complete(true);
    await sending;
    final merged = events.pendingNotifications.single;
    expect(merged.postCount, 2);
    expect(syncNoticeId(merged), syncNoticeId(first));
    expect(syncNoticeTag(merged), syncNoticeTag(first));
    final sent = <SyncNotice>[];
    await delivery.deliver(
      events: events,
      enabled: () => true,
      current: () => true,
      requestPermission: ({requestIfDenied = true}) async => true,
      show: (notice) async {
        sent.add(notice);
        return true;
      },
    );
    expect(events.pendingNotifications, isEmpty);
    await events.consume('bookmarks', posts(3));
    final next = events.pendingNotifications.single;
    expect(next.postCount, 1);
    expect(syncNoticeId(next), isNot(syncNoticeId(first)));
    expect(
      syncNoticeId(SyncNotice.fromJson(next.toJson())),
      syncNoticeId(next),
    );
  });
  test('a native channel refusal keeps intent until enabled and a preference change during permission wait prevents display', () async {
    await events.consume('bookmarks', posts(1));
    final delivery = SyncNotificationDelivery();
    var enabled = true;
    final permission = Completer<bool>();
    final entered = Completer<void>();
    var shows = 0;
    final pending = delivery.deliver(
      events: events,
      enabled: () => enabled,
      current: () => true,
      requestPermission: ({requestIfDenied = true}) {
        entered.complete();
        return permission.future;
      },
      show: (_) async {
        shows++;
        return true;
      },
    );
    await entered.future;
    enabled = false;
    permission.complete(true);
    await pending;
    expect(shows, 0);
    expect(events.pendingNotifications, hasLength(1));
    enabled = true;
    await delivery.deliver(
      events: events,
      enabled: () => enabled,
      current: () => true,
      requestPermission: ({requestIfDenied = true}) async => true,
      show: (_) async => false,
    );
    expect(events.pendingNotifications, hasLength(1));
    await delivery.deliver(
      events: events,
      enabled: () => enabled,
      current: () => true,
      requestPermission: ({requestIfDenied = true}) async => true,
      show: (_) async {
        shows++;
        return true;
      },
    );
    expect(shows, 1);
    expect(events.pendingNotifications, isEmpty);
  });
  test('expired pending intent is retired without asking permission or replaying old journal entries', () async {
    await events.consume('bookmarks', posts(1));
    now = at.add(const Duration(hours: 25));
    await SyncNotificationDelivery().deliver(
      events: events,
      enabled: () => true,
      current: () => true,
      requestPermission: ({requestIfDenied = true}) => Future.sync(() {
        fail('Expired intent must not ask permission');
      }),
      show: (_) => Future.sync(() {
        fail('Expired intent must not show');
      }),
    );
    await events.consume('bookmarks', posts(1));
    expect(events.pendingNotifications, isEmpty);
    expect(events.history, hasLength(1));
    expect(events.activityCursor('bookmarks'), 1);
  });
}

class _Store implements MiscDataStore {
  final values = <String, String>{};
  @override
  String? get(String key) => values[key];
  @override
  Future<void> put(String key, String value) async {
    values[key] = value;
  }
}
