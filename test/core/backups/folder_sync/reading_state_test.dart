import 'dart:convert';

import 'package:boorusama/core/backups/folder_sync/protocol.dart';
import 'package:boorusama/core/backups/folder_sync/reading_state.dart';
import 'package:flutter_test/flutter_test.dart';

SyncCollectionId group({String source = '10000000-0000-4000-8000-000000000002'}) =>
    SyncCollectionId(
      publisher: '10000000-0000-4000-8000-000000000001',
      kind: 'bookmarks',
      source: source,
    );

void main() {
  test('Group opening acknowledges arrivals but never reads Posts', () {
    final received = SyncGroupReadingState.empty(group()).applyMembership(
      revision: 1, members: {'post-a', 'post-b'},
    );
    expect(received.arrivals, {'post-a', 'post-b'});
    final opened = received.acknowledgeArrival(renderedRevision: 1);
    expect(opened.arrivals, isEmpty);
    expect(opened.hasUnseenChange, isFalse);
    expect(opened.unreadMembers, {'post-a', 'post-b'});
  });

  test('Mark Read changes only selected current members, not arrival notice', () {
    final state = SyncGroupReadingState.empty(group()).applyMembership(
      revision: 1, members: {'post-a', 'post-b'},
    );
    expect(state.canMarkRead({}), isFalse);
    expect(state.canMarkRead({'other'}), isFalse);
    expect(state.canMarkRead({'post-a'}), isTrue);
    final read = state.markRead({'post-a', 'other'});
    expect(read.readMembers, {'post-a'});
    expect(read.unreadMembers, {'post-b'});
    expect(read.arrivals, state.arrivals);
    expect(read.canMarkRead({'post-a'}), isFalse);
    expect(read.canMarkRead({'post-a', 'post-b'}), isTrue);
  });

  test('multiple revisions accumulate arrivals and subtract removed additions', () {
    final first = SyncGroupReadingState.empty(group()).applyMembership(
      revision: 1, members: {'post-a', 'post-b'},
    );
    final second = first.applyMembership(revision: 2, members: {'post-b', 'post-c'});
    expect(second.arrivals, {'post-b', 'post-c'});
    expect(second.hasUnseenChange, isTrue);
    final opened = second.acknowledgeArrival(renderedRevision: 2);
    final removal = opened.applyMembership(revision: 3, members: {'post-b'});
    expect(removal.arrivals, isEmpty);
    expect(removal.hasUnseenChange, isTrue);
  });

  test('a delayed frame cannot acknowledge a newer, unrendered revision', () {
    final state = SyncGroupReadingState.empty(group())
        .applyMembership(revision: 1, members: {'post-a'})
        .applyMembership(revision: 2, members: {'post-a', 'post-b'});
    expect(state.acknowledgeArrival(renderedRevision: 1).arrivals,
        {'post-a', 'post-b'});
    expect(state.acknowledgeArrival(renderedRevision: 3).arrivals,
        {'post-a', 'post-b'});
  });

  test('metadata-only revisions and removal/rearrival retain local reading', () {
    final read = SyncGroupReadingState.empty(group())
        .applyMembership(revision: 1, members: {'post-a'})
        .acknowledgeArrival(renderedRevision: 1)
        .markRead({'post-a'});
    final renamed = read.applyMembership(revision: 2, members: {'post-a'});
    expect(renamed.hasUnseenChange, isFalse);
    expect(renamed.arrivals, isEmpty);
    final restored = renamed
        .applyMembership(revision: 3, members: {})
        .applyMembership(revision: 4, members: {'post-a'});
    expect(restored.unreadMembers, isEmpty);
    expect(restored.arrivals, {'post-a'});
  });

  test('identity and all independent state survive JSON round trip', () {
    final state = SyncGroupReadingState.empty(group())
        .applyMembership(revision: 3, members: {'post-a', 'post-b'})
        .markRead({'post-a'});
    final restored = SyncGroupReadingState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );
    expect(restored.group, state.group);
    expect(restored.revision, 3);
    expect(restored.readMembers, {'post-a'});
    expect(restored.arrivals, {'post-a', 'post-b'});
    final other = SyncGroupReadingState.empty(group(
      source: '10000000-0000-4000-8000-000000000003',
    )).applyMembership(revision: 3, members: {'post-a'});
    expect(other.unreadMembers, {'post-a'});
  });

  test('rollback or changed content under same revision cannot replace state', () {
    final state = SyncGroupReadingState.empty(group()).applyMembership(
      revision: 3, members: {'post-a'},
    );
    expect(
      () => state.applyMembership(revision: 2, members: {}),
      throwsA(isA<SyncConflict>()),
    );
    expect(
      () => state.applyMembership(revision: 3, members: {'post-b'}),
      throwsA(isA<SyncConflict>()),
    );
    expect(state.applyMembership(revision: 3, members: {'post-a'}), same(state));
  });
}
