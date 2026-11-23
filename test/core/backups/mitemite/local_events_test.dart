import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/local_events.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a failed cached offer acknowledgement retains NEW and preserves other receipt state', () async {
    const publisher = '11111111-2222-4333-8444-555555555555';
    const source = '22222222-2222-4333-8444-555555555555';
    final store = _Store();
    final events = SyncLocalEvents(
      preferences: store,
      mutations: DataMutationCoordinator(),
      now: () => DateTime.utc(2026),
    );
    await events.seedOfferBaseline(
      publisher: publisher,
      fingerprint: 'a' * 64,
      sequence: 0,
      roots: [],
    );
    await events.observeOffers(
      publisher: publisher,
      fingerprint: 'a' * 64,
      sequence: 1,
      roots: [
        SyncCollectionId(
          publisher: publisher,
          kind: 'bookmarks',
          source: source,
        ),
      ],
      at: DateTime.utc(2026),
    );
    final before = Map<String, String>.from(store.data);
    final pending = events.pendingNotifications.single.token;
    final captured = events.unseenOffers.keys.toSet();
    store.failAfterWrite = true;
    await expectLater(events.acknowledgeOffers(captured), throwsStateError);
    expect(
      events.unseenOffers.keys.toSet(),
      captured,
      reason: 'A cached value is not a successful receipt write',
    );
    expect(store.data, before);
    expect(events.pendingNotifications.single.token, pending);
    store.failAfterWrite = false;
    await events.acknowledgeOffers(captured);
    expect(events.unseenOffers, isEmpty);
    expect(
      events.pendingNotifications.single.token,
      pending,
      reason: 'Viewing offers never acknowledges native delivery',
    );
  });

  test('discovery receipts survive scans and reconstruction without repeat notices', () async {
    final store = _Store();
    final mutations = DataMutationCoordinator();
    SyncLocalEvents open() => SyncLocalEvents(
      preferences: store,
      mutations: mutations,
      now: () => DateTime.utc(2026),
    );
    final device = SyncDiscovery(
      '11111111-2222-4333-8444-555555555555',
      'a' * 64,
    );
    final events = open();
    await events.discover([device, device], DateTime.utc(2026));
    expect(events.history, hasLength(1));
    expect(events.pendingDiscoveries.single.key, device.key);
    await events.acknowledgeDiscoveries({device.key});
    final reopened = open();
    await reopened.discover([device], DateTime.utc(2026, 2));
    expect(reopened.pendingDiscoveries, isEmpty);
    expect(reopened.history, hasLength(1));
  });
  test('interrupted delivery followed by Forget cannot resurrect a removed publisher notification', () async {
    const publisher = '11111111-2222-4333-8444-555555555555';
    final at = DateTime.utc(2026);
    final store = _Store();
    final events = SyncLocalEvents(
      preferences: store,
      mutations: DataMutationCoordinator(),
      now: () => at,
    );
    final log = const SyncActivityLog.empty().append([
      SyncEvent(
        kind: SyncEventKind.received,
        at: at,
        publisher: publisher,
        source: '22222222-2222-4333-8444-555555555555',
        fingerprint: 'a' * 64,
        added: 1,
        notificationMembers: {'P'},
      ),
      SyncEvent(kind: SyncEventKind.forgotten, at: at, publisher: publisher),
    ]);
    await events.consume('bookmarks', log);
    expect(events.pendingNotifications, isEmpty);
    // The domain tombstone still prevents replay after the bounded Activity
    // window has truncated the older Forget event.
    final later = log.append([
      for (var i = 0; i < 205; i++)
        SyncEvent(kind: SyncEventKind.published, at: at),
    ]);
    final reopened = SyncLocalEvents(
      preferences: _Store(),
      mutations: DataMutationCoordinator(),
      now: () => at,
    );
    await reopened.consume(
      'bookmarks',
      later,
      forgottenPublishers: {publisher},
    );
    expect(reopened.pendingNotifications, isEmpty);
    expect(reopened.activityCursor('bookmarks'), later.sequence);
  });

  test('a cached cursor from a failed durability barrier must be flushed again before journal intent can retire', () async {
    final store = _Store()..failAfterWrite = true;
    final events = SyncLocalEvents(
      preferences: store,
      mutations: DataMutationCoordinator(),
      now: () => DateTime.utc(2026),
    );
    final log = const SyncActivityLog.empty().append([
      SyncEvent(
        kind: SyncEventKind.received,
        at: DateTime.utc(2026),
        publisher: '11111111-2222-4333-8444-555555555555',
        source: '22222222-2222-4333-8444-555555555555',
        fingerprint: 'a' * 64,
        added: 1,
        notificationMembers: {'P'},
      ),
    ]);
    await expectLater(events.consume('bookmarks', log), throwsStateError);
    expect(
      events.activityCursor('bookmarks'),
      log.sequence,
      reason: 'Hive may already expose its cached write',
    );
    await expectLater(
      events.consume('bookmarks', log),
      throwsStateError,
      reason: 'The matching cached cursor must not bypass failed fsync',
    );
    expect(log.pendingPosts, hasLength(1));
    store.failAfterWrite = false;
    await events.consume('bookmarks', log);
    expect(store.successfulWrites, 1);
    expect(events.pendingNotifications.single.postCount, 1);
    expect(
      log
          .acknowledgePostsThrough(events.activityCursor('bookmarks'))
          .pendingPosts,
      isEmpty,
    );
  });

  test('exact journaled Posts survive a failed outbox transfer beyond bounded Activity and recover once', () async {
    const publisher = '11111111-2222-4333-8444-555555555555';
    const source = '22222222-2222-4333-8444-555555555555';
    final at = DateTime.utc(2026);
    final store = _Store();
    final mutations = DataMutationCoordinator();
    SyncLocalEvents open() => SyncLocalEvents(
      preferences: store,
      mutations: mutations,
      now: () => at,
    );
    final log = const SyncActivityLog.empty().append([
      for (var i = 0; i < 205; i++)
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
    store.failWrites = true;
    await expectLater(open().consume('bookmarks', log), throwsStateError);
    expect(open().pendingNotifications, isEmpty);
    expect(open().activityCursor('bookmarks'), 0);
    store.failWrites = false;
    await open().consume('bookmarks', SyncActivityLog.fromJson(log.toJson()));
    final notice = open().pendingNotifications.single;
    expect(notice.postCount, 205);
    expect(open().history, hasLength(200));
    expect(
      open().history.every((event) => event.notificationMembers.isEmpty),
      isTrue,
    );
    await open().acknowledgeNotification(notice);
    await open().consume('bookmarks', log);
    expect(open().pendingNotifications, isEmpty);
    expect(open().activityCursor('bookmarks'), 205);
  });

  test('journal outbox delivery survives interrupted history writes, deduplicates and keeps chronological bounds', () async {
    final store = _Store();
    final mutations = DataMutationCoordinator();
    SyncLocalEvents open() =>
        SyncLocalEvents(preferences: store, mutations: mutations);
    final at = DateTime.utc(2026, 11, 15);
    var log = const SyncActivityLog.empty();
    for (var i = 0; i < 205; i++) {
      log = log.append([
        SyncEvent(
          kind: SyncEventKind.received,
          at: at.add(Duration(seconds: i)),
        ),
      ]);
    }
    expect(log.sequence, 205);
    expect(log.entries, hasLength(SyncActivityLog.limit));
    final reopened = SyncActivityLog.fromJson(log.toJson());
    expect(reopened, log);
    expect(reopened.follows(const SyncActivityLog.empty()), isTrue);
    expect(const SyncActivityLog.empty().follows(log), isFalse);
    store.failWrites = true;
    await expectLater(open().consume('bookmarks', reopened), throwsStateError);
    expect(open().history, isEmpty);
    store.failWrites = false;
    await open().record(
      SyncEvent(
        kind: SyncEventKind.published,
        at: at.add(const Duration(days: 1)),
      ),
    );
    await open().consume('bookmarks', reopened);
    expect(open().history, hasLength(SyncLocalEvents.historyLimit));
    expect(open().history.first.kind, SyncEventKind.published);
    expect(open().history.last.at, at.add(const Duration(seconds: 6)));
    final delivered = open().history;
    await open().consume('bookmarks', reopened);
    expect(open().history, delivered);
    final next = reopened.append([
      SyncEvent(
        kind: SyncEventKind.received,
        at: at.add(const Duration(days: 2)),
      ),
    ]);
    await open().consume('bookmarks', next);
    expect(open().history.first.at, at.add(const Duration(days: 2)));
    await expectLater(
      open().consume('bookmarks', reopened),
      throwsFormatException,
    );
    final fork = reopened.toJson();
    (((fork['entries']! as List).last as Map)['event'] as Map)['kind'] =
        'copied';
    expect(SyncActivityLog.fromJson(fork).follows(reopened), isFalse);
    final malformed = reopened.toJson();
    (malformed['entries']! as List).removeAt(0);
    expect(() => SyncActivityLog.fromJson(malformed), throwsFormatException);
  });

  test('completed publication receipts recover exactly once and intent seeding invents no history', () async {
    final store = _Store();
    final mutations = DataMutationCoordinator();
    SyncLocalEvents open() =>
        SyncLocalEvents(preferences: store, mutations: mutations);
    const source = '11111111-2222-4333-8444-555555555555';
    final at = DateTime.utc(2026);
    await open().reconcilePublications({'bookmarks': {}}, at, seedOnly: true);
    store.failWrites = true;
    await expectLater(
      open().reconcilePublications({
        'following_topics': {source},
      }, at),
      throwsStateError,
    );
    store.failWrites = false;
    await open().reconcilePublications({
      'following_topics': {source},
    }, at);
    await open().reconcilePublications({
      'following_topics': {source},
    }, at);
    expect(open().history, hasLength(1));
    expect(open().history.single.kind, SyncEventKind.published);
    expect(open().history.single.sourceKind, 'following_topics');
    await open().reconcilePublications({
      'following_topics': {},
    }, at.add(const Duration(days: 1)));
    expect(open().history.first.kind, SyncEventKind.stopped);
  });

  test('failure episodes survive restart, distinguish causes and preserve the last success through a failed attempt', () async {
    final store = _Store();
    final mutations = DataMutationCoordinator();
    SyncLocalEvents open() =>
        SyncLocalEvents(preferences: store, mutations: mutations);
    final start = DateTime.utc(2026, 11, 15);
    final success = start.add(const Duration(minutes: 1));
    await open().markAttempt(start);
    await open().reconcileFailures(
      [],
      attemptedAt: start,
      completedAt: success,
    );
    final next = success.add(const Duration(minutes: 1));
    SyncEvent error(SyncFailureKind kind) => SyncEvent(
      kind: SyncEventKind.failed,
      at: next,
      publisher: '11111111-2222-4333-8444-555555555555',
      failure: kind,
    );
    await open().markAttempt(next);
    await open().reconcileFailures([
      error(SyncFailureKind.permission),
    ], attemptedAt: next);
    await open().reconcileFailures([
      error(SyncFailureKind.permission),
    ], attemptedAt: next.add(const Duration(minutes: 1)));
    expect(open().history, hasLength(1));
    expect(open().lastAttempt, next.add(const Duration(minutes: 1)));
    expect(open().lastSuccess, success);
    await open().reconcileFailures([
      error(SyncFailureKind.invalidSignature),
    ], attemptedAt: next);
    expect(open().history, hasLength(2));
    await open().reconcileFailures([], attemptedAt: next, completedAt: next);
    await open().recordFailure(error(SyncFailureKind.permission));
    await open().recordFailure(error(SyncFailureKind.permission));
    expect(open().history, hasLength(3));
    expect(open().lastSuccess, next);
  });

  test('history is bounded without dropping discovery deduplication', () async {
    final events = SyncLocalEvents(
      preferences: _Store(),
      mutations: DataMutationCoordinator(),
    );
    final device = SyncDiscovery(
      '11111111-2222-4333-8444-555555555555',
      'b' * 64,
    );
    await events.discover([device], DateTime.utc(2026));
    await events.acknowledgeDiscoveries({device.key});
    for (var i = 0; i < 205; i++) {
      await events.record(
        SyncEvent(
          kind: SyncEventKind.published,
          at: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
        ),
      );
    }
    expect(events.history, hasLength(SyncLocalEvents.historyLimit));
    await events.discover([device], DateTime.utc(2026, 2));
    expect(events.pendingDiscoveries, isEmpty);
    expect(
      events.history.every((event) => event.kind == SyncEventKind.published),
      isTrue,
    );
  });
}

class _Store implements MiscDataStore {
  final data = <String, String>{};
  bool failWrites = false;
  bool failAfterWrite = false;
  int successfulWrites = 0;
  @override
  String? get(String key) => data[key];
  @override
  Future<void> put(String key, String value) async {
    if (failWrites) throw StateError('Injected history write failure');
    data[key] = value;
    if (failAfterWrite)
      throw StateError('Injected durability barrier failure after cached put');
    successfulWrites++;
  }
}
