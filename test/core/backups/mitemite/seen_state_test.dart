import 'dart:convert';

import 'package:boorusama/core/backups/mitemite/protocol.dart';
import 'package:boorusama/core/backups/mitemite/seen_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_mirror_state.dart';
import 'package:flutter_test/flutter_test.dart';

SyncCollectionId group({
  String source = '10000000-0000-4000-8000-000000000002',
}) => SyncCollectionId(
  publisher: '10000000-0000-4000-8000-000000000001',
  kind: 'bookmarks',
  source: source,
);

void main() {
  test('validates 7000 targets against one decoded owner snapshot', () {
    final collection = group();
    const localId = '10000000-0000-4000-8000-000000000010';
    final keys = {for (var i = 0; i < 7000; i++) 'post-$i'};
    final state = SyncGroupSeenState.empty(collection).applyMembership(
      revision: 1,
      members: keys,
    );
    final resolver = BookmarkSeenTargetResolver(
      BookmarkMirrorState(
        epoch: 1,
        owners: {
          localId: BookmarkMirrorOwner(
            publisher: collection.publisher,
            source: collection.source,
            revision: 1,
            payloadDigest: syncDigest(const []),
            groupDigest: syncDigest(const []),
            reading: state.toJson(),
          ),
        },
      ),
    );
    final seen = resolver.forGroup(localId)!;
    for (final key in keys) {
      expect(
        resolver.contains(
          BookmarkSeenTarget(
            groupId: localId,
            publisher: collection.publisher,
            source: collection.source,
            member: key,
          ),
        ),
        isTrue,
      );
    }
    expect(resolver.forGroup(localId), same(seen));
    expect(seen.markSeen(keys).unseenMembers, isEmpty);
  });

  test('legacy arrival receipts never change persistent Unseen members', () {
    final received = SyncGroupSeenState.empty(group()).applyMembership(
      revision: 1,
      members: {'post-a', 'post-b'},
    );
    expect(received.arrivals, {'post-a', 'post-b'});
    final opened = received.acknowledgeArrival(renderedRevision: 1);
    expect(opened.arrivals, isEmpty);
    expect(opened.hasUnseenChange, isFalse);
    expect(opened.unseenMembers, {'post-a', 'post-b'});
  });

  test(
    'Mark Seen changes selected current members while retaining legacy arrival data',
    () {
      final state = SyncGroupSeenState.empty(group()).applyMembership(
        revision: 1,
        members: {'post-a', 'post-b'},
      );
      expect(state.canMarkSeen({}), isFalse);
      expect(state.canMarkSeen({'other'}), isFalse);
      expect(state.canMarkSeen({'post-a'}), isTrue);
      final read = state.markSeen({'post-a', 'other'});
      expect(read.seenMembers, {'post-a'});
      expect(read.unseenMembers, {'post-b'});
      expect(read.arrivals, state.arrivals);
      expect(read.canMarkSeen({'post-a'}), isFalse);
      expect(read.canMarkSeen({'post-a', 'post-b'}), isTrue);
    },
  );

  test(
    'multiple revisions accumulate arrivals and subtract removed additions',
    () {
      final first = SyncGroupSeenState.empty(group()).applyMembership(
        revision: 1,
        members: {'post-a', 'post-b'},
      );
      final second = first.applyMembership(
        revision: 2,
        members: {'post-b', 'post-c'},
      );
      expect(second.arrivals, {'post-b', 'post-c'});
      expect(second.hasUnseenChange, isTrue);
      final opened = second.acknowledgeArrival(renderedRevision: 2);
      final removal = opened.applyMembership(revision: 3, members: {'post-b'});
      expect(removal.arrivals, isEmpty);
      expect(removal.hasUnseenChange, isTrue);
    },
  );

  test('legacy receipt validation rejects a different membership revision', () {
    final state = SyncGroupSeenState.empty(group())
        .applyMembership(revision: 1, members: {'post-a'})
        .applyMembership(revision: 2, members: {'post-a', 'post-b'});
    expect(state.acknowledgeArrival(renderedRevision: 1).arrivals, {
      'post-a',
      'post-b',
    });
    expect(state.acknowledgeArrival(renderedRevision: 3).arrivals, {
      'post-a',
      'post-b',
    });
  });

  test(
    'metadata-only revisions and removal/rearrival retain local reading',
    () {
      final read = SyncGroupSeenState.empty(group())
          .applyMembership(revision: 1, members: {'post-a'})
          .acknowledgeArrival(renderedRevision: 1)
          .markSeen({'post-a'});
      final renamed = read.applyMembership(revision: 2, members: {'post-a'});
      expect(renamed.hasUnseenChange, isFalse);
      expect(renamed.arrivals, isEmpty);
      final restored = renamed
          .applyMembership(revision: 3, members: {})
          .applyMembership(revision: 4, members: {'post-a'});
      expect(restored.unseenMembers, isEmpty);
      expect(restored.arrivals, {'post-a'});
    },
  );

  test('identity and all independent state survive JSON round trip', () {
    final state = SyncGroupSeenState.empty(group())
        .applyMembership(revision: 3, members: {'post-a', 'post-b'})
        .markSeen({'post-a'});
    final restored = SyncGroupSeenState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
    expect(restored.group, state.group);
    expect(restored.revision, 3);
    expect(restored.seenMembers, {'post-a'});
    expect(restored.arrivals, {'post-a', 'post-b'});
    final other = SyncGroupSeenState.empty(
      group(
        source: '10000000-0000-4000-8000-000000000003',
      ),
    ).applyMembership(revision: 3, members: {'post-a'});
    expect(other.unseenMembers, {'post-a'});
  });

  test(
    'rollback or changed content under same revision cannot replace state',
    () {
      final state = SyncGroupSeenState.empty(group()).applyMembership(
        revision: 3,
        members: {'post-a'},
      );
      expect(
        () => state.applyMembership(revision: 2, members: {}),
        throwsA(isA<SyncConflict>()),
      );
      expect(
        () => state.applyMembership(revision: 3, members: {'post-b'}),
        throwsA(isA<SyncConflict>()),
      );
      expect(
        state.applyMembership(revision: 3, members: {'post-a'}),
        same(state),
      );
    },
  );
}
