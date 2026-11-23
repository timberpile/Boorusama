part of 'bookmark_library_service.dart';

/// Common membership operations commit payloads and organization together. The
/// legacy branch in the service is retained for standalone Post-only adapters.
extension on BookmarkLibraryService {
  Future<BookmarkDraftSaveResult> _saveUnifiedDrafts(
    Iterable<Bookmark> drafts,
    String groupId,
    Iterable<Bookmark> savedRecords,
  ) => unifiedStore!.runReadWriteScope(() async {
    final store = unifiedStore!;
    final target = await _requireUnifiedGroup(groupId);
    // All structures and source interpretations are validated before the
    // durable counter advances. Only proven identities deduplicate.
    final normalized = [
      for (final draft in drafts)
        store.normalizeRecord(bookmarkWithId(draft, 0)),
    ];
    final known = <Object, Bookmark>{};
    final resolved = <Bookmark>[];
    for (final frozen in savedRecords) {
      final current = await store.read(frozen.id);
      if (current == null || !_sameTarget(current, frozen))
        throw StateError('Saved Bookmark changed before the action completed');
      resolved.add(current);
    }
    final pending = <Bookmark>[];
    for (final candidate in normalized) {
      final identity = bookmarkContentIdentity(candidate);
      if (identity == null) {
        pending.add(candidate);
        continue;
      }
      final previous =
          known[identity] ??
          await store.lookupContent(
            identity,
            engine: bookmarkEngine(candidate),
          );
      if (previous != null) {
        store.normalizeRecord(candidate, previous: previous);
        if (!known.containsKey(identity)) resolved.add(previous);
        known[identity] = previous;
      } else {
        known[identity] = candidate;
        pending.add(candidate);
      }
    }
    validateBookmarkCommitGuard();
    final ids = await store.reserveIds(pending.length);
    final created = <Bookmark>[
      for (final (index, draft) in pending.indexed)
        bookmarkWithId(draft, ids[index]),
    ];
    // Pending known records appear exactly once. Resolved existing records
    // are selected by their authoritative IDs rather than draft IDs.
    final selected = <int>{
      for (final record in [...resolved, ...created]) record.id,
    };
    final added = selected.difference(target.bookmarkIds);
    if (added.isNotEmpty || created.isNotEmpty) {
      final now = DateTime.now().toUtc();
      await store.commitOrganization(
        records: created,
        groups: [
          target.copyWith(
            bookmarkIds: {...target.bookmarkIds, ...added},
            addedAt: {...target.addedAt, for (final id in added) id: now},
          ),
        ],
      );
    }
    return (
      addedCount: added.length,
      createdRecords: List<Bookmark>.unmodifiable(created),
    );
  });

  Future<BookmarkGroup> _requireUnifiedGroup(String id) async =>
      await groupRepository.getGroup(id) ??
      (throw StateError('Bookmark Group no longer exists'));

  Future<List<BookmarkGroup>> _duplicateUnifiedGroups(
    Map<String, String> names,
    BookmarkLibraryState snapshot,
  ) => unifiedStore!.runReadWriteScope(() async {
    final copies = snapshot.groupTree.duplicateSubtrees(
      names,
      createId: () => const Uuid().v4().toLowerCase(),
    );
    await unifiedStore!.commitOrganization(groups: copies.groups);
    return copies.roots;
  });

  /// These inputs are frozen saved records, not file-local transfer IDs.
  /// Imports use their own preflight and explicit ID remapping.
  Future<int> _addUnifiedMembers(Iterable<Bookmark> selected, String groupId) =>
      unifiedStore!.runReadWriteScope(() async {
        final store = unifiedStore!;
        final target = await _requireUnifiedGroup(groupId);
        final members = <int>{};
        for (final frozen in selected) {
          final current = await store.read(frozen.id);
          if (current == null || !_sameTarget(current, frozen)) {
            throw StateError(
              'Saved Bookmark changed before the action completed',
            );
          }
          members.add(current.id);
        }
        final added = members.difference(target.bookmarkIds);
        if (added.isEmpty) return 0;
        final now = DateTime.now().toUtc();
        await store.commitOrganization(
          groups: [
            target.copyWith(
              bookmarkIds: {...target.bookmarkIds, ...added},
              addedAt: {...target.addedAt, for (final id in added) id: now},
            ),
          ],
        );
        return added.length;
      });

  Future<BookmarkGroupRemovalResult> _removeUnifiedMembers(
    Iterable<Bookmark> selected,
    String groupId,
    Set<String> poolLocalIds,
  ) => unifiedStore!.runReadWriteScope(() async {
    final snapshot = await _snapshotForMutation();
    final target =
        snapshot.groupsById[groupId] ??
        (throw StateError('Bookmark Group no longer exists'));
    final requested = <int>{};
    for (final frozen in selected) {
      final current = snapshot.byId[frozen.id];
      if (current == null || !_sameTarget(current, frozen)) {
        throw StateError('Saved Bookmark changed before the action completed');
      }
      requested.add(current.id);
    }
    for (final view in snapshot.pools) {
      if (poolLocalIds.contains(view.localId) && view.bookmarkId != null) {
        requested.add(view.bookmarkId!);
      }
    }
    final affected = target.bookmarkIds.intersection(requested);
    if (affected.isEmpty)
      return const BookmarkGroupRemovalResult(removedCount: 0);
    final removed = [for (final id in affected) snapshot.byId[id]!];
    final finalMembership = <int>{
      for (final id in affected)
        if (snapshot.membershipsForId(id).difference({groupId}).isEmpty) id,
    };
    final deleted = [for (final id in finalMembership) snapshot.byId[id]!];
    await unifiedStore!.commitOrganization(
      removeIds: finalMembership,
      groups: [
        target.copyWith(bookmarkIds: target.bookmarkIds.difference(affected)),
      ],
    );
    final media = removed.whereType<PostBookmark>().toList();
    return BookmarkGroupRemovalResult(
      groupId: groupId,
      removedCount: affected.length,
      removedRecords: List.unmodifiable(removed),
      deletedRecords: List.unmodifiable(deleted),
      recordAddedAt: Map.unmodifiable({
        for (final record in removed)
          record.id: target.addedAt[record.id] ?? bookmarkCreatedAt(record),
      }),
      removedBookmarks: List.unmodifiable(media),
      deletedBookmarks: List.unmodifiable(deleted.whereType<PostBookmark>()),
      addedAt: Map.unmodifiable({
        for (final record in media)
          record.uniqueId: target.addedAt[record.id] ?? record.createdAt,
      }),
      removedPools: List.unmodifiable(
        snapshot.pools.where((view) => affected.contains(view.bookmarkId)),
      ),
    );
  });

  Future<void> _undoUnifiedRemoval(
    BookmarkGroupRemovalResult removal,
  ) => unifiedStore!.runReadWriteScope(() async {
    final store = unifiedStore!;
    final groupId = removal.groupId;
    if (groupId == null) return;
    final target = await _requireUnifiedGroup(groupId);
    final deletedIds = removal.deletedRecords
        .map((record) => record.id)
        .toSet();
    final resolved = <int, Bookmark>{};
    final recreate = <Bookmark>[];
    for (final old in removal.removedRecords) {
      var current = await store.read(old.id);
      if (current != null && !_sameTarget(current, old)) {
        throw StateError('Saved Bookmark changed before Undo');
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
        resolved[old.id] = current;
      } else if (deletedIds.contains(old.id)) {
        // Validate snapshots before reserving replacement slots. Opaque
        // records have no semantic key and are recreated independently.
        recreate.add(store.normalizeRecord(old));
      }
    }
    final newIds = await store.reserveIds(recreate.length);
    final writes = <Bookmark>[];
    for (final (index, old) in recreate.indexed) {
      final record = bookmarkWithId(old, newIds[index]);
      resolved[old.id] = record;
      writes.add(record);
    }
    final addedAt = Map<int, DateTime>.of(target.addedAt);
    final members = Set<int>.of(target.bookmarkIds);
    for (final old in removal.removedRecords) {
      final current = resolved[old.id];
      if (current == null || !members.add(current.id)) continue;
      addedAt[current.id] =
          removal.recordAddedAt[old.id] ?? bookmarkCreatedAt(old);
    }
    final updated = target.copyWith(bookmarkIds: members, addedAt: addedAt);
    try {
      await store.commitOrganization(records: writes, groups: [updated]);
    } catch (error, stack) {
      // A committed-then-throw Undo must not create another opaque record on
      // retry. Re-entering the facade first finishes durable journal replay.
      try {
        final actual = await groupRepository.getGroup(groupId);
        final matches =
            actual != null &&
            members.every(
              (id) =>
                  actual.bookmarkIds.contains(id) &&
                  actual.addedAt[id] == addedAt[id],
            );
        if (matches) {
          var complete = true;
          for (final record in writes) {
            if (await store.read(record.id) != record) complete = false;
          }
          if (complete) return;
        }
      } catch (_) {}
      Error.throwWithStackTrace(error, stack);
    }
  });

  Future<void> _deleteUnifiedRecords(Iterable<Bookmark> selected) =>
      unifiedStore!.runReadWriteScope(() async {
        final store = unifiedStore!;
        final ids = <int>{};
        for (final frozen in selected) {
          final current = await store.read(frozen.id);
          if (current == null) continue;
          if (!_sameTarget(current, frozen)) {
            throw StateError('Saved Bookmark changed before deletion');
          }
          ids.add(current.id);
        }
        if (ids.isEmpty) return;
        await store.commitOrganization(
          removeIds: ids,
          groups: [
            for (final group in await groupRepository.getGroups())
              if (group.bookmarkIds.any(ids.contains))
                group.copyWith(bookmarkIds: group.bookmarkIds.difference(ids)),
          ],
        );
      });

  Future<BookmarkGroupDeletionPreview> _deleteUnifiedGroup(String id) async =>
      (await deleteHierarchy({id})).singlePreview;
}

bool _sameTarget(Bookmark current, Bookmark frozen) =>
    current.id == frozen.id &&
    current.runtimeType == frozen.runtimeType &&
    bookmarkEngine(current) == bookmarkEngine(frozen) &&
    bookmarkContentIdentity(current) == bookmarkContentIdentity(frozen);
