import 'package:boorusama/core/backups/mitemite/notification_outbox.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const publisher = '11111111-2222-4333-8444-555555555555';
  const other = '22222222-2222-4333-8444-555555555555';
  const a = '33333333-2222-4333-8444-555555555555';
  const b = '44444444-2222-4333-8444-555555555555';
  const c = '55555555-2222-4333-8444-555555555555';
  final fingerprint = 'a' * 64;
  final at = DateTime.utc(2026, 11, 15);
  SyncCollectionId collection(String source) =>
      SyncCollectionId(publisher: publisher, kind: 'bookmarks', source: source);
  SyncNoticeItem post(
    String source,
    String member, {
    String from = publisher,
    DateTime? time,
  }) => SyncNoticeItem(
    publisher: from,
    fingerprint: fingerprint,
    at: time ?? at,
    sourceKind: 'bookmarks',
    source: source,
    member: member,
  );

  test('source-specific offers and NEW receipts persist independently from native delivery', () {
    final outbox = SyncNotificationOutbox.empty();
    SyncCollectionId following(String id) => SyncCollectionId(
      publisher: publisher,
      kind: 'following_topics',
      source: id,
    );
    void observe(int n, List<SyncCollectionId> roots) => outbox.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: n,
      roots: roots,
      at: at,
    );
    observe(1, [collection(a)]);
    expect(outbox.unseenOffers, isEmpty);
    observe(2, [collection(a), collection(b), following(c)]);
    expect(outbox.pending.map((notice) => notice.kind).toSet(), {
      SyncNoticeKind.offers,
      SyncNoticeKind.followingOffers,
    });
    final snapshot = outbox.unseenOffers.keys.toSet();
    for (final notice in outbox.pending) {
      outbox.acknowledge(notice);
    }
    expect(outbox.unseenOffers.keys.toSet(), snapshot);
    outbox.prune(at.add(const Duration(days: 4)));
    expect(outbox.unseenOffers, hasLength(2));
    observe(3, [collection(a), collection(b), following(c), following(a)]);
    outbox.acknowledgeOffers(snapshot);
    final restored = SyncNotificationOutbox.fromJson(outbox.toJson());
    expect(restored.unseenOffers.values.single.source, a);
    expect(restored.unseenOffers.values.single.sourceKind, 'following_topics');
    observe(4, [collection(a)]);
    observe(5, [collection(a), collection(b), following(c), following(a)]);
    expect(
      outbox.unseenOffers,
      isEmpty,
      reason: 'Withdrawal/re-advertisement never invents a new offer',
    );
    restored.removePublisher(publisher);
    expect(restored.unseenOffers, isEmpty);
  });

  test(
    'obsolete mixed pending offers fail before loading the outbox',
    () {
      final outbox = SyncNotificationOutbox.empty();
      outbox.seedOffers(
        publisher: publisher,
        fingerprint: fingerprint,
        sequence: 0,
        roots: [],
      );
      outbox.observeOffers(
        publisher: publisher,
        fingerprint: fingerprint,
        sequence: 1,
        roots: [
          collection(a),
          SyncCollectionId(
            publisher: publisher,
            kind: 'following_topics',
            source: b,
          ),
        ],
        at: at,
      );
      final current = outbox.toJson();
      final items = outbox.pending.expand((notice) => notice.items).toList();
      final legacy = {
        ...current,
        'version': 1,
        'pending': [
          {
            'kind': 'offers',
            'bucket': 'offers:$publisher/$fingerprint',
            'batch': 1,
            'generation': 3,
            'items': items.map((item) => item.toJson()).toList(),
          },
        ],
      }..remove('unseenOffers');
      expect(
        () => SyncNotificationOutbox.fromJson(legacy),
        throwsFormatException,
      );
      final restored = SyncNotificationOutbox.fromJson(current);
      expect(restored.toJson(), current);
    },
  );

  test('trust seeds offers; only new direct identities notify without rename or reappearance spam', () {
    final outbox = SyncNotificationOutbox.empty();
    void observe(int sequence, List<String> roots) => outbox.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: sequence,
      roots: roots.map(collection),
      at: at,
    );
    observe(1, [a]);
    expect(outbox.pending, isEmpty);
    observe(2, [a]);
    expect(outbox.pending, isEmpty);
    observe(3, [a, b, c]);
    final offered = outbox.pending.single;
    expect(offered.kind, SyncNoticeKind.offers);
    expect(offered.groupCount, 2);
    expect(outbox.acknowledge(offered), isTrue);
    observe(4, []);
    observe(5, [a, b, c]);
    expect(outbox.pending, isEmpty);
    expect(() => observe(4, [a]), throwsA(isA<SyncReplayRejected>()));
  });

  test('explicit identity-only trust seeds zero; re-trust replaces offers without replaying old device notices', () {
    final outbox = SyncNotificationOutbox.empty()
      ..discover(publisher, fingerprint, at);
    outbox.seedOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 0,
      roots: [],
    );
    outbox.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 1,
      roots: [collection(a)],
      at: at,
    );
    expect(outbox.pending.map((n) => n.kind), [
      SyncNoticeKind.device,
      SyncNoticeKind.offers,
    ]);
    outbox.seedOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 1,
      roots: [collection(a)],
      replace: true,
    );
    expect(outbox.pending.single.kind, SyncNoticeKind.device);
    outbox.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 2,
      roots: [collection(a)],
      at: at,
    );
    expect(outbox.pending.single.kind, SyncNoticeKind.device);
  });

  test('canonical overlap and sibling copies count one Post but preserve both destinations', () {
    final outbox = SyncNotificationOutbox.empty();
    outbox.receivePosts([post(a, 'P'), post(a, 'P'), post(a, 'P')]);
    expect(outbox.pending.single.items, hasLength(1));
    outbox.receivePosts([post(b, 'P')]);
    expect(outbox.pending.single.postCount, 1);
    expect(outbox.pending.single.groupCount, 2);
    outbox.receivePosts([post(a, 'P', from: other)]);
    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.single.postCount, 2);
    expect(outbox.pending.single.groupCount, 3);
    expect(outbox.pending.single.deviceCount, 2);
  });

  test('2 plus 3 plus 4 unique Posts form one nine-Post batch', () {
    final outbox = SyncNotificationOutbox.empty();
    outbox.receivePosts([
      for (var i = 0; i < 2; i++) post(a, 'A$i'),
      for (var i = 0; i < 3; i++) post(b, 'B$i'),
      for (var i = 0; i < 4; i++) post(c, 'C$i'),
    ]);
    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.single.postCount, 9);
    expect(outbox.pending.single.groupCount, 3);
  });

  test('an older async receipt cannot erase merged changes; later batches remain distinct', () {
    final outbox = SyncNotificationOutbox.empty()..receivePosts([post(a, 'P')]);
    final first = outbox.pending.single;
    outbox.receivePosts([post(b, 'Q')]);
    final merged = outbox.pending.single;
    expect(merged.batch, first.batch);
    expect(merged.generation, greaterThan(first.generation));
    expect(merged.token, isNot(first.token));
    expect(outbox.acknowledge(first), isFalse);
    expect(outbox.pending.single.postCount, 2);
    expect(outbox.acknowledge(merged), isTrue);
    outbox.receivePosts([post(a, 'R')]);
    expect(outbox.pending.single.batch, greaterThan(first.batch));
  });

  test('freshness expires individual old changes without reviving them on a fresh merge', () {
    final outbox = SyncNotificationOutbox.empty();
    outbox.receivePosts([
      post(a, 'Old', time: at.subtract(const Duration(days: 2))),
    ]);
    outbox.receivePosts([post(b, 'Current')]);
    outbox.prune(at);
    expect(outbox.pending.single.postCount, 1);
    expect(outbox.pending.single.items.single.member, 'Current');
    outbox.prune(at.add(const Duration(hours: 24, seconds: 1)));
    expect(outbox.pending, isEmpty);
  });

  test('roundtrip preserves exact pending identities, offer checkpoints and permission receipt', () {
    final outbox = SyncNotificationOutbox.empty()..permissionRequested = true;
    outbox.discover(publisher, fingerprint, at);
    outbox.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 1,
      roots: [collection(a)],
      at: at,
    );
    outbox.receivePosts([
      post(a, canonicalSyncJson([25, 'site', 'work', '123'])),
    ]);
    final restored = SyncNotificationOutbox.fromJson(outbox.toJson());
    expect(
      canonicalSyncJson(restored.toJson()),
      canonicalSyncJson(outbox.toJson()),
    );
    expect(restored.permissionRequested, isTrue);
    restored.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 2,
      roots: [collection(a)],
      at: at,
    );
    expect(
      restored.pending.where((n) => n.kind == SyncNoticeKind.offers),
      isEmpty,
    );
  });

  test('Forget removes only its publisher from mixed summaries and resets its offer baseline', () {
    final outbox = SyncNotificationOutbox.empty();
    outbox.discover(publisher, fingerprint, at);
    outbox.receivePosts([post(a, 'P'), post(b, 'Q', from: other)]);
    outbox.removePublisher(publisher);
    expect(outbox.pending, hasLength(1));
    expect(outbox.pending.single.items.single.publisher, other);
    outbox.observeOffers(
      publisher: publisher,
      fingerprint: fingerprint,
      sequence: 9,
      roots: [collection(a)],
      at: at,
    );
    expect(outbox.pending, hasLength(1));
  });

  test(
    'invalid versions, duplicate buckets and malformed identities fail closed',
    () {
      final outbox = SyncNotificationOutbox.empty()
        ..discover(publisher, fingerprint, at);
      expect(
        () =>
            SyncNotificationOutbox.fromJson({...outbox.toJson(), 'version': 7}),
        throwsFormatException,
      );
      expect(
        () => SyncNotificationOutbox.fromJson({
          ...outbox.toJson(),
          'pending': [
            outbox.pending.single.toJson(),
            outbox.pending.single.toJson(),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () =>
            SyncNoticeItem(publisher: publisher, fingerprint: 'broken', at: at),
        throwsFormatException,
      );
      expect(
        () => SyncNotice(
          bucket: 'posts',
          kind: SyncNoticeKind.posts,
          batch: 1,
          generation: 1,
          items: [
            SyncNoticeItem(
              publisher: publisher,
              fingerprint: fingerprint,
              at: at,
            ),
          ],
        ),
        throwsFormatException,
      );
    },
  );
}
