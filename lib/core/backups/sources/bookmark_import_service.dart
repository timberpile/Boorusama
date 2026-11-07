// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../export_import/models/import_action.dart';
import '../../bookmarks/types.dart';
import '../../groups/folder_tree.dart';

import 'package:uuid/uuid.dart';

import '../../posts/post/types.dart';
import 'bookmark_import_plan.dart';
import 'bookmark_backup_data.dart';
import 'bookmark_import_planner.dart';
import 'bookmark_unified_import.dart';
import '../../bookmarks/src/types/bookmark_record_fields.dart';
import '../../bookmarks/src/types/legacy_group_bookmark.dart';
import '../../bookmarks/src/services/bookmark_library_service.dart';

class BookmarkImportResult extends Equatable {
  const BookmarkImportResult({
    required this.totalCount,
    required this.alreadyExistedCount,
    required this.groupCount,
  });

  final int totalCount;
  final int alreadyExistedCount;
  final int groupCount;

  @override
  List<Object?> get props => [totalCount, alreadyExistedCount, groupCount];
}

class BookmarkImportRollbackException implements Exception {
  const BookmarkImportRollbackException({
    required this.importError,
    required this.rollbackErrors,
  });

  final Object importError;
  final List<Object> rollbackErrors;
}

class BookmarkImportService {
  const BookmarkImportService({
    required this.bookmarkRepository,
    required this.groupRepository,
    required this.imageUrlResolver,
    this.importFolderName = 'Imported Groups',
  });

  final BookmarkRepository bookmarkRepository;
  final BookmarkGroupRepository groupRepository;
  final String importFolderName;
  final ImageUrlResolver Function(int? booruId) imageUrlResolver;

  UnifiedBookmarkStore? get _unified =>
      groupRepository is UnifiedBookmarkOrganization
      ? unifiedBookmarkStorage(bookmarkRepository)
      : null;

  Future<BookmarkImportResult> _commitUnified(
    BookmarkImportPlan plan, {
    bool replace = false,
    Set<int> removeIds = const {},
  }) async {
    final store = _unified!;
    return store.runReadWriteScope(() async {
      final prepared = BookmarkImportPreparation.prepare(
        plan: plan,
        currentRecords: await store.readAll(),
        currentGroups: await groupRepository.getGroups(),
        currentFolders: await groupRepository.getFolders(),
        normalize: store.normalizeRecord,
        replace: replace,
        removeIds: removeIds,
        importFolderName: importFolderName,
      );
      final write = prepared.materialize(
        await store.reserveIds(prepared.newIds.length),
      );
      await store.commitOrganization(
        records: write.records,
        removeIds: write.removeIds,
        groups: write.groups,
        removeGroupIds: write.removeGroupIds,
        folders: write.folders,
      );
      return BookmarkImportResult(
        totalCount: prepared.newIds.length + prepared.alreadyExistedCount,
        alreadyExistedCount: prepared.alreadyExistedCount,
        groupCount: plan.groups.length,
      );
    });
  }

  void _requireLegacyFixtureRecords(Iterable<Bookmark> records) {
    if (records.any(
      (record) => switch (record) {
        ContentGroupBookmark() => true,
        LegacyRelatedGroupBookmark(:final preferredOrder) =>
          preferredOrder != null,
        PostBookmark(:final postId) => postId == null,
        _ => false,
      },
    )) {
      throw StateError('Unified Bookmark storage is required for this import');
    }
  }

  // Standalone legacy repositories are retained for pre-cutover fixtures only.
  // Their UUID-shaped Pool views are derived; production uses the common commit.
  List<CollectionBookmark> _legacyPools(List<CollectionBookmark> pools) => [
    for (final p in pools)
      p.copyWith(
        localId: Uuid.isValidUUID(fromString: p.localId)
            ? p.localId
            : const Uuid().v5(
                Namespace.url.value,
                'bookmark-file:${p.localId}',
              ),
      ),
  ];

  Future<void> replace(BookmarkBackupData data) async {
    if (_unified != null) {
      final plan = const BookmarkImportPlanner().plan(
        data: data,
        currentBookmarks: await _unified!.readAll(),
        currentGroups: await groupRepository.getGroups(),
      );
      await _commitUnified(
        plan.resolveActions({
          for (final g in plan.groups)
            g.id: g.resolveAction(ImportAction.replace),
        }),
        replace: true,
      );
      return;
    }
    _requireLegacyFixtureRecords(data.records);
    _validateReferences(
      _legacyPools(data.pools),
      data.groups.map((g) => g.id).nonNulls.toSet(),
    );
    FolderTree(data.folders).validatePlacements([
      for (final (i, g) in data.groups.indexed)
        FolderPlacement(
          itemId: g.id ?? 'legacy-$i',
          folderId: g.folderId,
          position: g.position,
        ),
    ]);
    final oldGroups = await groupRepository.getGroups();
    final oldFolders = await groupRepository.getFolders();
    final oldPools = await groupRepository.getPoolBookmarks();
    final oldBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    try {
      for (final g in oldGroups) {
        if (g.isDefault) {
          await groupRepository.replaceMemberships(g.id, {});
        } else {
          await groupRepository.deleteGroup(g.id);
        }
      }
      if (oldBookmarks.isNotEmpty)
        await bookmarkRepository.removeBookmarks(oldBookmarks);
      final saved = await bookmarkRepository.addBookmarkWithBookmarks(
        data.bookmarks,
      );
      final savedByIdentity = {for (final b in saved) b.transferIdentity: b.id};
      final importedIds = {
        for (final b in data.bookmarks)
          b.id: savedByIdentity[b.transferIdentity],
      };
      final sourceById = {for (final b in data.bookmarks) b.id: b};
      final restored = <BookmarkGroup>[];
      for (final g in data.groups) {
        final group =
            (g.isDefault
                ? await groupRepository.getGroup(defaultBookmarkGroupId)
                : null) ??
            await groupRepository.createGroup(g.name, id: g.id);
        final members = await groupRepository.replaceMemberships(
          group.id,
          {
            for (final id in g.bookmarkIds)
              if (importedIds[id] != null) importedIds[id]!,
          },
          addedAt: {
            for (final id in g.bookmarkIds)
              if (importedIds[id] != null)
                importedIds[id]!: g.addedAt[id] ?? sourceById[id]!.createdAt,
          },
        );
        restored.add(
          members.copyWith(
            folderId: g.folderId,
            parentGroupId: g.parentGroupId,
            position: g.position,
          ),
        );
      }
      await groupRepository.replaceFolderOrganization(data.folders, restored);
      await _ensureDefault();
      await groupRepository.replacePoolBookmarks(_legacyPools(data.pools));
    } catch (error, stack) {
      final errors = await _rollback(
        oldGroups: oldGroups,
        oldPools: oldPools,
        oldFolders: oldFolders,
        oldGroupIds: oldGroups.map((g) => g.id).toSet(),
        oldBookmarks: oldBookmarks,
      );
      if (errors.isNotEmpty)
        throw BookmarkImportRollbackException(
          importError: error,
          rollbackErrors: errors,
        );
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<BookmarkImportResult> apply(
    BookmarkImportPlan plan, {
    Set<int> removeIds = const {},
  }) async {
    if (_unified != null) return _commitUnified(plan, removeIds: removeIds);
    _requireLegacyFixtureRecords(plan.records);
    if (!plan.isResolved) throw StateError('Import conflicts are unresolved.');
    _validateReferences(
      _legacyPools(plan.pools),
      plan.groups.map((g) => g.id).toSet(),
    );
    final oldGroups = await groupRepository.getGroups();
    final oldFolders = await groupRepository.getFolders();
    final oldPools = await groupRepository.getPoolBookmarks();
    final sourceTree = FolderTree(plan.folders);
    sourceTree.validatePlacements([
      for (final g in plan.groups)
        FolderPlacement(
          itemId: g.id,
          folderId: g.folderId,
          position: g.position,
        ),
    ]);
    final createdPlacements = <String, FolderPlacement>{};
    final oldGroupIds = oldGroups.map((group) => group.id).toSet();
    final oldBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
      imageUrlResolver: imageUrlResolver,
    );
    final missingBookmarks = plan.bookmarks
        .where(
          (b) => !oldBookmarks.any(
            (old) =>
                bookmarkContentIdentity(old) != null &&
                bookmarkContentIdentity(old) == bookmarkContentIdentity(b) &&
                bookmarkEngine(old) == bookmarkEngine(b),
          ),
        )
        .toList();
    var addedBookmarks = const <PostBookmark>[];
    final orphanCandidates = <int>{};
    final oldDates = {for (final b in oldBookmarks) b.id: b.createdAt.toUtc()};
    Map<int, DateTime> preservedDates(BookmarkGroup group) => {
      for (final id in group.bookmarkIds)
        if ((group.addedAt[id] ?? oldDates[id]) case final date?) id: date,
    };
    try {
      for (final b in oldBookmarks) {
        if (removeIds.contains(b.id))
          await bookmarkRepository.removeBookmark(b);
      }
      final copies = plan.groups
          .where((g) => !g.isDefault && g.resolvedAction == ImportAction.copy)
          .toList();
      if (copies.isNotEmpty && groupRepository is BookmarkFolderRepository) {
        final hierarchy = planFolderHierarchyCopy(
          current: oldFolders,
          incoming: plan.folders,
          itemFolders: copies.map((g) => g.folderId),
          wrapperName: importFolderName,
          newId: () => const Uuid().v4(),
        );
        await groupRepository.replaceFolderOrganization(
          hierarchy.folders,
          oldGroups,
        );
        for (final g in copies) {
          final id =
              g.destinationId ??
              (oldGroupIds.contains(g.id) ? const Uuid().v4() : g.id);
          createdPlacements[g.id] = FolderPlacement(
            itemId: id,
            folderId: g.folderId == null
                ? hierarchy.wrapperId
                : hierarchy.folderIds[g.folderId],
            position: g.position,
          );
        }
      }
      if (missingBookmarks.isNotEmpty) {
        addedBookmarks = await bookmarkRepository.addBookmarkWithBookmarks(
          missingBookmarks,
        );
      }
      final savedByIdentity = {
        for (final b in [...oldBookmarks, ...addedBookmarks])
          b.transferIdentity: b.id,
      };
      final localIds = {
        for (final b in plan.bookmarks)
          b.id: savedByIdentity[b.transferIdentity],
      };

      final poolGroupTargets = <String, String>{};
      final replacedPoolGroups = <String>{};
      for (final imported in plan.groups) {
        final action = imported.resolvedAction!;
        if (action == ImportAction.skip) continue;
        final membershipIds = imported.bookmarkIds
            .map((id) => localIds[id])
            .nonNulls
            .toSet();
        final incomingDates = {
          for (final entry in imported.addedAt.entries)
            if (localIds[entry.key] case final id?) id: entry.value,
        };
        if (imported.isDefault) {
          if (await groupRepository.getGroup(defaultBookmarkGroupId) == null) {
            await groupRepository.createGroup(
              'Default',
              id: defaultBookmarkGroupId,
            );
          }
          final current = (await groupRepository.getGroup(
            defaultBookmarkGroupId,
          ))!;
          await groupRepository.replaceMemberships(
            defaultBookmarkGroupId,
            {
              ...current.bookmarkIds,
              ...membershipIds,
            },
            addedAt: {...incomingDates, ...preservedDates(current)},
          );
          poolGroupTargets[imported.id] = defaultBookmarkGroupId;
          continue;
        }
        final existingId = action == ImportAction.mergeIntoTarget
            ? imported.targetId
            : imported.id;
        if (existingId == null) {
          throw StateError('Merge target is unresolved.');
        }
        final existing = await groupRepository.getGroup(existingId);
        if (action == ImportAction.mergeIntoTarget && existing == null) {
          throw StateError('Merge target is unavailable.');
        }
        if (existing == null) {
          final destinationId =
              createdPlacements[imported.id]?.itemId ??
              imported.destinationId ??
              imported.id;
          await groupRepository.createGroup(imported.name, id: destinationId);
          await groupRepository.replaceMemberships(
            destinationId,
            membershipIds,
            addedAt: incomingDates,
          );
          poolGroupTargets[imported.id] = destinationId;
          continue;
        }
        poolGroupTargets[imported.id] = action == ImportAction.copy
            ? createdPlacements[imported.id]?.itemId ??
                  imported.destinationId ??
                  imported.id
            : existingId;
        if (action == ImportAction.update || action == ImportAction.replace) {
          replacedPoolGroups.add(existingId);
        }
        switch (action) {
          case ImportAction.update:
          case ImportAction.replace:
            orphanCandidates.addAll(
              existing.bookmarkIds.difference(membershipIds),
            );
            if (action == ImportAction.replace) {
              await groupRepository.renameGroup(imported.id, imported.name);
            }
            await groupRepository.replaceMemberships(
              imported.id,
              membershipIds,
              addedAt: incomingDates,
            );
          case ImportAction.merge:
            await groupRepository.replaceMemberships(
              imported.id,
              {
                ...existing.bookmarkIds,
                ...membershipIds,
              },
              addedAt: {...incomingDates, ...preservedDates(existing)},
            );
          case ImportAction.mergeIntoTarget:
            await groupRepository.replaceMemberships(
              existingId,
              {
                ...existing.bookmarkIds,
                ...membershipIds,
              },
              addedAt: {...incomingDates, ...preservedDates(existing)},
            );
          case ImportAction.copy:
            final destinationId =
                createdPlacements[imported.id]?.itemId ??
                imported.destinationId;
            if (destinationId == null || destinationId == imported.id) {
              throw StateError('Copy identity is unresolved.');
            }
            await groupRepository.createGroup(
              imported.name,
              id: destinationId,
            );
            await groupRepository.replaceMemberships(
              destinationId,
              membershipIds,
              addedAt: incomingDates,
            );
          case ImportAction.skip:
          case ImportAction.configureItems:
            throw StateError('Import action cannot be applied to a group.');
        }
      }

      if (createdPlacements.isNotEmpty) {
        final placements = {
          for (final p in createdPlacements.values) p.itemId: p,
        };
        final groups = await groupRepository.getGroups();
        await groupRepository.replaceFolderOrganization(
          await groupRepository.getFolders(),
          [
            for (final g in groups)
              if (placements[g.id] case final p?)
                g.copyWith(folderId: p.folderId, position: p.position)
              else
                g,
          ],
        );
      }
      if (orphanCandidates.isNotEmpty) {
        final memberships = {
          for (final group in await groupRepository.getGroups())
            ...group.bookmarkIds,
        };
        final bookmarksById = {
          for (final bookmark in [...oldBookmarks, ...addedBookmarks])
            bookmark.id: bookmark,
        };
        final orphanBookmarks = orphanCandidates
            .difference(memberships)
            .map((id) => bookmarksById[id])
            .nonNulls
            .toList();
        if (orphanBookmarks.isNotEmpty) {
          await bookmarkRepository.removeBookmarks(orphanBookmarks);
        }
      }
      await _ensureDefault();
      final nextPools = <Object, CollectionBookmark>{
        for (final pool in oldPools)
          if (pool.groupIds.difference(replacedPoolGroups)
              case final memberships when memberships.isNotEmpty)
            pool.identity: pool.withGroups(memberships),
      };
      final occupiedPoolIds = nextPools.values.map((p) => p.localId).toSet();
      for (final pool in _legacyPools(plan.pools)) {
        final incomingDates = {
          for (final group in pool.groupIds)
            if (poolGroupTargets[group] case final target?)
              target: pool.addedAt[group] ?? pool.createdAt,
        };
        final memberships = incomingDates.keys.toSet();
        if (memberships.isEmpty) continue;
        final current = nextPools[pool.identity];
        final localId =
            current?.localId ??
            (occupiedPoolIds.contains(pool.localId)
                ? const Uuid().v4()
                : pool.localId);
        final saved = (current ?? pool.copyWith(localId: localId)).withGroups(
          {
            ...?current?.groupIds,
            ...memberships,
          },
          addedAt: {...incomingDates, ...?current?.addedAt},
        );
        nextPools[pool.identity] = saved;
        occupiedPoolIds.add(localId);
      }
      await groupRepository.replacePoolBookmarks(nextPools.values.toList());
    } catch (error, stackTrace) {
      final rollbackErrors = await _rollback(
        oldGroups: oldGroups,
        oldPools: oldPools,
        oldFolders: oldFolders,
        oldGroupIds: oldGroupIds,
        oldBookmarks: oldBookmarks,
      );
      if (rollbackErrors.isNotEmpty) {
        throw BookmarkImportRollbackException(
          importError: error,
          rollbackErrors: List.unmodifiable(rollbackErrors),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return BookmarkImportResult(
      totalCount: plan.bookmarks.length + plan.pools.length,
      alreadyExistedCount:
          plan.bookmarks.length -
          missingBookmarks.length +
          plan.pools
              .where((p) => oldPools.any((old) => old.identity == p.identity))
              .length,
      groupCount: plan.groups.length,
    );
  }

  Future<void> _ensureDefault() async {
    await BookmarkLibraryService(
      bookmarkRepository: bookmarkRepository,
      groupRepository: groupRepository,
      imageUrlResolver: imageUrlResolver,
    ).ensureDefaultMemberships(
      await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      ),
    );
  }

  Future<List<Object>> _rollback({
    required List<BookmarkGroup> oldGroups,
    required List<CollectionBookmark> oldPools,
    required List<CollectionFolder> oldFolders,
    required Set<String> oldGroupIds,
    required List<PostBookmark> oldBookmarks,
  }) async {
    final errors = <Object>[];
    try {
      final currentGroups = await groupRepository.getGroups();
      for (final group in currentGroups) {
        if (!group.isDefault && !oldGroupIds.contains(group.id)) {
          try {
            await groupRepository.deleteGroup(group.id);
          } catch (error) {
            errors.add(error);
          }
        }
      }
    } catch (error) {
      errors.add(error);
    }

    final currentByIdentity = <BookmarkUniqueId, PostBookmark>{};
    try {
      final oldIdentities = oldBookmarks
          .map((bookmark) => bookmark.uniqueId)
          .toSet();
      final currentBookmarks = await bookmarkRepository.getAllBookmarksOrThrow(
        imageUrlResolver: imageUrlResolver,
      );
      final extras = currentBookmarks
          .where((bookmark) => !oldIdentities.contains(bookmark.uniqueId))
          .toList();
      if (extras.isNotEmpty) await bookmarkRepository.removeBookmarks(extras);
      currentByIdentity.addEntries(
        currentBookmarks
            .where((bookmark) => oldIdentities.contains(bookmark.uniqueId))
            .map((bookmark) => MapEntry(bookmark.uniqueId, bookmark)),
      );
      final missing = oldBookmarks
          .where(
            (bookmark) => !currentByIdentity.containsKey(bookmark.uniqueId),
          )
          .toList();
      if (missing.isNotEmpty) {
        final restored = await bookmarkRepository.addBookmarkWithBookmarks(
          missing,
        );
        currentByIdentity.addEntries(
          restored.map((bookmark) => MapEntry(bookmark.uniqueId, bookmark)),
        );
      }
    } catch (error) {
      errors.add(error);
    }
    final restoredIds = {
      for (final bookmark in oldBookmarks)
        bookmark.id: currentByIdentity[bookmark.uniqueId]?.id ?? bookmark.id,
    };
    for (final group in oldGroups) {
      try {
        if (await groupRepository.getGroup(group.id) == null) {
          await groupRepository.createGroup(group.name, id: group.id);
        } else if (!group.isDefault) {
          await groupRepository.renameGroup(group.id, group.name);
        }
        await groupRepository.replaceMemberships(
          group.id,
          {
            for (final id in group.bookmarkIds) restoredIds[id] ?? id,
          },
          addedAt: {
            for (final entry in group.addedAt.entries)
              restoredIds[entry.key] ?? entry.key: entry.value,
          },
        );
      } catch (error) {
        errors.add(error);
      }
    }
    try {
      await groupRepository.replaceFolderOrganization(oldFolders, [
        for (final g in oldGroups)
          g.copyWith(
            bookmarkIds: {
              for (final id in g.bookmarkIds) restoredIds[id] ?? id,
            },
            addedAt: {
              for (final entry in g.addedAt.entries)
                restoredIds[entry.key] ?? entry.key: entry.value,
            },
          ),
      ]);
    } catch (e) {
      errors.add(e);
    }
    try {
      await groupRepository.replacePoolBookmarks(oldPools);
    } catch (error) {
      errors.add(error);
    }
    return errors;
  }
}

// Validate every typed reference before any Post, group or folder write. The
// decoder also enforces this at the untrusted backup boundary.
void _validateReferences(
  List<CollectionBookmark> references,
  Set<String> groups,
) {
  final identities = <Object>{};
  final localIds = <String>{};
  for (final reference in references) {
    if (!Uuid.isValidUUID(fromString: reference.localId) ||
        !identities.add(reference.identity) ||
        !localIds.add(reference.localId) ||
        reference.groupIds.isEmpty ||
        !groups.containsAll(reference.groupIds)) {
      throw const FormatException('Invalid collection bookmark references');
    }
  }
}
