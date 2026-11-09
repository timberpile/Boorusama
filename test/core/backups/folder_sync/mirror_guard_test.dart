import 'dart:async';

import 'package:boorusama/core/backups/folder_sync/mirror_guard.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/search/following_topics/src/types/topic_organization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '10000000-0000-4000-8000-000000000001';
  final group = BookmarkGroup(id: id, name: 'Received', bookmarkIds: {1, 2});
  late CollectionMirrorGuard guard;
  setUp(
    () => guard = CollectionMirrorGuard()
      ..replaceBindings([id])
      ..replaceFollowingBindings([id]),
  );

  test('renaming and moving retain writable local ownership', () {
    expect(
      () => guard.validate(
        currentGroups: [group],
        groups: [group.copyWith(name: 'Local', position: 4)],
      ),
      returnsNormally,
    );
  });
  test('all membership and underlying record deletion paths fail closed', () {
    expect(
      () => guard.validate(
        currentGroups: [group],
        groups: [
          group.copyWith(bookmarkIds: {1}),
        ],
      ),
      throwsA(isA<CollectionMirrorReadOnly>()),
    );
    expect(
      () => guard.validate(currentGroups: [group], removeIds: {1}),
      throwsA(isA<CollectionMirrorReadOnly>()),
    );
    expect(
      () => guard.validate(currentGroups: [group], removeGroupIds: {id}),
      throwsA(isA<CollectionMirrorReadOnly>()),
    );
  });
  test(
    'received transaction authority is scoped and cannot leak to later edits',
    () async {
      await guard.applyReceived(() async {
        guard.validate(
          currentGroups: [group],
          groups: [
            group.copyWith(bookmarkIds: {3}),
          ],
        );
      });
      expect(
        () => guard.validate(
          currentGroups: [group],
          groups: [
            group.copyWith(bookmarkIds: {3}),
          ],
        ),
        throwsA(isA<CollectionMirrorReadOnly>()),
      );
    },
  );
  test('confirmed subtree deletion removes mirror without changing outside mirrors', () async {
    await guard.deleteLocalSubtree(() async {
      guard.validate(
        currentGroups: [group],
        removeGroupIds: {id},
        removeIds: {1, 2},
      );
      expect(
        () => guard.validate(currentGroups: [group], removeIds: {1}),
        throwsA(isA<CollectionMirrorReadOnly>()),
      );
    });
  });
  test(
    'Following local name/read/cache changes are distinct from definitions',
    () {
      guard.validateFollowingEdit(id, definitionChanged: false);
      expect(
        () => guard.validateFollowingEdit(id, definitionChanged: true),
        throwsA(isA<CollectionMirrorReadOnly>()),
      );
      final before = TopicOrganization(
        folders: [TopicFolder(id: id, name: 'Received', feedEnabled: true)],
      );
      final renamed = TopicOrganization(
        folders: [TopicFolder(id: id, name: 'Local', feedEnabled: true)],
      );
      guard.validateFollowingOrganization(before, renamed);
      final changed = TopicOrganization(
        folders: [TopicFolder(id: id, name: 'Local', feedEnabled: false)],
      );
      expect(
        () => guard.validateFollowingOrganization(before, changed),
        throwsA(isA<CollectionMirrorReadOnly>()),
      );
    },
  );
  test('late callbacks lose completed receive and deletion grants', () async {
    late void Function() lateWrite;
    await guard.applyReceived(() async {
      lateWrite = Zone.current.bindCallback(
        () => guard.validate(
          currentGroups: [group],
          groups: [
            group.copyWith(bookmarkIds: {9}),
          ],
        ),
      );
    });
    expect(lateWrite, throwsA(isA<CollectionMirrorReadOnly>()));
    await guard.deleteLocalSubtree(() async {
      lateWrite = Zone.current.bindCallback(
        () => guard.validate(currentGroups: [group], removeGroupIds: {id}),
      );
    });
    expect(lateWrite, throwsA(isA<CollectionMirrorReadOnly>()));
  });
}
