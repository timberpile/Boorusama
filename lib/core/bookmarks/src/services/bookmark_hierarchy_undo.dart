part of 'bookmark_library_service.dart';

/// An in-memory receipt for one confirmed local deletion. It retains only the
/// affected groups and their direct records, never a second library snapshot.
final class BookmarkHierarchyDeletion {
  BookmarkHierarchyDeletion._({
    required Iterable<BookmarkGroup> deletedGroups,
    required Map<int, Bookmark> recordsBefore,
    required Set<int> deletedRecordIds,
    required this.requestedRootId,
    required Iterable<BookmarkGroup> promotedChildrenBefore,
    required Iterable<BookmarkGroup> promotedChildrenAfter,
  }) : deletedGroups = List.unmodifiable(deletedGroups),
       recordsBefore = Map.unmodifiable(recordsBefore),
       deletedRecordIds = Set.unmodifiable(deletedRecordIds),
       promotedChildrenBefore = List.unmodifiable(promotedChildrenBefore),
       promotedChildrenAfter = List.unmodifiable(promotedChildrenAfter);

  final List<BookmarkGroup> deletedGroups;
  final Map<int, Bookmark> recordsBefore;
  final Set<int> deletedRecordIds;
  final String requestedRootId;
  final List<BookmarkGroup> promotedChildrenBefore;
  final List<BookmarkGroup> promotedChildrenAfter;

  BookmarkGroupDeletionPreview get singlePreview {
    final group = deletedGroups.firstWhere(
      (group) => group.id == requestedRootId,
    );
    return BookmarkGroupDeletionPreview(
      group: group,
      orphanBookmarkIds: deletedRecordIds,
      descendantGroups: deletedGroups
          .where((child) => child.id != group.id)
          .toList(),
    );
  }
}

extension BookmarkHierarchyOperations on BookmarkLibraryService {
  Future<BookmarkHierarchyDeletion> deleteHierarchy(
    Set<String> groupIds, {
    BookmarkCollectionDeletionPreview? expectedPreview,
  }) => _scope(() async {
    final store =
        unifiedStore ??
        (throw StateError('Hierarchy deletion requires unified storage'));
    final groups = await groupRepository.getGroups();
    if (groupIds.isEmpty ||
        !groups.map((group) => group.id).toSet().containsAll(groupIds) ||
        groupIds.contains(defaultBookmarkGroupId)) {
      throw ArgumentError('Invalid local Group deletion');
    }
    final before = await _snapshotForMutation();
    final preview = BookmarkCollectionDeletionPreview.from(
      before,
      folderIds: expectedPreview?.selectedFolderIds ?? const {},
      groupIds: expectedPreview?.selectedGroupIds ?? groupIds,
    );
    final requestedClosure = {
      for (final root in before.groupTree.selectionRoots(groupIds))
        ...before.groupTree.subtreeIds(root.id),
    };
    if (expectedPreview != null &&
        (preview != expectedPreview ||
            !const SetEquality<String>().equals(
              requestedClosure,
              preview.groupIds,
            )))
      throw BookmarkCollectionChangedException(preview);
    final removedIds = preview.groupIds;
    final promoted = <BookmarkGroup>[];
    final removed = before.groups
        .where((group) => removedIds.contains(group.id))
        .toList();
    final members = {for (final group in removed) ...group.bookmarkIds};
    final receipt = BookmarkHierarchyDeletion._(
      requestedRootId: before.groupTree.selectionRoots(groupIds).first.id,
      deletedGroups: removed,
      recordsBefore: {
        for (final id in members)
          id:
              before.byId[id] ??
              (throw StateError('Group member no longer exists')),
      },
      deletedRecordIds: preview.orphanBookmarkIds,
      promotedChildrenAfter: promoted,
      promotedChildrenBefore: [
        for (final group in promoted) before.groupsById[group.id]!,
      ],
    );
    try {
      Future<void> commit() => store.commitOrganization(
        removeIds: receipt.deletedRecordIds,
        removeGroupIds: removedIds,
        groups: promoted,
      );
      await commit();
    } catch (error, stack) {
      try {
        // A read first resolves an interrupted journal. Confirm the complete
        // write before offering Undo for a committed-then-throw deletion.
        final current = {
          for (final group in await groupRepository.getGroups())
            group.id: group,
        };
        var complete =
            removedIds.every((id) => !current.containsKey(id)) &&
            promoted.every(
              (group) => _sameHierarchyGroup(current[group.id], group),
            );
        for (final id in receipt.deletedRecordIds) {
          if (await store.read(id) != null) complete = false;
        }
        if (complete) return receipt;
      } catch (_) {}
      Error.throwWithStackTrace(error, stack);
    }
    return receipt;
  });

  Future<void> undoHierarchyDeletion(
    BookmarkHierarchyDeletion deletion,
  ) => _scope(() async {
    final store =
        unifiedStore ??
        (throw StateError('Hierarchy Undo requires unified storage'));
    final groups = await groupRepository.getGroups();
    final byGroup = {for (final group in groups) group.id: group};
    if (deletion.deletedGroups.any((group) => byGroup.containsKey(group.id))) {
      throw StateError('A Group identity was recreated before Undo');
    }
    final oldChildren = {
      for (final group in deletion.promotedChildrenBefore) group.id: group,
    };
    final childUpdates = <BookmarkGroup>[];
    for (final expected in deletion.promotedChildrenAfter) {
      final current = byGroup[expected.id];
      // A later explicit deletion wins; Undo never resurrects that child.
      if (current == null) continue;
      if (current.parentGroupId != expected.parentGroupId ||
          current.position != expected.position) {
        throw StateError('A newer Group move superseded Undo');
      }
      final before = oldChildren[current.id]!;
      childUpdates.add(
        current.copyWith(
          parentGroupId: before.parentGroupId,
          home: before.parentGroupId == null,
          position: before.position,
        ),
      );
    }
    // Validate all parent references and newer edits before reserving payload
    // IDs. This tree has placeholder direct IDs, which cannot affect structure.
    BookmarkGroupTree([
      for (final group in groups)
        if (!oldChildren.containsKey(group.id)) group,
      ...childUpdates,
      ...deletion.deletedGroups,
    ]);
    final resolved = <int, Bookmark>{};
    final recreate = <Bookmark>[];
    for (final entry in deletion.recordsBefore.entries) {
      final old = entry.value;
      var current = await store.read(old.id);
      if (current != null && !_sameTarget(current, old)) {
        throw StateError('A saved record changed before hierarchy Undo');
      }
      if (current == null && !deletion.deletedRecordIds.contains(old.id)) {
        throw StateError('A newer record deletion superseded Undo');
      }
      if (current == null) {
        if (bookmarkContentIdentity(old) case final identity?) {
          current = await store.lookupContent(
            identity,
            engine: bookmarkEngine(old),
          );
        }
      }
      if (current != null) {
        store.normalizeRecord(old, previous: current);
        resolved[entry.key] = current;
      } else {
        recreate.add(store.normalizeRecord(old));
      }
    }
    final reserved = await store.reserveIds(recreate.length);
    final writes = <Bookmark>[];
    for (final (index, old) in recreate.indexed) {
      final record = bookmarkWithId(old, reserved[index]);
      writes.add(record);
      resolved[old.id] = record;
    }
    final restored = [
      for (final group in deletion.deletedGroups)
        group.copyWith(
          bookmarkIds: {for (final id in group.bookmarkIds) resolved[id]!.id},
          addedAt: {
            for (final id in group.bookmarkIds)
              resolved[id]!.id:
                  group.addedAt[id] ??
                  bookmarkCreatedAt(deletion.recordsBefore[id]!),
          },
        ),
    ];
    final changed = [...restored, ...childUpdates];
    try {
      await store.commitOrganization(records: writes, groups: changed);
    } catch (error, stack) {
      try {
        final actual = {
          for (final group in await groupRepository.getGroups())
            group.id: group,
        };
        var complete = changed.every(
          (group) => _sameHierarchyGroup(actual[group.id], group),
        );
        for (final record in writes) {
          if (await store.read(record.id) != record) complete = false;
        }
        if (complete) return;
      } catch (_) {}
      Error.throwWithStackTrace(error, stack);
    }
  });
}

bool _sameHierarchyGroup(BookmarkGroup? a, BookmarkGroup b) =>
    a != null &&
    a.id == b.id &&
    a.name == b.name &&
    a.parentGroupId == b.parentGroupId &&
    a.folderId == b.folderId &&
    a.position == b.position &&
    const SetEquality<int>().equals(a.bookmarkIds, b.bookmarkIds) &&
    const MapEquality<int, DateTime>().equals(a.addedAt, b.addedAt);
