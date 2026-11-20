import 'package:boorusama/core/backups/mitemite/activity_log.dart';
import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const publisher = '11111111-2222-4333-8444-555555555555';
  const source = '22222222-2222-4333-8444-555555555555';
  final at = DateTime.utc(2026, 11, 15);
  SyncEvent addition(int index) => SyncEvent(
    kind: SyncEventKind.received,
    at: at,
    publisher: publisher,
    source: source,
    added: 1,
    fingerprint: 'a' * 64,
    notificationMembers: {'member:$index'},
  );

  test('legacy journal payloads roundtrip without changing their hashes', () {
    final legacy = const SyncActivityLog.empty().append([
      SyncEvent(
        kind: SyncEventKind.received,
        at: at,
        publisher: publisher,
        source: source,
        added: 100,
      ),
    ]);
    final json = legacy.toJson();
    expect(json['version'], 1);
    final bytes = canonicalSyncJson(json);
    expect(
      canonicalSyncJson(
        SyncActivityLog.fromJson(Map<String, dynamic>.from(json)).toJson(),
      ),
      bytes,
    );
    expect(legacy.pendingPosts, isEmpty);
  });

  test('pending exact changes survive the bounded 200-row Activity window and restart', () {
    final log = const SyncActivityLog.empty().append(
      [for (var i = 0; i < 500; i++) addition(i)],
      observedMembers: {
        '$publisher/$source': {for (var i = 0; i < 500; i++) 'member:$i'},
      },
    );
    expect(log.entries, hasLength(200));
    expect(log.pendingPosts, hasLength(500));
    expect(log.toJson()['version'], 1);
    final restored = SyncActivityLog.fromJson(
      Map<String, dynamic>.from(log.toJson()),
    );
    expect(restored, log);
    expect(restored.pendingPosts.first.sequence, 1);
    expect(restored.pendingPosts.last.sequence, 500);
    final partial = restored.acknowledgePostsThrough(200);
    expect(partial.pendingPosts, hasLength(300));
    expect(partial.follows(restored), isTrue);
    final completed = partial.acknowledgePostsThrough(500);
    expect(completed.pendingPosts, isEmpty);
    expect(completed.entries, restored.entries);
    expect(completed.notificationKnown, restored.notificationKnown);
    expect(completed.follows(partial), isTrue);
  });

  test('known identities survive removal and notification acknowledgement', () {
    final log = const SyncActivityLog.empty()
        .append(
          [addition(1)],
          observedMembers: {
            '$publisher/$source': {'member:1'},
          },
        )
        .acknowledgePostsThrough(1);
    final removed = log.append(
      [
        SyncEvent(
          kind: SyncEventKind.received,
          at: at,
          publisher: publisher,
          source: source,
          removed: 1,
        ),
      ],
      observedMembers: {'$publisher/$source': {}},
    );
    expect(removed.notificationKnown['$publisher/$source'], {'member:1'});
    expect(removed.follows(log), isTrue);
    final restored = SyncActivityLog.fromJson(
      Map<String, dynamic>.from(removed.toJson()),
    );
    expect(restored.notificationKnown, log.notificationKnown);
  });

  test('dropping journaled intent or rolling its cursor back fails the follows guard', () {
    final log = const SyncActivityLog.empty().append([addition(1)]);
    final encoded = Map<String, dynamic>.from(log.toJson());
    encoded['notifications'] = {
      ...encoded['notifications'] as Map,
      'pending': <Object?>[],
    };
    final dropped = SyncActivityLog.fromJson(encoded);
    expect(dropped.follows(log), isFalse);
    final acknowledged = log.acknowledgePostsThrough(1);
    expect(log.follows(acknowledged), isFalse);
    expect(() => log.acknowledgePostsThrough(2), throwsFormatException);
  });
}
