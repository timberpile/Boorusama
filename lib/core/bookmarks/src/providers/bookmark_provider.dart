import '../../../posts/cross_profile_lookup/src/data/post_lookup_visibility.dart';

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../../foundation/data_mutation_coordinator.dart';
import '../../../../foundation/loggers.dart';
import '../../../boorus/booru/types.dart';
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../../../blacklists/providers.dart';
import '../../../content/content_access.dart';
import '../../../content/content_access_provider.dart';
import '../../../posts/details/src/types/viewer_entry.dart';
import '../../../downloads/downloader/providers.dart';
import '../../../downloads/filename/types.dart';
import '../../../downloads/urls/providers.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import '../../../router.dart';
import '../../../settings/providers.dart';
import '../data/bookmark_convert.dart';
import '../data/bookmark_collection_projection.dart';
import '../types/legacy_group_bookmark.dart';
import '../types/content_group_bookmark.dart';
import '../../../posts/related/related_posts_order_value.dart';
import '../data/providers.dart';
import '../services/bookmark_library_service.dart';
import '../services/bookmark_hydration_service.dart';
import '../services/bookmark_mutation_repository.dart';
import '../types/bookmark.dart';
import '../types/bookmark_record_fields.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_repository.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_repository.dart';
import '../../../groups/folder_tree.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_repository.dart';
import '../types/unified_bookmark_store.dart';
import '../types/bookmark_target.dart';
import '../types/bookmark_view.dart';
import 'bookmark_group_view_preferences.dart';

final bookmarkLibraryProvider =
    AsyncNotifierProvider<BookmarkLibraryNotifier, BookmarkLibraryState>(
      BookmarkLibraryNotifier.new,
      dependencies: [
        settingsProvider,
        booruConfigProvider,
        sourceDownloadNotifierParamsProvider,
        blacklistTagsProvider,
        contentProfileAccessProvider,
        contentPostVisibilityProvider,
        bookmarkRepoProvider,
        bookmarkGroupRepoProvider,
        dataMutationCoordinatorProvider,
        bookmarkGroupViewPreferencesProvider,
      ],
    );

final bookmarkProvider = bookmarkLibraryProvider;

typedef BookmarkNotifier = BookmarkLibraryNotifier;

class BookmarkGroupCreationRollbackException implements Exception {
  const BookmarkGroupCreationRollbackException({
    required this.creationError,
    required this.rollbackErrors,
  });

  final Object creationError;
  final List<Object> rollbackErrors;
}

class BookmarkGroupDeletionRollbackException implements Exception {
  const BookmarkGroupDeletionRollbackException({
    required this.deletionError,
    required this.rollbackErrors,
  });

  final Object deletionError;
  final List<Object> rollbackErrors;
}

class BookmarkGroupChangedException implements Exception {
  const BookmarkGroupChangedException(this.preview);

  final BookmarkGroupDeletionPreview preview;
}

class BookmarkPostBatchRollbackException implements Exception {
  const BookmarkPostBatchRollbackException({
    required this.operationError,
    required this.rollbackErrors,
    required this.createdBookmarks,
  });

  final Object operationError;
  final List<Object> rollbackErrors;
  final List<PostBookmark> createdBookmarks;
}

enum BookmarkToggleOutcome {
  added,
  removed,
  unavailable,
  missingPostIdentity,
  failed,
}

final bookmarkUrlResolverProvider = Provider.autoDispose
    .family<ImageUrlResolver, int?>((ref, booruId) {
      final booruType = intToBooruType(booruId);
      final registry = ref.watch(booruEngineRegistryProvider);
      return registry.getRepository(booruType)?.imageUrlResolver() ??
          const DefaultImageUrlResolver();
    });

class BookmarkLibraryNotifier extends AsyncNotifier<BookmarkLibraryState> {
  Future<void> _mutationTail = Future.value();
  var _requiresRefresh = false;
  final _removals = <BookmarkUniqueId, BookmarkGroupRemovalResult>{};
  final _poolRemovals = <Object, BookmarkGroupRemovalResult>{};
  final _recordRemovals = <int, BookmarkGroupRemovalResult>{};
  BookmarkHierarchyDeletion? _hierarchyDeletion;
  Map<String, BookmarkGroupViewMode> _hierarchyDeletedModes = const {};
  BookmarkHierarchyDeletion? get lastHierarchyDeletion => _hierarchyDeletion;
  final _mutationSessionKey = Object();
  final _storageSessionKey = Object();
  final _pendingHydration = <int, PostBookmark>{};
  int? _pendingHydrationRevision;
  Timer? _hydrationPublicationTimer;

  // Zone-local rather than a notifier field: unrelated async readers must never
  // borrow an in-flight operation's write-through view.
  BookmarkMutationRepository? get _mutation =>
      Zone.current[_mutationSessionKey] as BookmarkMutationRepository?;

  _BookmarkStorageSession? get _storageSession {
    final session =
        Zone.current[_storageSessionKey] as _BookmarkStorageSession?;
    return session?.active == true ? session : null;
  }

  Future<BookmarkLibraryState> get _librarySnapshot =>
      switch (_storageSession) {
        final session? => Future.value(session.snapshot),
        null => future,
      };

  Future<BookmarkGroupRepository> get bookmarkGroupRepository =>
      switch (_storageSession) {
        final session? => Future.value(session.groups),
        null => ref.read(bookmarkGroupRepoProvider.future),
      };

  void _publishLibrary(BookmarkLibraryState next) {
    final session = _storageSession;
    if (session != null) session.snapshot = next;
    // A replacement build owns its eventual publication. The admitted write
    // remains coherent in its pinned view until that build reads after release.
    if (session == null || !state.isLoading) state = AsyncValue.data(next);
  }

  void _discardRestoredRemovalUndo(BookmarkLibraryState next) {
    if (!next.hasUnifiedRecords || _recordRemovals.isEmpty) return;
    // Only the most recent removal batch is offered as Undo. A later save
    // can have a fresh local ID, so check its compatible semantic identity.
    final removal = _recordRemovals.values.first;
    final group = next.groupsById[removal.groupId];
    if (group == null) return;
    for (final frozen in removal.removedRecords) {
      final identity = bookmarkContentIdentity(frozen);
      final current =
          next.byId[frozen.id] ??
          (identity == null ? null : next.byId[next.idByContent[identity]]);
      if (current != null &&
          bookmarkContentIdentity(current) == identity &&
          bookmarkEngine(current) == bookmarkEngine(frozen) &&
          group.bookmarkIds.contains(current.id)) {
        _removals.clear();
        _poolRemovals.clear();
        _recordRemovals.clear();
        return;
      }
    }
  }

  void _recordRemoval(BookmarkGroupRemovalResult result) {
    if (result.removedCount == 0) return;
    _hierarchyDeletion = null;
    _hierarchyDeletedModes = const {};
    _removals.clear();
    _poolRemovals.clear();
    _recordRemovals.clear();
    for (final pool in result.removedPools) {
      _poolRemovals[pool.identity] = result;
    }
    for (final bookmark in result.removedBookmarks) {
      _removals[bookmark.uniqueId] = result;
    }
    for (final record in result.removedRecords) {
      _recordRemovals[record.id] = result;
    }
  }

  void showRemovalUndo(
    BuildContext context,
    BookmarkGroupRemovalResult result,
  ) {
    if (result.removedCount == 0) return;
    // Root-navigator callbacks outlive their menu but sit above the shell's
    // live inset scope. Resolve the stable shell anchor when showing feedback.
    final feedbackContext =
        ref.read(appNavigationProvider).feedbackKey.currentContext ?? context;
    if (!feedbackContext.mounted) return;
    final strings = feedbackContext.t.bookmark;
    Kurumi.showSuccessToast(
      feedbackContext,
      result.removedCount == 1
          ? strings.removed
          : strings.removal_result.replaceAll(
              '{removed}',
              '${result.removedCount}',
            ),
      duration: const Duration(seconds: 5),
      actionLabel: strings.undo,
      onAction: () async {
        try {
          await undoRemoval(result);
        } catch (_) {
          if (feedbackContext.mounted) {
            Kurumi.showErrorToast(feedbackContext, strings.undo_failed);
          }
        }
      },
    );
  }

  Future<void> undoRemoval(BookmarkGroupRemovalResult result) =>
      _runTrackedMutation(() async {
        if (result.removedRecords.isNotEmpty) {
          if (result.removedRecords.any(
            (record) => !identical(_recordRemovals[record.id], result),
          )) {
            throw StateError('A later removal superseded this Undo.');
          }
          await (await _service).undoRemoval(result);
          for (final record in result.removedRecords) {
            _recordRemovals.remove(record.id);
          }
          return;
        }
        final eligible = result.removedBookmarks
            .where((b) => identical(_removals[b.uniqueId], result))
            .toList();
        final eligiblePools = result.removedPools
            .where((p) => identical(_poolRemovals[p.identity], result))
            .toList();
        if (eligible.length + eligiblePools.length != result.removedCount) {
          throw StateError('A later removal superseded this Undo.');
        }
        await (await _service).undoRemoval(result);
        for (final b in eligible) {
          _removals.remove(b.uniqueId);
        }
        for (final pool in eligiblePools) {
          _poolRemovals.remove(pool.identity);
        }
      });

  Future<BookmarkRepository> get bookmarkRepository =>
      switch (_storageSession) {
        final session? => Future.value(session.repository),
        null => ref.read(bookmarkRepoProvider.future),
      };

  Future<BookmarkLibraryService> get _service async {
    final mutation = _mutation;
    return _serviceFor(
      mutation ?? await bookmarkRepository,
      await bookmarkGroupRepository,
      mutation: mutation,
    );
  }

  BookmarkLibraryService _serviceFor(
    BookmarkRepository repository,
    BookmarkGroupRepository groups, {
    BookmarkMutationRepository? mutation,
  }) => BookmarkLibraryService(
    bookmarkRepository: repository,
    groupRepository: groups,
    imageUrlResolver: (booruId) =>
        ref.read(bookmarkUrlResolverProvider(booruId)),
    readMutationSnapshot: mutation == null
        ? null
        : () => _readMutationState(mutation),
  );

  @override
  FutureOr<BookmarkLibraryState> build() =>
      DataMutationCoordinator.withoutOwnership(
        () => runZoned(
          _buildLibrary,
          zoneValues: {_storageSessionKey: null, _mutationSessionKey: null},
        ),
      );

  Future<BookmarkLibraryState> _buildLibrary() async {
    // Keep cold initialization subscribed to repository replacement. Reading a
    // cancelled Future alone can leave the library waiting forever when engine
    // registration or storage dependencies invalidate it during startup.
    final repositoryReady = ref.watch(bookmarkRepoProvider.future);
    final groupsReady = ref.watch(bookmarkGroupRepoProvider.future);
    final storage = await Future.wait<Object>([repositoryReady, groupsReady]);
    _pendingHydration.clear();
    _pendingHydrationRevision = null;
    _hydrationPublicationTimer?.cancel();
    _hydrationPublicationTimer = null;
    ref.onDispose(() => _hydrationPublicationTimer?.cancel());
    final next = await _serviceFor(
      storage[0] as BookmarkRepository,
      storage[1] as BookmarkGroupRepository,
    ).load();
    await _pruneGroupModes(next);
    return next;
  }

  Future<void> _pruneGroupModes(BookmarkLibraryState next) async {
    try {
      await ref
          .read(bookmarkGroupViewPreferencesProvider.notifier)
          .retainGroups(next.groupsById.keys.toSet());
    } catch (error) {
      // UI preferences cannot turn a confirmed domain write into a reported
      // deletion failure. A later successful load retries stale-key cleanup.
      try {
        ref
            .read(loggerProvider)
            .warn(
              'Bookmarks',
              'Could not prune local Group view preferences (${error.runtimeType}).',
            );
      } catch (_) {
        // Reduced hosts and shutdown can have no logger or local UI store.
      }
    }
  }

  void _recordHierarchyDeletion(BookmarkHierarchyDeletion deletion) {
    var modes = const <String, BookmarkGroupViewMode>{};
    try {
      modes = ref.read(bookmarkGroupViewPreferencesProvider);
    } catch (_) {}
    _hierarchyDeletedModes = Map.unmodifiable({
      for (final group in deletion.deletedGroups)
        if (modes[group.id] case final mode?) group.id: mode,
    });
    _hierarchyDeletion = deletion;
    _removals.clear();
    _poolRemovals.clear();
    _recordRemovals.clear();
  }

  Future<void> undoHierarchyDeletion(
    BookmarkHierarchyDeletion deletion,
  ) => _serialize(() async {
    if (!identical(_hierarchyDeletion, deletion))
      throw StateError('A later action superseded this Undo');
    await (await _service).undoHierarchyDeletion(deletion);
    try {
      await ref
          .read(bookmarkGroupViewPreferencesProvider.notifier)
          .restoreMissing(_hierarchyDeletedModes);
    } catch (error) {
      try {
        ref
            .read(loggerProvider)
            .warn(
              'Bookmarks',
              'Could not restore local Group view preferences (${error.runtimeType}).',
            );
      } catch (_) {}
    }
    _hierarchyDeletion = null;
    _hierarchyDeletedModes = const {};
    await _publishCommittedMutation();
  });

  void showHierarchyUndo(
    BuildContext context,
    BookmarkHierarchyDeletion deletion,
  ) {
    final feedback =
        ref.read(appNavigationProvider).feedbackKey.currentContext ?? context;
    if (!feedback.mounted) return;
    final strings = feedback.t.bookmark;
    Kurumi.showSuccessToast(
      feedback,
      strings.groups.deleted(n: deletion.deletedGroups.length),
      duration: const Duration(seconds: 5),
      actionLabel: strings.undo,
      onAction: () async {
        try {
          await undoHierarchyDeletion(deletion);
        } catch (_) {
          if (feedback.mounted)
            Kurumi.showErrorToast(feedback, strings.undo_failed);
        }
      },
    );
  }

  /// External callbacks (imports/restores) may write directly to repositories.
  /// They intentionally keep the authoritative reload path.
  Future<T> runSerializedMutation<T>(
    Future<T> Function() operation, {
    bool reload = true,
  }) => _runMutation(operation, reload: reload, tracked: false);

  Future<T> _runTrackedMutation<T>(Future<T> Function() operation) =>
      _runMutation(operation, tracked: true);

  Future<T> _runMutation<T>(
    Future<T> Function() operation, {
    bool reload = true,
    required bool tracked,
  }) => _serialize(() async {
    if (!tracked) _mutation?.invalidate();
    Object? operationError;
    StackTrace? operationStackTrace;
    T? result;
    try {
      result = await operation();
      _removals.clear();
      _poolRemovals.clear();
      _recordRemovals.clear();
    } catch (error, stackTrace) {
      _mutation?.invalidate();
      operationError = error;
      operationStackTrace = stackTrace;
    }
    if (operationError != null) {
      if (reload) {
        await _publishCommittedMutation();
      }
      Error.throwWithStackTrace(operationError, operationStackTrace!);
    }
    if (reload) {
      await _publishCommittedMutation();
    } else if (!tracked) {
      _requiresRefresh = true;
    }
    return result as T;
  });

  Future<int> _addPoolsToGroup(
    List<CollectionBookmark> drafts,
    String groupId, {
    RelatedPostsOrder? initialRelatedOrder,
  }) async {
    if (drafts.isEmpty) return 0;
    final service = await _service;
    if (service.unifiedStore != null) {
      final current = await _librarySnapshot;
      final records = <Bookmark>[];
      final savedRecords = <Bookmark>[];
      for (final draft in drafts) {
        final identity = LegacyGroupBookmark.fromMetadata(
          id: 0,
          metadata: draft,
        ).identity;
        final id =
            draft.bookmarkId ??
            (identity == null ? null : current.idByContent[identity]);
        final previous = id == null ? null : current.byId[id];
        if (draft.bookmarkId != null && previous == null)
          throw StateError('Saved Group changed before the action completed');
        final candidate = collectionRecordForSave(
          draft,
          id: 0,
          previous: previous,
          initialRelatedOrder: draft.isRelated
              ? initialRelatedOrder ??
                    ref.read(settingsProvider).relatedPostsOrder
              : null,
        );
        if (previous != null) {
          service.unifiedStore!.normalizeRecord(candidate, previous: previous);
          savedRecords.add(previous);
        } else {
          records.add(candidate);
        }
      }
      return (await service.saveDraftsToGroup(
        records,
        groupId,
        savedRecords: savedRecords,
      )).addedCount;
    }
    final repository = await bookmarkGroupRepository;
    if (await repository.getGroup(groupId) == null)
      throw StateError('Bookmark group unavailable');
    final next = {
      for (final pool in await repository.getPoolBookmarks())
        pool.identity: pool,
    };
    var added = 0;
    for (final draft in drafts) {
      final current = next[draft.identity];
      if (current?.groupIds.contains(groupId) ?? false) continue;
      // Prepared metadata is not a saved membership, including its provisional
      // Default group. Assign the first membership date only on this write.
      next[draft.identity] = (current ?? draft.copyWith(groupIds: const {}))
          .withGroups({
            ...?current?.groupIds,
            groupId,
          });
      _poolRemovals.remove(draft.identity);
      added++;
    }
    await repository.replacePoolBookmarks(next.values.toList());
    return added;
  }

  Future<BookmarkToggleOutcome> toggleSavedBookmarkTarget(
    Bookmark record, {
    required String groupId,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) => _serialize(() async {
    try {
      final current = await _librarySnapshot;
      if (!current.hasUnifiedRecords || !current.byId.containsKey(record.id))
        return BookmarkToggleOutcome.failed;
      final service = await _service;
      if (current.membershipsForId(record.id).contains(groupId)) {
        final result = await service.removeBookmarksFromGroup([
          record,
        ], groupId);
        if (result.removedCount > 0) await _rememberManualGroup(groupId);
        await _publishCommittedMutation();
        _recordRemoval(result);
        onRemoved?.call(result);
        return BookmarkToggleOutcome.removed;
      }
      await service.addBookmarksToGroup([record], groupId);
      await _rememberManualGroup(groupId);
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.added;
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.failed;
    }
  });

  Future<({BookmarkGroup group, int addedCount})> createGroupWithSavedRecords(
    String name,
    Iterable<Bookmark> records, {
    String? folderId,
    String? parentGroupId,
  }) => _runTrackedMutation(() async {
    final result = await (await _service).createGroupWithSavedRecords(
      name,
      records,
      folderId: folderId,
      parentGroupId: parentGroupId,
    );
    if (result.addedCount > 0) await _rememberManualGroup(result.group.id);
    return result;
  });

  Future<BookmarkToggleOutcome> toggleContentGroupTarget(
    ContentGroupBookmark draft, {
    required String groupId,
    void Function()? beforeCommit,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) => withBookmarkCommitGuard(
    () => _serialize(() async {
      beforeCommit?.call();
      final current = await _librarySnapshot;
      final service = await _service;
      beforeCommit?.call();
      final id = current.idByContent[draft.reference.identity];
      final saved = id == null ? null : current.byId[id];
      if (saved != null &&
          current.membershipsForId(saved.id).contains(groupId)) {
        final removal = await service.removeBookmarksFromGroup([
          saved,
        ], groupId);
        _recordRemoval(removal);
        await _rememberManualGroup(groupId);
        await _publishCommittedMutation();
        onRemoved?.call(removal);
        return BookmarkToggleOutcome.removed;
      }
      await service.saveDraftsToGroup(
        saved == null ? [draft] : const [],
        groupId,
        savedRecords: saved == null ? const [] : [saved],
      );
      await _rememberManualGroup(groupId);
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.added;
    }),
    beforeCommit,
  );

  Future<void> createGroupWithContentDraft(
    String name,
    ContentGroupBookmark draft, {
    String? parentGroupId,
    void Function()? beforeCommit,
  }) => withBookmarkCommitGuard(
    () => _runTrackedMutation(() async {
      beforeCommit?.call();
      final service = await _service;
      beforeCommit?.call();
      final result = await service.createGroupWithSavedRecords(
        name,
        const [],
        drafts: [draft],
        parentGroupId: parentGroupId,
      );
      await _rememberManualGroup(result.group.id);
    }),
    beforeCommit,
  );

  Future<int> addSavedRecordsToGroup(
    Iterable<Bookmark> records,
    String groupId,
  ) => _runTrackedMutation(() async {
    final added = await (await _service).addBookmarksToGroup(records, groupId);
    if (added > 0) await _rememberManualGroup(groupId);
    return added;
  });

  Future<BookmarkGroupRemovalResult> removeSavedRecordsFromGroup(
    Iterable<Bookmark> records,
    String groupId,
  ) => _serialize(() async {
    final removal = await (await _service).removeBookmarksFromGroup(
      records,
      groupId,
    );
    if (removal.removedCount > 0) await _rememberManualGroup(groupId);
    _recordRemoval(removal);
    await _publishCommittedMutation();
    return removal;
  });

  Future<BookmarkToggleOutcome> togglePoolTarget(
    CollectionBookmark draft, {
    required String groupId,
    RelatedPostsOrder? initialRelatedOrder,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) => _serialize(() async {
    try {
      final repository = await bookmarkGroupRepository;
      if (await repository.getGroup(groupId) == null)
        return BookmarkToggleOutcome.failed;
      final current = (await repository.getPoolBookmarks())
          .where((p) => p.identity == draft.identity)
          .firstOrNull;
      if ((await _librarySnapshot).hasUnifiedRecords &&
          draft.bookmarkId != null &&
          current?.bookmarkId != draft.bookmarkId)
        return BookmarkToggleOutcome.failed;
      if (current?.groupIds.contains(groupId) ?? false) {
        final result = await (await _service).removeBookmarksFromGroup(
          [],
          groupId,
          poolLocalIds: {current!.localId},
        );
        if (result.removedCount > 0) await _rememberManualGroup(groupId);
        await _publishCommittedMutation();
        _recordRemoval(result);
        onRemoved?.call(result);
        return BookmarkToggleOutcome.removed;
      }
      await _addPoolsToGroup(
        [draft],
        groupId,
        initialRelatedOrder: initialRelatedOrder,
      );
      await _rememberManualGroup(groupId);
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.added;
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.failed;
    }
  });

  Future<void> setRelatedOrder(int bookmarkId, RelatedPostsOrder order) =>
      _runTrackedMutation(
        () async => (await _service).setRelatedOrder(bookmarkId, order),
      );

  Future<void> refreshPoolBookmark(CollectionBookmark summary) =>
      runSerializedMutation(() async {
        final repository = await bookmarkGroupRepository;
        final pools = await repository.getPoolBookmarks();
        final existing = pools
            .where(
              (p) =>
                  p.identity == summary.identity &&
                  p.localId == summary.localId,
            )
            .firstOrNull;
        if (existing == null)
          throw StateError('Pool bookmark changed during refresh');
        await repository.replacePoolBookmarks([
          for (final pool in pools)
            if (pool.identity == summary.identity)
              summary.withGroups(pool.groupIds, addedAt: pool.addedAt)
            else
              pool,
        ]);
      });

  /// Admit before taking the shared coordinator when a caller needs several
  /// coherent library operations. Nested notifier calls reuse the same pin.
  Future<T> runWithLibrary<T>(Future<T> Function() operation) =>
      _serialize(operation);

  Future<BookmarkLibraryState> snapshotForExport() =>
      _serialize(() => _librarySnapshot);

  Future<void> refresh() => _serialize(_reload);

  Future<T> _serialize<T>(
    Future<T> Function() operation, {
    bool publishHydration = true,
  }) async {
    if (_storageSession != null) {
      return operation();
    }
    final coordinator = ref.read(dataMutationCoordinatorProvider);
    // Provider initialization reads the durable repository in its own zone.
    // Finish it before taking the same coordinator for a mutation, otherwise
    // a cold first action can wait on a read queued behind its own lock.
    while (true) {
      if (state.isLoading) {
        if (coordinator.isCurrentOwner) {
          throw StateError(
            'Admit the Bookmark library before taking the data coordinator',
          );
        }
        await future;
      }
      try {
        return await coordinator.runExclusive(
          () {
            // A dependency can be replaced after this operation queues. Yield
            // the coordinator before awaiting its replacement initialization.
            // Reads may themselves flush invalidated dependencies. Capture all
            // ready storage first, then validate the library they belong to.
            final repository = ref.read(bookmarkRepoProvider);
            final groups = ref.read(bookmarkGroupRepoProvider);
            if (state.isLoading || repository.isLoading || groups.isLoading) {
              throw const _LibraryInitializationPending();
            }
            final session = _BookmarkStorageSession(
              repository: repository.requireValue,
              groups: groups.requireValue,
              snapshot: state.requireValue,
            );
            return runZoned(
              () async {
                try {
                  return await _serializeLocally(
                    operation,
                    publishHydration: publishHydration,
                  );
                } finally {
                  session.active = false;
                }
              },
              zoneValues: {
                _storageSessionKey: session,
                _mutationSessionKey: null,
              },
            );
          },
        );
      } on _LibraryInitializationPending {
        if (coordinator.isCurrentOwner) {
          throw StateError(
            'Admit the Bookmark library before taking the data coordinator',
          );
        }
        await future;
      }
    }
  }

  Future<T> _serializeLocally<T>(
    Future<T> Function() operation, {
    required bool publishHydration,
  }) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.catchError((_) {}).then((_) async {
      BookmarkMutationRepository? mutation;
      try {
        if (_requiresRefresh) await _reload();
        final repository = await bookmarkRepository;
        final store = unifiedBookmarkStorage(repository);
        if ((await _librarySnapshot).hasUnifiedRecords && store != null) {
          final durableRevision = await store.readRevision();
          final expectedRevision =
              _pendingHydrationRevision ?? (await _librarySnapshot).revision;
          if (durableRevision != expectedRevision) await _reload();
        }
        if (publishHydration) _publishHydration();
        mutation = BookmarkMutationRepository(
          delegate: repository,
          base: await _librarySnapshot,
        );
        completer.complete(
          await observeBookmarkWrites(
            () => runZoned(
              operation,
              zoneValues: {_mutationSessionKey: mutation},
            ),
            mutation.recordCommittedChange,
          ),
        );
      } catch (error, stackTrace) {
        mutation?.invalidate();
        // A deferred callback can inherit an older operation's zone. Recovery
        // must use storage rather than either the current or inherited delta.
        _mutation?.invalidate();
        await _publishCommittedMutation();
        completer.completeError(error, stackTrace);
      } finally {
        // Async callbacks can outlive the operation that registered them.
        mutation?.invalidate();
      }
    });
    return completer.future;
  }

  Future<void> _reload() async {
    _mutation?.invalidate();
    try {
      final next = await (await _service).load();
      await _pruneGroupModes(next);
      _discardRestoredRemovalUndo(next);
      _publishLibrary(next);
      _pendingHydration.clear();
      _pendingHydrationRevision = null;
      _hydrationPublicationTimer?.cancel();
      _hydrationPublicationTimer = null;
      _requiresRefresh = false;
    } catch (error, stackTrace) {
      if (_storageSession == null || !state.isLoading) {
        state = AsyncValue.error(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<BookmarkLibraryState> _readMutationState(
    BookmarkMutationRepository mutation,
  ) async {
    if (!mutation.isValid) return (await _service).load();
    final repository = await bookmarkGroupRepository;
    final groups = await repository.getGroups();
    final folders = await repository.getFolders();
    FolderTree(folders).validatePlacements([
      for (final group in groups)
        FolderPlacement(
          itemId: group.id,
          folderId: group.folderId,
          position: group.position,
        ),
    ]);
    return mutation.base.applyCommittedChanges(
      pools: mutation.base.hasUnifiedRecords
          ? null
          : await repository.getPoolBookmarks(),
      upserts: mutation.upserts,
      removedIds: mutation.removedIds,
      revision: mutation.base.hasUnifiedRecords ? mutation.revision : null,
      groups: groups,
      folders: folders,
    );
  }

  Future<void> _publishCommittedMutation() async {
    final previousState = state;
    final mutation = _mutation;
    if (mutation != null && mutation.isValid) {
      try {
        final next = await _readMutationState(mutation);
        await _pruneGroupModes(next);
        _discardRestoredRemovalUndo(next);
        if (!identical(state.valueOrNull, next)) _publishLibrary(next);
        _requiresRefresh = false;
        return;
      } catch (_) {
        mutation.invalidate();
      }
    }
    try {
      await _reload();
    } catch (_) {
      if (_storageSession == null || !state.isLoading) state = previousState;
      _requiresRefresh = true;
    }
  }

  Future<void> addBookmarks(
    BooruConfigAuth config,
    Iterable<Post> posts, {
    void Function(int count)? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      final booruId = config.booruIdHint;
      final currentState = await _librarySnapshot;
      final filtered = posts
          .where((post) => !currentState.isBookmarked(post, booruId))
          .toList();

      final result = await _addPostsToGroup(config, filtered, null);
      await _publishCommittedMutation();
      onSuccess?.call(result.changedCount);
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<void> addBookmark(
    BooruConfigAuth config,
    Post post, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      BookmarkIdentity.fromPost(post);
      final booruId = config.booruIdHint;
      final currentState = await _librarySnapshot;
      final existing = currentState.bookmarkForPost(
        post,
        fallbackBooruId: booruId,
      );
      const groupId = defaultBookmarkGroupId;
      await (await _service).addBookmarkToGroup(
        groupId: groupId,
        existingBookmark: existing,
        createBookmarkIdentity: BookmarkUniqueId.fromPost(post, booruId),
        createBookmark: existing == null
            ? () => _createBookmark(config, post)
            : null,
        prepareBookmark: existing == null
            ? () => _prepareBookmark(config, post)
            : null,
      );

      await _publishCommittedMutation();
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<BookmarkHydrationProgress> hydrateBookmarks({
    required Iterable<BooruConfig> configs,
    required BookmarkRecoveryService recovery,
    required BookmarkHydrationCancellation cancellation,
    required void Function(BookmarkHydrationProgress) onProgress,
  }) async {
    final publicationZone = Zone.current;
    final library = await snapshotForExport();
    // Network requests and backoff must not hold the global write lock. Each
    // successful response gets its own short, revalidated serialized commit.
    try {
      return await BookmarkHydrationService(
        library: await _service,
        recovery: recovery,
        commitRecovered: (bookmark, post, codec) => _serialize(() async {
          if (cancellation.cancelled) return false;
          final currentState = await _librarySnapshot;
          final current = currentState.bookmarksById[bookmark.id];
          // A deletion, replacement, recovery reload or newer snapshot supersedes
          // this request. Do not resurrect a row or overwrite newer data.
          if (current is! PostBookmark ||
              current.uniqueId != bookmark.uniqueId ||
              current.post.origin.booruType != bookmark.post.origin.booruType ||
              !identical(current, bookmark) ||
              _pendingHydration.containsKey(bookmark.id)) {
            return false;
          }
          final upgraded = await (await _service).upgradeBookmarkSnapshot(
            bookmark: bookmark,
            post: post,
            dataCodec: codec,
          );
          _pendingHydration[upgraded.id] = upgraded;
          _pendingHydrationRevision = _mutation?.revision;
          if (_pendingHydration.length >= 32) {
            _publishHydration();
          } else {
            // Register outside the commit's reentrant coordinator zone. A
            // deferred timer must acquire the global lock as a fresh caller.
            _hydrationPublicationTimer ??= publicationZone.run(
              () => Timer(
                const Duration(milliseconds: 16),
                () {
                  _hydrationPublicationTimer = null;
                  unawaited(_serialize(() async {}).catchError((Object _) {}));
                },
              ),
            );
          }
          return true;
        }, publishHydration: false),
      ).run(
        bookmarks: library.items,
        configs: configs,
        cancellation: cancellation,
        onProgress: onProgress,
      );
    } finally {
      await _serialize(() async {});
    }
  }

  // Persist each response promptly, but shallow-copy the library at most once
  // per frame or 32 responses. Every other serialized operation flushes first,
  // so interactive edits and export snapshots always see the committed rows.
  void _publishHydration() {
    if (_pendingHydration.isEmpty) return;
    final current = _storageSession?.snapshot ?? state.requireValue;
    final next = current.applyCommittedChanges(
      upserts: _pendingHydration.values,
      revision: current.hasUnifiedRecords ? _pendingHydrationRevision : null,
      groups: current.groups,
      folders: current.folders,
    );
    _pendingHydration.clear();
    _pendingHydrationRevision = null;
    _hydrationPublicationTimer?.cancel();
    _hydrationPublicationTimer = null;
    _publishLibrary(next);
  }

  Future<void> upgradeBookmarkSnapshot(
    PostBookmark bookmark,
    Post post, {
    bool Function()? canUpgrade,
  }) => _serialize(() async {
    if (canUpgrade?.call() == false) return;
    final snapshot = await _librarySnapshot;
    if (canUpgrade?.call() == false) return;
    final current = snapshot.bookmarksById[bookmark.id];
    if (current is! PostBookmark ||
        current.uniqueId != bookmark.uniqueId ||
        current.post.origin.booruType != bookmark.post.origin.booruType) {
      return;
    }
    final capability = ref
        .read(booruEngineRegistryProvider)
        .getPostCapability(post.origin.booruType);
    final codec = capability?.codecFor(post.origin, post.booruData);
    if (codec == null) {
      throw StateError('No compatible post codec is available.');
    }
    final service = await _service;
    if (canUpgrade?.call() == false) return;
    await service.upgradeBookmarkSnapshot(
      bookmark: current,
      post: post,
      dataCodec: codec,
    );
    await _publishCommittedMutation();
  });

  Future<void> _rememberManualGroup(String groupId) async {
    try {
      await (await bookmarkGroupRepository).rememberManualGroup(groupId);
    } catch (error) {
      // Membership is already committed. Never report it as failed because a
      // nonessential local shortcut preference could not be persisted.
      try {
        ref
            .read(loggerProvider)
            .warn(
              'Bookmarks',
              'Could not persist recent group selection (${error.runtimeType}).',
            );
      } catch (_) {
        // Logging can be unavailable during shutdown or in reduced hosts.
      }
    }
  }

  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget target = const BookmarkTarget.defaultGroup(),
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) => _serialize(() async {
    try {
      if (BookmarkUniqueId.fromPost(post) is UnbookmarkablePostIdentity) {
        return BookmarkToggleOutcome.missingPostIdentity;
      }
      final current = await _librarySnapshot;
      final selectedTarget = target;
      final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
      final bookmark = current.bookmarkForPost(
        post,
        fallbackBooruId: config.booruIdHint,
      );
      final memberships = current.membershipsFor(uniqueId);
      final bookmarked =
          bookmark != null && memberships.contains(selectedTarget.groupId);
      return await _setPostTargetMembership(
        config,
        post,
        current,
        selectedTarget,
        bookmarked: !bookmarked,
        onRemoved: onRemoved,
      );
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.failed;
    }
  });

  Future<BookmarkToggleOutcome> setPostTargetMembership(
    BooruConfigAuth config,
    Post post, {
    required BookmarkTarget target,
    required bool bookmarked,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) => _serialize(() async {
    try {
      return await _setPostTargetMembership(
        config,
        post,
        await _librarySnapshot,
        target,
        bookmarked: bookmarked,
        onRemoved: onRemoved,
      );
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.failed;
    }
  });

  Future<BookmarkToggleOutcome> _setPostTargetMembership(
    BooruConfigAuth config,
    Post post,
    BookmarkLibraryState current,
    BookmarkTarget target, {
    required bool bookmarked,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) async {
    final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
    if (uniqueId is UnbookmarkablePostIdentity) {
      return BookmarkToggleOutcome.missingPostIdentity;
    }
    final bookmark = current.bookmarkForPost(
      post,
      fallbackBooruId: config.booruIdHint,
    );
    final memberships = current.membershipsFor(uniqueId);
    final groupId = target.groupId;
    final isMember = bookmark != null && memberships.contains(groupId);
    if (isMember == bookmarked) {
      return bookmarked
          ? BookmarkToggleOutcome.added
          : BookmarkToggleOutcome.removed;
    }
    if (bookmarked) {
      await (await _service).addBookmarkToGroup(
        groupId: groupId,
        existingBookmark: bookmark,
        createBookmarkIdentity: uniqueId,
        createBookmark: bookmark == null
            ? () => _createBookmark(config, post)
            : null,
        prepareBookmark: bookmark == null
            ? () => _prepareBookmark(config, post)
            : null,
      );
      await _rememberManualGroup(groupId);
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.added;
    }
    final removal = await (await _service).removeBookmarksFromGroup(
      [bookmark!],
      groupId,
    );
    if (removal.removedCount > 0) await _rememberManualGroup(groupId);
    await _publishCommittedMutation();
    _recordRemoval(removal);
    onRemoved?.call(removal);
    return BookmarkToggleOutcome.removed;
  }

  Future<BookmarkGroup> createGroup(
    String name, {
    String? folderId,
    String? parentGroupId,
  }) => _serialize(() async {
    if (folderId != null && parentGroupId != null) {
      throw ArgumentError('Choose one parent Group');
    }
    final service = await _service;
    final repository = await bookmarkGroupRepository;
    final aliases = await repository.getLegacyFolderGroupIds();
    final parent = parentGroupId ?? aliases[folderId] ?? folderId;
    var group = await service.createGroup(
      name,
      parentGroupId: service.unifiedStore == null ? parentGroupId : parent,
    );
    if (service.unifiedStore == null && folderId != null) {
      try {
        await (await _service).moveFolderItems(
          groupIds: {group.id},
          destination: folderId,
        );
        group = (await (await bookmarkGroupRepository).getGroup(group.id))!;
      } catch (_) {
        await (await bookmarkGroupRepository).deleteGroup(group.id);
        rethrow;
      }
    }
    await _publishCommittedMutation();
    return group;
  });

  Future<BookmarkGroup> duplicateGroup(String groupId, String name) =>
      _serialize(() async {
        final service = await _service;
        final repository = await bookmarkGroupRepository;
        final source = (await repository.getGroup(groupId))!;
        var group = await service.duplicateGroup(groupId, name);
        try {
          if (source.folderId != null)
            await service.moveFolderItems(
              groupIds: {group.id},
              destination: source.folderId,
            );
        } catch (_) {
          await repository.deleteGroup(group.id);
          rethrow;
        }
        group = (await repository.getGroup(group.id))!;
        await _publishCommittedMutation();
        return group;
      });

  Future<CollectionFolder> createFolder(String name, {String? parentId}) =>
      _runTrackedMutation(
        () async => (await _service).createFolder(name, parentId: parentId),
      );
  Future<void> renameFolder(String id, String name) => _runTrackedMutation(
    () async => (await _service).renameFolder(id, name),
  );
  Future<void> moveFolderItems({
    Set<String> folderIds = const {},
    Set<String> groupIds = const {},
    required String? destination,
  }) => _runTrackedMutation(
    () async => (await _service).moveFolderItems(
      folderIds: folderIds,
      groupIds: groupIds,
      destination: destination,
    ),
  );
  Future<void> moveGroups(
    Set<String> groupIds, {
    required String? parentGroupId,
  }) => _runTrackedMutation(
    () async => (await _service).moveGroups(
      groupIds,
      parentGroupId: parentGroupId,
    ),
  );
  Future<BookmarkFolderDeletionPreview> previewDeleteFolder(String id) =>
      _serialize(() async => (await _service).previewDeleteFolder(id));
  Future<void> deleteFolder(BookmarkFolderDeletionPreview expected) =>
      _runTrackedMutation(() async {
        final service = await _service;
        final current = await service.previewDeleteFolder(expected.folderId);
        if (current != expected) throw BookmarkFolderChangedException(current);
        await service.deleteFolder(expected);
        for (final id in current.orphanBookmarkIds) {
          _removals.remove(current.snapshot.bookmarksById[id]?.uniqueId);
        }
      });

  Future<List<BookmarkGroup>> duplicateGroups(
    Map<String, String> names, {
    required List<BookmarkGroup> expectedGroups,
  }) => _runTrackedMutation(
    () async =>
        (await _service).duplicateGroups(names, expectedGroups: expectedGroups),
  );

  Future<BookmarkCollectionDeletionPreview> previewDeleteSelection({
    required Set<String> folderIds,
    required Set<String> groupIds,
  }) => _serialize(
    () async => (await _service).previewDeleteSelection(
      folderIds: folderIds,
      groupIds: groupIds,
    ),
  );

  Future<void> deleteSelection(
    BookmarkCollectionDeletionPreview expected,
  ) => _runTrackedMutation(() async {
    final service = await _service;
    final current = await service.previewDeleteSelection(
      folderIds: expected.selectedFolderIds,
      groupIds: expected.selectedGroupIds,
    );
    if (current != expected) throw BookmarkCollectionChangedException(current);
    if (service.unifiedStore != null) {
      _recordHierarchyDeletion(
        await service.deleteHierarchy(
          current.groupIds,
          expectedPreview: current,
        ),
      );
    } else {
      await service.deleteSelection(expected);
    }
    for (final id in current.orphanBookmarkIds) {
      _removals.remove(current.snapshot.bookmarksById[id]?.uniqueId);
    }
  });

  Future<void> renameGroup(String groupId, String name) => _serialize(() async {
    await (await bookmarkGroupRepository).renameGroup(groupId, name);
    await _publishCommittedMutation();
  });

  Future<BookmarkGroupDeletionPreview> deleteGroup(
    String groupId, {
    BookmarkGroupDeletionPreview? expectedPreview,
  }) => _serialize(() async {
    final repository = await bookmarkGroupRepository;
    final currentPreview = await repository.previewDeleteGroup(groupId);
    if (expectedPreview != null && currentPreview != expectedPreview) {
      throw BookmarkGroupChangedException(currentPreview);
    }
    final before = await _librarySnapshot;
    final service = await _service;
    final BookmarkGroupDeletionPreview preview;
    if (service.unifiedStore != null) {
      final deletion = await service.deleteHierarchy({groupId});
      _recordHierarchyDeletion(deletion);
      preview = deletion.singlePreview;
    } else {
      preview = await service.deleteGroup(groupId);
    }
    for (final id in preview.orphanBookmarkIds) {
      _removals.remove(before.bookmarksById[id]?.uniqueId);
    }
    await _publishCommittedMutation();
    return preview;
  });

  Future<void> addExistingBookmarkToGroup(
    PostBookmark bookmark,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      await (await _service).addBookmarkToGroup(
        groupId: groupId,
        existingBookmark: bookmark,
      );
      await _publishCommittedMutation();
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<void> addExistingBookmarksToGroup(
    Iterable<PostBookmark> bookmarks,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      final count = await (await _service).addBookmarksToGroup(
        bookmarks,
        groupId,
      );
      if (count > 0) await _rememberManualGroup(groupId);
      await _publishCommittedMutation();
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<void> addBookmarkToGroup(
    BooruConfigAuth config,
    Post post,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      final current = await _librarySnapshot;
      final booruId = config.booruIdHint;
      final existing = current.hasUnifiedRecords
          ? current.storedBookmarkForPost(post)
          : current.bookmarkForPost(post, fallbackBooruId: booruId);
      await (await _service).addBookmarkToGroup(
        groupId: groupId,
        existingBookmark: existing,
        createBookmarkIdentity: BookmarkUniqueId.fromPost(post, booruId),
        createBookmark: existing == null
            ? () => _createBookmark(config, post)
            : null,
        prepareBookmark: existing == null
            ? () => _prepareBookmark(config, post)
            : null,
      );
      if (existing == null ||
          !current.membershipsFor(existing.uniqueId).contains(groupId)) {
        await _rememberManualGroup(groupId);
      }
      await _publishCommittedMutation();
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<void> removeFromGroup(
    Iterable<PostBookmark> bookmarks,
    String groupId, {
    void Function(BookmarkGroupRemovalResult)? onRemoved,
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      final removal = await (await _service).removeBookmarksFromGroup(
        bookmarks,
        groupId,
      );
      if (removal.removedCount > 0) await _rememberManualGroup(groupId);
      await _publishCommittedMutation();
      _recordRemoval(removal);
      onRemoved?.call(removal);
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<void> removeFromGroupAndDeleteIfLast(
    BookmarkUniqueId bookmarkId,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _removeByIdentity(
    bookmarkId,
    groupId: groupId,
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<void> removeBookmarkFromId(
    BookmarkUniqueId bookmarkId, {
    void Function(BookmarkGroupRemovalResult)? onRemoved,
    void Function()? onSuccess,
    void Function()? onError,
  }) => _removeByIdentity(
    bookmarkId,
    onRemoved: onRemoved,
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<void> _removeByIdentity(
    BookmarkUniqueId bookmarkId, {
    String? groupId,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      final current = await _librarySnapshot;
      final bookmark = current.bookmarksByUniqueId[bookmarkId];
      if (bookmark == null) {
        onError?.call();
        return;
      }
      final removal = await (await _service).removeBookmarksFromGroup(
        [bookmark],
        groupId ?? defaultBookmarkGroupId,
      );
      if (removal.removedCount > 0)
        await _rememberManualGroup(groupId ?? defaultBookmarkGroupId);
      await _publishCommittedMutation();
      _recordRemoval(removal);
      onRemoved?.call(removal);
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<void> removeBookmark(
    PostBookmark bookmark, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => removeBookmarks(
    [bookmark],
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<void> removeBookmarkFromView(
    PostBookmark bookmark,
    BookmarkView view, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => switch (view.kind) {
    BookmarkViewKind.group => removeFromGroup(
      [bookmark],
      view.groupId!,
      onSuccess: onSuccess,
      onError: onError,
    ),
    BookmarkViewKind.all || BookmarkViewKind.subtree => Future.error(
      StateError('Select a source group.'),
    ),
  };

  Future<void> removeBookmarks(
    Iterable<PostBookmark> bookmarks, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      final selected = bookmarks.toList();
      await (await _service).deleteBookmarks(selected);
      for (final b in selected) {
        _removals.remove(b.uniqueId);
      }
      await _publishCommittedMutation();
      onSuccess?.call();
    } catch (_) {
      _mutation?.invalidate();
      await _publishCommittedMutation();
      onError?.call();
    }
  });

  Future<int> addPostsToGroup(
    BooruConfigAuth config,
    Iterable<Post> posts,
    String? groupId, {
    bool manual = false,
    List<CollectionBookmark> pools = const [],
  }) => _serialize(() async {
    if (pools.isEmpty) {
      final result = await _addPostsToGroup(config, posts, groupId);
      if (manual && result.changedCount > 0) {
        await _rememberManualGroup(groupId ?? defaultBookmarkGroupId);
      }
      await _publishAddedGroupMembers(result.createdBookmarks, groupId);
      return result.changedCount;
    }
    final repository = await bookmarkGroupRepository;
    final targetId = groupId ?? defaultBookmarkGroupId;
    final previous = await repository.getGroup(targetId);
    if (previous == null)
      throw StateError('The bookmark group no longer exists');
    final oldPools = await repository.getPoolBookmarks();
    final result = await _addPostsToGroup(config, posts, groupId);
    var poolCount = 0;
    try {
      poolCount = await _addPoolsToGroup(pools, targetId);
    } catch (error, stack) {
      final errors = <Object>[];
      try {
        await repository.replacePoolBookmarks(oldPools);
      } catch (e) {
        errors.add(e);
      }
      try {
        await repository.replaceMemberships(targetId, previous.bookmarkIds);
      } catch (e) {
        errors.add(e);
      }
      try {
        await (await _service).deleteBookmarks(result.createdBookmarks);
      } catch (e) {
        errors.add(e);
      }
      if (errors.isNotEmpty)
        throw BookmarkLibraryRollbackException(
          operationError: error,
          rollbackErrors: errors,
        );
      Error.throwWithStackTrace(error, stack);
    }
    if (manual && result.changedCount + poolCount > 0) {
      await _rememberManualGroup(targetId);
    }
    await _publishCommittedMutation();
    return result.changedCount + poolCount;
  });

  Future<void> _publishAddedGroupMembers(
    List<PostBookmark> createdBookmarks,
    String? groupId,
  ) async {
    if (!(_mutation?.isValid ?? false)) {
      await _publishCommittedMutation();
      return;
    }
    try {
      final repository = await bookmarkGroupRepository;
      final group = await repository.getGroup(
        groupId ?? defaultBookmarkGroupId,
      );
      if (group == null) {
        throw StateError('The bookmark group no longer exists.');
      }
      final current = await _librarySnapshot;
      _publishLibrary(
        current.withAddedGroupMembers(
          createdBookmarks: createdBookmarks,
          group: group,
          revision: current.hasUnifiedRecords ? _mutation?.revision : null,
        ),
      );
    } catch (_) {
      // A committed write stays successful even if publishing needs recovery.
      await _publishCommittedMutation();
    }
  }

  Future<({BookmarkGroup group, int addedCount})> createGroupWithPosts(
    String name,
    BooruConfigAuth config,
    Iterable<Post> posts, {
    String? folderId,
    String? parentGroupId,
    List<CollectionBookmark> pools = const [],
    RelatedPostsOrder? initialRelatedOrder,
  }) => _serialize(() async {
    final current = await _librarySnapshot;
    for (final post in posts) {
      if (!current.hasUnifiedRecords ||
          current.storedBookmarkForPost(post) == null) {
        BookmarkIdentity.fromPost(post);
      }
    }
    final repository = await bookmarkGroupRepository;
    if (folderId != null && parentGroupId != null) {
      throw ArgumentError('Choose one parent Group');
    }
    final service = await _service;
    final aliases = await repository.getLegacyFolderGroupIds();
    final parent = parentGroupId ?? aliases[folderId] ?? folderId;
    final group = await service.createGroup(
      name,
      parentGroupId: service.unifiedStore == null ? parentGroupId : parent,
    );
    try {
      if (service.unifiedStore == null && folderId != null)
        await (await _service).moveFolderItems(
          groupIds: {group.id},
          destination: folderId,
        );
    } catch (_) {
      await (await bookmarkGroupRepository).deleteGroup(group.id);
      rethrow;
    }
    var createdBookmarks = const <PostBookmark>[];
    late final ({int changedCount, List<PostBookmark> createdBookmarks}) result;
    var addedPools = 0;
    try {
      result = await _addPostsToGroup(config, posts, group.id);
      createdBookmarks = result.createdBookmarks;
      addedPools = await _addPoolsToGroup(
        pools,
        group.id,
        initialRelatedOrder: initialRelatedOrder,
      );
    } catch (error, stackTrace) {
      if (error case BookmarkPostBatchRollbackException(
        createdBookmarks: final leakedBookmarks,
      )) {
        createdBookmarks = leakedBookmarks;
      }
      final rollbackErrors = <Object>[];
      if (createdBookmarks.isNotEmpty) {
        try {
          await (await _service).deleteBookmarks(createdBookmarks);
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      }
      try {
        await repository.deleteGroup(group.id);
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      _mutation?.invalidate();
      await _publishCommittedMutation();
      if (rollbackErrors.isNotEmpty) {
        throw BookmarkGroupCreationRollbackException(
          creationError: error,
          rollbackErrors: List.unmodifiable(rollbackErrors),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (result.changedCount + addedPools > 0)
      await _rememberManualGroup(group.id);
    await _publishCommittedMutation();
    return (group: group, addedCount: result.changedCount + addedPools);
  });

  Future<({int changedCount, List<PostBookmark> createdBookmarks})>
  _addPostsToGroup(
    BooruConfigAuth config,
    Iterable<Post> posts,
    String? requestedGroupId,
  ) async {
    final groupId = requestedGroupId ?? defaultBookmarkGroupId;
    final current = await _librarySnapshot;
    final selected = posts.toList();
    for (final post in selected) {
      if (!current.hasUnifiedRecords ||
          current.storedBookmarkForPost(post) == null) {
        BookmarkIdentity.fromPost(post);
      }
    }
    final existing = <PostBookmark>[];
    final missing = <Post>[];
    final seen = <Object>{};
    for (final post in selected) {
      final identity = _bookmarkIdentity(post, config);
      final bookmark = current.hasUnifiedRecords
          ? current.storedBookmarkForPost(post)
          : current.bookmarkForPost(post, fallbackBooruId: config.booruIdHint);
      final Object selectionKey = current.hasUnifiedRecords
          ? bookmark == null
                ? (identity, post.origin.booruType)
                : ('saved', bookmark.id)
          : identity;
      if (!seen.add(selectionKey)) continue;
      if (bookmark == null) {
        missing.add(post);
      } else {
        existing.add(bookmark);
      }
    }
    final repository = await bookmarkGroupRepository;
    final target = await repository.getGroup(groupId);
    if (target == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final service = await _service;
    if (service.unifiedStore != null) {
      final drafts = <Bookmark>[];
      for (final post in missing) {
        drafts.add(await _prepareBookmark(config, post));
      }
      final result = await service.saveDraftsToGroup(
        drafts,
        groupId,
        savedRecords: existing,
      );
      return (
        changedCount: result.addedCount,
        createdBookmarks: result.createdRecords
            .whereType<PostBookmark>()
            .toList(),
      );
    }
    final before = target.bookmarkIds;
    final created = <PostBookmark>[];
    try {
      for (final post in missing) {
        created.add(await _createBookmark(config, post));
      }
      final addedIds = {
        for (final bookmark in [...existing, ...created]) bookmark.id,
      }.difference(before);
      if (addedIds.isNotEmpty) await repository.addBookmarks(groupId, addedIds);
      return (changedCount: addedIds.length, createdBookmarks: created);
    } catch (error, stackTrace) {
      final rollbackErrors = <Object>[];
      try {
        await repository.replaceMemberships(groupId, before);
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      rollbackErrors.addAll(await _deleteCreatedBookmarks(created));
      if (rollbackErrors.isNotEmpty) {
        throw BookmarkPostBatchRollbackException(
          operationError: error,
          rollbackErrors: List.unmodifiable(rollbackErrors),
          createdBookmarks: List.unmodifiable(created),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<Object>> _deleteCreatedBookmarks(
    List<PostBookmark> bookmarks,
  ) async {
    if (bookmarks.isEmpty) return const [];
    try {
      await (await _service).deleteBookmarks(bookmarks);
      return const [];
    } catch (error) {
      return [error];
    }
  }

  Future<BookmarkGroupRemovalResult> removePostsFromGroup(
    BooruConfigAuth config,
    Iterable<Post> posts,
    String groupId, {
    Set<String> poolLocalIds = const {},
  }) => _serialize(() async {
    final current = await _librarySnapshot;
    final bookmarks = posts
        .map(
          (post) => current.storedBookmarkForPost(post),
        )
        .whereType<PostBookmark>()
        .where(
          (bookmark) =>
              (current.hasUnifiedRecords
                      ? current.membershipsForId(bookmark.id)
                      : current.membershipsFor(bookmark.uniqueId))
                  .contains(groupId),
        )
        .toList();
    final result = await (await _service).removeBookmarksFromGroup(
      bookmarks,
      groupId,
      poolLocalIds: poolLocalIds,
    );
    if (result.removedCount > 0) await _rememberManualGroup(groupId);
    await _publishCommittedMutation();
    _recordRemoval(result);
    return result;
  });

  Future<int> deleteBookmarksForPosts(
    BooruConfigAuth config,
    Iterable<Post> posts,
  ) => _serialize(() async {
    final current = await _librarySnapshot;
    final bookmarks = posts
        .map(
          (post) => current.storedBookmarkForPost(post),
        )
        .whereType<PostBookmark>()
        .toSet()
        .toList();
    await (await _service).deleteBookmarks(bookmarks);
    for (final bookmark in bookmarks) {
      _removals.remove(bookmark.uniqueId);
    }
    await _publishCommittedMutation();
    return bookmarks.length;
  });

  Future<void> downloadBookmarks(
    BooruConfigAuth auth,
    BooruConfigDownload download,
    List<PostBookmark> bookmarks,
  ) async {
    // Native background jobs cannot enforce an anonymous scope's redirect and
    // revocation boundary. Never reconstruct an ordinary auth for that actor.
    if (auth.anonymousReadScope != null) return;
    final configs = ref.read(booruConfigProvider);
    final groups = <(BooruConfig, int, String, bool), List<PostBookmark>>{};
    final sourceCounts = <(BooruConfig, int, String), int>{};
    final sourceIndices = <Post, int>{};
    final engines = ref.read(booruEngineRegistryProvider);
    final blacklists = <BooruConfig, Set<String>>{};
    for (final bookmark in bookmarks) {
      final origin = bookmark.post.origin;
      final source = switch (const PostOriginResolver().resolve(
        origin,
        configs,
        allowProfileHintFallback: false,
      )) {
        ResolvedPostOrigin(:final config) => config,
        _ => null,
      };
      // A stored URL grants no native download permission. In particular, a
      // removed originating account must not borrow a compatible replacement.
      if (source == null || source.anonymousReadScope != null) continue;
      final blacklist = blacklists[source] ??= await ref.read(
        blacklistTagsProvider(source.filter).future,
      );
      if (!isExactLookupPostVisible(bookmark.post, source, blacklist)) continue;
      final sourceKey = (source, origin.booruType.id, origin.sourceHost);
      sourceIndices[bookmark.post] =
          sourceCounts.update(
            sourceKey,
            (count) => count + 1,
            ifAbsent: () => 1,
          ) -
          1;
      final nativePayload =
          engines
              .getPostCapability(origin.booruType)
              ?.codecFor(origin, bookmark.post.booruData) !=
          null;
      groups
          .putIfAbsent((
            source,
            origin.booruType.id,
            origin.sourceHost,
            nativePayload,
          ), () => [])
          .add(bookmark);
    }
    final subscriptions = <ProviderSubscription<ContentAccessContext?>>[];
    final operations =
        <
          ({
            DownloadNotifier notifier,
            List<PostBookmark> bookmarks,
            int totalCount,
            bool Function() isCurrent,
          })
        >[];
    try {
      for (final entry in groups.entries) {
        final (source, _, host, nativePayload) = entry.key;
        final binding = ViewerSourceBinding(source);
        final subscription = ref.listen(
          contentProfileAccessProvider(source.id),
          (_, _) {},
        );
        subscriptions.add(subscription);
        // Resolve the established visibility policy before capturing its key,
        // and retain the context only for this operation's preparation lifetime.
        await ref.read(blacklistTagsProvider(source.filter).future);
        final access = subscription.read();
        if (access == null) continue;
        bool current() {
          try {
            return binding.resolve(ref.read(booruConfigProvider)) != null &&
                subscription.read()?.key == access.key &&
                entry.value.every(
                  (bookmark) =>
                      ref
                          .read(
                            contentPostVisibilityProvider((
                              access: access.key,
                              post: bookmark.post,
                            )),
                          )
                          .asData
                          ?.value ==
                      true,
                );
          } catch (_) {
            // Container/provider disposal revokes pending work too.
            return false;
          }
        }

        if (!current()) continue;
        final ordinary = ref.read(
          sourceDownloadNotifierParamsProvider((
            source.auth,
            source.download,
          )),
        );
        final params = (
          auth: ordinary.auth,
          download: ordinary.download,
          profileIconUrl: source.profileIcon?.url,
          downloadFileUrlExtractor: nativePayload
              ? ordinary.downloadFileUrlExtractor
              : const UrlInsidePostExtractor(),
          filenameBuilder: nativePayload && ordinary.filenameBuilder != null
              ? ordinary.filenameBuilder
              : snapshotFileNameBuilderFor(entry.value.first.post),
          observer: ordinary.observer,
          canDownloadMultipleFiles: ordinary.canDownloadMultipleFiles,
          headers: ordinary.headers,
          settings: ordinary.settings,
          downloader: ordinary.downloader,
          logger: ordinary.logger,
        );
        operations.add((
          notifier: ref.read(downloadNotifierProvider(params).notifier),
          bookmarks: List<PostBookmark>.unmodifiable(entry.value),
          totalCount: sourceCounts[(source, entry.key.$2, host)]!,
          isCurrent: current,
        ));
      }
      for (final operation in operations) {
        if (!operation.isCurrent()) continue;
        final links = {
          for (final bookmark in operation.bookmarks)
            bookmark.post: bookmark.sourceUrl,
        };
        if (operation.totalCount == 1) {
          final bookmark = operation.bookmarks.single;
          await operation.notifier.download(
            bookmark.post,
            postUrl: bookmark.sourceUrl,
            isCurrent: operation.isCurrent,
          );
        } else {
          await operation.notifier.bulkDownload(
            [for (final bookmark in operation.bookmarks) bookmark.post],
            postUrlBuilder: (post) => links[post],
            totalCount: operation.totalCount,
            indexOf: (post) => sourceIndices[post]!,
            isCurrent: operation.isCurrent,
          );
        }
      }
    } finally {
      for (final subscription in subscriptions) subscription.close();
    }
  }

  Future<PostBookmark> _createBookmark(
    BooruConfigAuth config,
    Post post,
  ) async {
    final identity = BookmarkIdentity.fromPost(post);
    // Mixed selections carry independent origins. Generate each source link
    // with that post's profile instead of the grid's surrounding profile.
    final sourceConfig = switch (const PostOriginResolver().resolve(
      post.origin,
      ref.read(booruConfigProvider),
    )) {
      ResolvedPostOrigin(:final config) => config.auth,
      _
          when config.booruType == post.origin.booruType &&
              normalizePostSourceHost(config.url) == post.origin.sourceHost =>
        config,
      _ => null,
    };
    final repository = _mutation ?? await bookmarkRepository;

    Future<PostBookmark?> findStored() async =>
        (await repository.getBookmarksByIdentityOrThrow(
          [identity],
          imageUrlResolver: (booruId) =>
              ref.read(bookmarkUrlResolverProvider(booruId)),
        ))[identity];

    try {
      return await repository.addBookmark(
        post.origin.booruId,
        post,
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
        postLinkGenerator: (_) => sourceConfig == null
            ? const NoLinkPostLinkGenerator()
            : ref.read(postLinkGeneratorProvider(sourceConfig)),
      );
    } catch (error, stackTrace) {
      try {
        if (await findStored() case final committed?) return committed;
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<PostBookmark> _prepareBookmark(
    BooruConfigAuth config,
    Post post,
  ) async {
    BookmarkIdentity.fromPost(post);
    // Mixed selections carry independent origins. Generate each source link
    // with that post's profile instead of the grid's surrounding profile.
    final sourceConfig = switch (const PostOriginResolver().resolve(
      post.origin,
      ref.read(booruConfigProvider),
    )) {
      ResolvedPostOrigin(:final config) => config.auth,
      _
          when config.booruType == post.origin.booruType &&
              normalizePostSourceHost(config.url) == post.origin.sourceHost =>
        config,
      _ => null,
    };
    final capability = ref
        .read(booruEngineRegistryProvider)
        .getPostCapability(post.origin.booruType);
    final now = DateTime.now();
    return PostBookmark.fromSnapshot(
      id: 0,
      createdAt: now,
      updatedAt: now,
      snapshot: const StoredPostCodec().encode(
        post,
        dataCodec: capability?.codec,
      ),
      post: post,
      postId: post.id,
      sourceUrl: sourceConfig == null
          ? ''
          : ref.read(postLinkGeneratorProvider(sourceConfig)).getLink(post),
    );
  }

  BookmarkUniqueId _bookmarkIdentity(Post post, BooruConfigAuth config) =>
      bookmarkIdentityForPost(post, config.booruIdHint);
}

extension BookmarkCubitToastX on BookmarkNotifier {
  Future<void> addBookmarkWithToast(
    BooruConfigAuth config,
    Post post,
  ) async {
    final context = ref.read(appNavigationProvider).navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      return;
    }

    if (BookmarkUniqueId.fromPost(post) is UnbookmarkablePostIdentity) {
      Kurumi.showErrorToast(
        context,
        context.t.bookmark.missing_post_identity,
      );
      return;
    }

    await addBookmark(
      config,
      post,
      onSuccess: () {
        if (context.mounted) {
          Kurumi.showSuccessToast(context, context.t.bookmark.added);
        }
      },
      onError: () {
        if (context.mounted) {
          Kurumi.showErrorToast(context, context.t.bookmark.failed_to_add);
        }
      },
    );
  }

  Future<void> addBookmarksWithToast(
    BooruConfigAuth config,
    String booruUrl,
    Iterable<Post> posts,
  ) async {
    final context = ref.read(appNavigationProvider).navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      return;
    }

    if (posts.any(
      (post) => BookmarkUniqueId.fromPost(post) is UnbookmarkablePostIdentity,
    )) {
      Kurumi.showErrorToast(
        context,
        context.t.bookmark.missing_post_identity,
      );
      return;
    }

    await addBookmarks(
      config,
      posts,
      onSuccess: (count) {
        if (context.mounted) {
          Kurumi.showSuccessToast(
            context,
            context.t.bookmark.many_added.replaceAll('{0}', '$count'),
          );
        }
      },
      onError: () {
        if (context.mounted) {
          Kurumi.showErrorToast(
            context,
            context.t.bookmark.failed_to_add_many,
          );
        }
      },
    );
  }

  Future<void> removeBookmarkWithToast(
    BookmarkUniqueId bookmarkId, {
    void Function()? onSuccess,
  }) async {
    final context = ref.read(appNavigationProvider).navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      return;
    }

    await removeBookmarkFromId(
      bookmarkId,
      onRemoved: (r) {
        if (context.mounted) showRemovalUndo(context, r);
      },
      onSuccess: onSuccess,
      onError: () {
        if (context.mounted) {
          Kurumi.showErrorToast(context, context.t.bookmark.failed_to_remove);
        }
      },
    );
  }
}

extension BookmarkNotifierX on WidgetRef {
  BookmarkNotifier get bookmarks => read(bookmarkProvider.notifier);
}

/// Internal admission retry; no domain mutation has started when this is thrown.
final class _LibraryInitializationPending implements Exception {
  const _LibraryInitializationPending();
}

/// An admitted operation retains its storage and read view across dependency
/// replacement. Deferred callbacks lose access when the operation completes.
final class _BookmarkStorageSession {
  _BookmarkStorageSession({
    required this.repository,
    required this.groups,
    required this.snapshot,
  });
  final BookmarkRepository repository;
  final BookmarkGroupRepository groups;
  BookmarkLibraryState snapshot;
  bool active = true;
}
