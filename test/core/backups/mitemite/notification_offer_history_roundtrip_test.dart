import 'package:boorusama/core/backups/mitemite/local_events.dart';
import 'package:boorusama/core/backups/mitemite/notification_outbox.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

const _publisher = '10000000-0000-4000-8000-000000000000';
const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
final _now = DateTime.utc(2026, 11, 22);

SyncCollectionId _root(int number) => SyncCollectionId(
  publisher: _publisher,
  kind: 'bookmarks',
  source:
      '20000000-0000-4000-8000-${number.toRadixString(16).padLeft(12, '0')}',
);

void main() {
  test(
    'accepted offer history remains readable across small observations',
    () async {
      final store = _MemoryPreferences();
      SyncLocalEvents open() => SyncLocalEvents(
        preferences: store,
        mutations: DataMutationCoordinator(),
        now: () => _now,
      );
      final events = open();
      await events.seedOfferBaseline(
        publisher: _publisher,
        fingerprint: _fingerprint,
        sequence: 1,
        roots: List.generate(256, _root),
      );
      // The receiving API admits each small current set. Its deduplication
      // history is cumulative even when earlier roots are no longer offered.
      // This tests the accepted-input contract, not this app's own publisher,
      // which retains old entries as tombstones in its outgoing catalog.
      for (var sequence = 2; sequence <= 17; sequence++) {
        await events.observeOffers(
          publisher: _publisher,
          fingerprint: _fingerprint,
          sequence: sequence,
          roots: List.generate(256, (i) => _root((sequence - 1) * 256 + i)),
          at: _now,
        );
        if (sequence < 17) {
          for (final notice in events.pendingNotifications) {
            await events.acknowledgeNotification(notice);
          }
          await events.acknowledgeOffers(events.unseenOffers.keys.toSet());
        }
      }

      final reopened = open();
      final notice = reopened.pendingNotifications.single;
      expect(notice.kind, SyncNoticeKind.offers);
      expect(notice.items, hasLength(256));
      expect(
        notice.items.map((item) => item.source),
        contains(_root(4351).source),
      );
      expect(reopened.unseenOffers, hasLength(256));
      await reopened.acknowledgeNotification(notice);
      await reopened.acknowledgeOffers(reopened.unseenOffers.keys.toSet());

      // A previously offered source returning is not new after reopening.
      await reopened.observeOffers(
        publisher: _publisher,
        fingerprint: _fingerprint,
        sequence: 18,
        roots: [_root(0), _root(4351)],
        at: _now,
      );
      expect(open().pendingNotifications, isEmpty);
      expect(open().unseenOffers, isEmpty);
    },
  );

  test('cumulative receipts do not relax one-catalog root limits', () {
    final roots = List.generate(4097, _root);
    expect(
      () => SyncNotificationOutbox.empty().seedOffers(
        publisher: _publisher,
        fingerprint: _fingerprint,
        sequence: 1,
        roots: roots,
      ),
      throwsFormatException,
    );
    expect(
      () => SyncNotificationOutbox.empty().observeOffers(
        publisher: _publisher,
        fingerprint: _fingerprint,
        sequence: 1,
        roots: roots,
        at: _now,
      ),
      throwsFormatException,
    );
  });
}

final class _MemoryPreferences implements MiscDataStore {
  final _values = <String, String>{};

  @override
  String? get(String key) => _values[key];

  @override
  Future<void> put(String key, String value) async {
    _values[key] = value;
  }
}
