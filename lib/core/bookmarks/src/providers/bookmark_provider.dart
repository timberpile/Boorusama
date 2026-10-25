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
import '../../../downloads/downloader/providers.dart';
import '../../../downloads/filename/types.dart';
import '../../../downloads/urls/providers.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import '../../../router.dart';
import '../../../settings/providers.dart';
import '../data/bookmark_convert.dart';
import '../data/providers.dart';
import '../services/bookmark_library_service.dart';
import '../services/bookmark_hydration_service.dart';
import '../services/bookmark_mutation_repository.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_group_repository.dart';
import '../../../groups/folder_tree.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_repository.dart';
import '../types/bookmark_target.dart';
import '../types/bookmark_view.dart';

final bookmarkLibraryProvider =
    AsyncNotifierProvider<BookmarkLibraryNotifier, BookmarkLibraryState>(
      BookmarkLibraryNotifier.new,
      dependencies: [
        settingsProvider,
        booruConfigProvider,
        sourceDownloadNotifierParamsProvider,
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
  final List<Bookmark> createdBookmarks;
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
  final _mutationSessionKey = Object();
  final _pendingHydration = <int, Bookmark>{};
  Timer? _hydrationPublicationTimer;

  // Zone-local rather than a notifier field: unrelated async readers must never
  // borrow an in-flight operation's write-through view.
  BookmarkMutationRepository? get _mutation =>
      Zone.current[_mutationSessionKey] as BookmarkMutationRepository?;

  void _recordRemoval(BookmarkGroupRemovalResult result) {
    if (result.removedCount == 0) return;
    _removals.clear();
    for (final bookmark in result.removedBookmarks) {
      _removals[bookmark.uniqueId] = result;
    }
  }

  void showRemovalUndo(
    BuildContext context,
    BookmarkGroupRemovalResult result,
  ) {
    if (result.removedCount == 0) return;
    final strings = context.t.bookmark;
    Kurumi.showSuccessToast(
      context,
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
          if (context.mounted) {
            Kurumi.showErrorToast(context, strings.undo_failed);
          }
        }
      },
    );
  }

  Future<void> undoRemoval(BookmarkGroupRemovalResult result) =>
      _runTrackedMutation(() async {
        final eligible = result.removedBookmarks
            .where((b) => identical(_removals[b.uniqueId], result))
            .toList();
        if (eligible.length != result.removedCount) {
          throw StateError('A later removal superseded this Undo.');
        }
        await (await _service).undoRemoval(result);
        for (final b in eligible) {
          _removals.remove(b.uniqueId);
        }
      });

  Future<BookmarkRepository> get bookmarkRepository =>
      ref.read(bookmarkRepoProvider.future);

  Future<BookmarkLibraryService> get _service async {
    final mutation = _mutation;
    return BookmarkLibraryService(
      bookmarkRepository: mutation ?? await bookmarkRepository,
      groupRepository: await ref.read(bookmarkGroupRepoProvider.future),
      imageUrlResolver: (booruId) =>
          ref.read(bookmarkUrlResolverProvider(booruId)),
      readMutationSnapshot: mutation == null
          ? null
          : () => _readMutationState(
              mutation,
              const BookmarkTarget.defaultGroup(),
            ),
    );
  }

  @override
  FutureOr<BookmarkLibraryState> build() async {
    _pendingHydration.clear();
    _hydrationPublicationTimer?.cancel();
    _hydrationPublicationTimer = null;
    ref.onDispose(() => _hydrationPublicationTimer?.cancel());
    final activeGroupId = ref.read(settingsProvider).activeBookmarkGroupId;
    return (await _service).load(BookmarkTarget.fromGroupId(activeGroupId));
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

  Future<BookmarkLibraryState> snapshotForExport() => _serialize(() => future);

  Future<void> syncActiveTargetFromSettings() => _serialize(_reload);

  Future<bool> setActiveTarget(BookmarkTarget target) => _serialize(() async {
    final groupId = target.groupId;
    final group = await (await ref.read(
      bookmarkGroupRepoProvider.future,
    )).getGroup(groupId);
    if (group == null) return false;

    final saved = await ref
        .read(settingsNotifierProvider.notifier)
        .updateWith(
          (settings) => settings.copyWith(
            activeBookmarkGroupId: target.groupId,
          ),
        );
    if (saved) await _publishCommittedMutation(target);
    return saved;
  });

  Future<T> _serialize<T>(
    Future<T> Function() operation, {
    bool publishHydration = true,
  }) => ref
      .read(dataMutationCoordinatorProvider)
      .runExclusive(
        () => _serializeLocally(operation, publishHydration: publishHydration),
      );

  Future<T> _serializeLocally<T>(
    Future<T> Function() operation, {
    required bool publishHydration,
  }) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.catchError((_) {}).then((_) async {
      BookmarkMutationRepository? mutation;
      try {
        if (_requiresRefresh) await _reload();
        if (publishHydration) _publishHydration();
        mutation = BookmarkMutationRepository(
          delegate: await bookmarkRepository,
          base: await future,
        );
        completer.complete(
          await runZoned(
            operation,
            zoneValues: {_mutationSessionKey: mutation},
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

  Future<void> _reload([BookmarkTarget? requestedTarget]) async {
    _mutation?.invalidate();
    final target =
        requestedTarget ??
        BookmarkTarget.fromGroupId(
          ref.read(settingsProvider).activeBookmarkGroupId,
        );
    try {
      state = AsyncValue.data(await (await _service).load(target));
      _pendingHydration.clear();
      _hydrationPublicationTimer?.cancel();
      _hydrationPublicationTimer = null;
      _requiresRefresh = false;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<BookmarkLibraryState> _readMutationState(
    BookmarkMutationRepository mutation,
    BookmarkTarget target,
  ) async {
    if (!mutation.isValid) return (await _service).load(target);
    final repository = await ref.read(bookmarkGroupRepoProvider.future);
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
      upserts: mutation.upserts,
      removedIds: mutation.removedIds,
      groups: groups,
      folders: folders,
      activeTarget: target,
    );
  }

  Future<void> _publishCommittedMutation([
    BookmarkTarget? requestedTarget,
  ]) async {
    final previousState = state;
    final mutation = _mutation;
    if (mutation != null && mutation.isValid) {
      try {
        final target =
            requestedTarget ??
            BookmarkTarget.fromGroupId(
              ref.read(settingsProvider).activeBookmarkGroupId,
            );
        final next = await _readMutationState(mutation, target);
        if (!identical(state.valueOrNull, next)) state = AsyncValue.data(next);
        _requiresRefresh = false;
        return;
      } catch (_) {
        mutation.invalidate();
      }
    }
    try {
      await _reload(requestedTarget);
    } catch (_) {
      state = previousState;
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
      final currentState = await future;
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
      final currentState = await future;
      final existing = currentState
          .bookmarksByUniqueId[BookmarkUniqueId.fromPost(post, booruId)];
      final groupId = currentState.activeTarget.groupId;
      await (await _service).addBookmarkToGroup(
        groupId: groupId,
        existingBookmark: existing,
        createBookmarkIdentity: BookmarkUniqueId.fromPost(post, booruId),
        createBookmark: existing == null
            ? () => _createBookmark(config, post)
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
          final current = (await future).bookmarksByUniqueId[bookmark.uniqueId];
          // A deletion, replacement, recovery reload or newer snapshot supersedes
          // this request. Do not resurrect a row or overwrite newer data.
          if (!identical(current, bookmark) ||
              _pendingHydration.containsKey(bookmark.id)) {
            return false;
          }
          final upgraded = await (await _service).upgradeBookmarkSnapshot(
            bookmark: bookmark,
            post: post,
            dataCodec: codec,
          );
          _pendingHydration[upgraded.id] = upgraded;
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
    final current = state.requireValue;
    final next = current.applyCommittedChanges(
      upserts: _pendingHydration.values,
      groups: current.groups,
      folders: current.folders,
      activeTarget: current.activeTarget,
    );
    _pendingHydration.clear();
    _hydrationPublicationTimer?.cancel();
    _hydrationPublicationTimer = null;
    state = AsyncValue.data(next);
  }

  Future<void> upgradeBookmarkSnapshot(
    Bookmark bookmark,
    Post post,
  ) => _serialize(() async {
    final current = (await future).bookmarksByUniqueId[bookmark.uniqueId];
    if (current == null || current.id != bookmark.id) return;
    final capability = ref
        .read(booruEngineRegistryProvider)
        .getPostCapability(post.origin.booruType);
    final codec = capability?.codecFor(post.origin, post.booruData);
    if (codec == null) {
      throw StateError('No compatible post codec is available.');
    }
    await (await _service).upgradeBookmarkSnapshot(
      bookmark: current,
      post: post,
      dataCodec: codec,
    );
    await _publishCommittedMutation();
  });

  Future<BookmarkToggleOutcome> togglePostTarget(
    BooruConfigAuth config,
    Post post, {
    BookmarkTarget? target,
    bool activateTarget = false,
    void Function(BookmarkGroupRemovalResult)? onRemoved,
  }) => _serialize(() async {
    try {
      if (BookmarkUniqueId.fromPost(post) is UnbookmarkablePostIdentity) {
        return BookmarkToggleOutcome.missingPostIdentity;
      }
      final current = await future;
      final selectedTarget = target ?? current.activeTarget;
      if (activateTarget) {
        final groupId = selectedTarget.groupId;
        final group = await (await ref.read(
          bookmarkGroupRepoProvider.future,
        )).getGroup(groupId);
        if (group == null) return BookmarkToggleOutcome.failed;

        final saved = await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(
                activeBookmarkGroupId: selectedTarget.groupId,
              ),
            );
        if (!saved) return BookmarkToggleOutcome.failed;
      }
      final uniqueId = bookmarkIdentityForPost(post, config.booruIdHint);
      final bookmark = current.bookmarksByUniqueId[uniqueId];
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
        await future,
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
    final bookmark = current.bookmarksByUniqueId[uniqueId];
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
      );
      await _publishCommittedMutation();
      return BookmarkToggleOutcome.added;
    }
    final removal = await (await _service).removeBookmarksFromGroup(
      [bookmark!],
      groupId,
    );
    await _publishCommittedMutation();
    _recordRemoval(removal);
    onRemoved?.call(removal);
    return BookmarkToggleOutcome.removed;
  }

  Future<BookmarkGroup> createGroup(
    String name, {
    bool activate = false,
    String? folderId,
  }) => _serialize(() async {
    var group = await (await _service).createGroup(name);
    if (folderId != null) {
      try {
        await (await _service).moveFolderItems(
          groupIds: {group.id},
          destination: folderId,
        );
        group = (await (await ref.read(
          bookmarkGroupRepoProvider.future,
        )).getGroup(group.id))!;
      } catch (_) {
        await (await ref.read(
          bookmarkGroupRepoProvider.future,
        )).deleteGroup(group.id);
        rethrow;
      }
    }
    var activated = false;
    if (activate) {
      activated = await ref
          .read(settingsNotifierProvider.notifier)
          .updateWith(
            (settings) => settings.copyWith(
              activeBookmarkGroupId: group.id,
            ),
          );
    }
    if (activate && !activated) {
      await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).deleteGroup(group.id);
      throw StateError('Failed to activate bookmark group ${group.id}.');
    }
    await _publishCommittedMutation(
      activated ? BookmarkTarget.group(group.id) : null,
    );
    return group;
  });

  Future<BookmarkGroup> duplicateGroup(String groupId, String name) =>
      _serialize(() async {
        final service = await _service;
        final repository = await ref.read(bookmarkGroupRepoProvider.future);
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
  Future<BookmarkFolderDeletionPreview> previewDeleteFolder(String id) =>
      _serialize(() async => (await _service).previewDeleteFolder(id));
  Future<void> deleteFolder(BookmarkFolderDeletionPreview expected) =>
      _runTrackedMutation(() async {
        final service = await _service;
        final current = await service.previewDeleteFolder(expected.folderId);
        if (current != expected) throw BookmarkFolderChangedException(current);
        final active = ref.read(settingsProvider).activeBookmarkGroupId;
        final clear = active != null && current.groupIds.contains(active);
        if (clear) {
          final ok = await ref
              .read(settingsNotifierProvider.notifier)
              .updateWith((s) => s.copyWith(activeBookmarkGroupId: null));
          if (!ok) throw StateError('Failed to clear active target');
        }
        try {
          await service.deleteFolder(expected);
          for (final id in current.orphanBookmarkIds) {
            _removals.remove(current.snapshot.bookmarksById[id]?.uniqueId);
          }
        } catch (error, stack) {
          if (clear) {
            final ok = await ref
                .read(settingsNotifierProvider.notifier)
                .updateWith((s) => s.copyWith(activeBookmarkGroupId: active));
            if (!ok)
              throw BookmarkGroupDeletionRollbackException(
                deletionError: error,
                rollbackErrors: [StateError('Failed to restore active target')],
              );
          }
          Error.throwWithStackTrace(error, stack);
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
    final active = ref.read(settingsProvider).activeBookmarkGroupId;
    final clear = active != null && current.groupIds.contains(active);
    if (clear &&
        !await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith((s) => s.copyWith(activeBookmarkGroupId: null))) {
      throw StateError('Failed to clear active target');
    }
    try {
      await service.deleteSelection(expected);
      for (final id in current.orphanBookmarkIds) {
        _removals.remove(current.snapshot.bookmarksById[id]?.uniqueId);
      }
    } catch (error, stack) {
      if (clear &&
          !await ref
              .read(settingsNotifierProvider.notifier)
              .updateWith((s) => s.copyWith(activeBookmarkGroupId: active))) {
        throw BookmarkGroupDeletionRollbackException(
          deletionError: error,
          rollbackErrors: [StateError('Failed to restore active target')],
        );
      }
      Error.throwWithStackTrace(error, stack);
    }
  });

  Future<void> renameGroup(String groupId, String name) => _serialize(() async {
    await (await ref.read(
      bookmarkGroupRepoProvider.future,
    )).renameGroup(groupId, name);
    await _publishCommittedMutation();
  });

  Future<BookmarkGroupDeletionPreview> deleteGroup(
    String groupId, {
    BookmarkGroupDeletionPreview? expectedPreview,
  }) => _serialize(() async {
    final repository = await ref.read(bookmarkGroupRepoProvider.future);
    final currentPreview = await repository.previewDeleteGroup(groupId);
    if (expectedPreview != null && currentPreview != expectedPreview) {
      throw BookmarkGroupChangedException(currentPreview);
    }
    final active = (await future).activeTarget.groupId;
    if (active == groupId) {
      final cleared = await ref
          .read(settingsNotifierProvider.notifier)
          .updateWith(
            (settings) => settings.copyWith(activeBookmarkGroupId: null),
          );
      if (!cleared) {
        throw StateError('Failed to clear the active bookmark group.');
      }
    }
    late final BookmarkGroupDeletionPreview preview;
    try {
      final before = await future;
      preview = await (await _service).deleteGroup(groupId);
      for (final id in preview.orphanBookmarkIds) {
        _removals.remove(before.bookmarksById[id]?.uniqueId);
      }
    } catch (error, stackTrace) {
      if (active != groupId) rethrow;
      final rollbackErrors = <Object>[];
      try {
        final restored = await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(
                activeBookmarkGroupId: groupId,
              ),
            );
        if (!restored) {
          throw StateError('Failed to restore the active bookmark group.');
        }
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        await _reload(BookmarkTarget.group(groupId));
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      if (rollbackErrors.isNotEmpty) {
        throw BookmarkGroupDeletionRollbackException(
          deletionError: error,
          rollbackErrors: List.unmodifiable(rollbackErrors),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    await _publishCommittedMutation(
      active == groupId ? const BookmarkTarget.defaultGroup() : null,
    );
    return preview;
  });

  Future<void> addExistingBookmarkToGroup(
    Bookmark bookmark,
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
    Iterable<Bookmark> bookmarks,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      await (await _service).addBookmarksToGroup(bookmarks, groupId);
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
      final current = await future;
      final booruId = config.booruIdHint;
      final existing =
          current.bookmarksByUniqueId[BookmarkUniqueId.fromPost(post, booruId)];
      await (await _service).addBookmarkToGroup(
        groupId: groupId,
        existingBookmark: existing,
        createBookmarkIdentity: BookmarkUniqueId.fromPost(post, booruId),
        createBookmark: existing == null
            ? () => _createBookmark(config, post)
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

  Future<void> removeFromGroup(
    Iterable<Bookmark> bookmarks,
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
      final current = await future;
      final bookmark = current.bookmarksByUniqueId[bookmarkId];
      if (bookmark == null) {
        onError?.call();
        return;
      }
      final removal = await (await _service).removeBookmarksFromGroup(
        [bookmark],
        groupId ?? current.activeTarget.groupId,
      );
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
    Bookmark bookmark, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => removeBookmarks(
    [bookmark],
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<void> removeBookmarkFromView(
    Bookmark bookmark,
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
    BookmarkViewKind.all => Future.error(StateError('Select a source group.')),
  };

  Future<void> removeBookmarks(
    Iterable<Bookmark> bookmarks, {
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
    String? groupId,
  ) => _serialize(() async {
    final result = await _addPostsToGroup(config, posts, groupId);
    await _publishAddedGroupMembers(result.createdBookmarks, groupId);
    return result.changedCount;
  });

  Future<void> _publishAddedGroupMembers(
    List<Bookmark> createdBookmarks,
    String? groupId,
  ) async {
    if (!(_mutation?.isValid ?? false)) {
      await _publishCommittedMutation();
      return;
    }
    try {
      final repository = await ref.read(bookmarkGroupRepoProvider.future);
      final group = await repository.getGroup(
        groupId ?? defaultBookmarkGroupId,
      );
      if (group == null) {
        throw StateError('The bookmark group no longer exists.');
      }
      final current = await future;
      state = AsyncValue.data(
        current.withAddedGroupMembers(
          createdBookmarks: createdBookmarks,
          group: group,
          requestedTarget: BookmarkTarget.fromGroupId(
            ref.read(settingsProvider).activeBookmarkGroupId,
          ),
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
  }) => _serialize(() async {
    for (final post in posts) {
      BookmarkIdentity.fromPost(post);
    }
    final previousTarget = (await future).activeTarget;
    final repository = await ref.read(bookmarkGroupRepoProvider.future);
    final group = await (await _service).createGroup(name);
    try {
      if (folderId != null)
        await (await _service).moveFolderItems(
          groupIds: {group.id},
          destination: folderId,
        );
    } catch (_) {
      await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).deleteGroup(group.id);
      rethrow;
    }
    final activated = await ref
        .read(settingsNotifierProvider.notifier)
        .updateWith(
          (settings) => settings.copyWith(activeBookmarkGroupId: group.id),
        );
    if (!activated) {
      await repository.deleteGroup(group.id);
      throw StateError('Failed to activate bookmark group ${group.id}.');
    }
    var createdBookmarks = const <Bookmark>[];
    late final ({int changedCount, List<Bookmark> createdBookmarks}) result;
    try {
      result = await _addPostsToGroup(config, posts, group.id);
      createdBookmarks = result.createdBookmarks;
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
        final restored = await ref
            .read(settingsNotifierProvider.notifier)
            .updateWith(
              (settings) => settings.copyWith(
                activeBookmarkGroupId: previousTarget.groupId,
              ),
            );
        if (!restored) {
          throw StateError('Failed to restore the active bookmark group.');
        }
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        await repository.deleteGroup(group.id);
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      _mutation?.invalidate();
      await _publishCommittedMutation(previousTarget);
      if (rollbackErrors.isNotEmpty) {
        throw BookmarkGroupCreationRollbackException(
          creationError: error,
          rollbackErrors: List.unmodifiable(rollbackErrors),
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    await _publishCommittedMutation(BookmarkTarget.group(group.id));
    return (group: group, addedCount: result.changedCount);
  });

  Future<({int changedCount, List<Bookmark> createdBookmarks})>
  _addPostsToGroup(
    BooruConfigAuth config,
    Iterable<Post> posts,
    String? requestedGroupId,
  ) async {
    final groupId = requestedGroupId ?? defaultBookmarkGroupId;
    final current = await future;
    final selected = posts.toList();
    for (final post in selected) {
      BookmarkIdentity.fromPost(post);
    }
    final existing = <Bookmark>[];
    final missing = <Post>[];
    final seen = <BookmarkUniqueId>{};
    for (final post in selected) {
      final identity = _bookmarkIdentity(post, config);
      if (!seen.add(identity)) continue;
      final bookmark = current.bookmarksByUniqueId[identity];
      if (bookmark == null) {
        missing.add(post);
      } else {
        existing.add(bookmark);
      }
    }
    final repository = await ref.read(bookmarkGroupRepoProvider.future);
    final target = await repository.getGroup(groupId);
    if (target == null) {
      throw StateError('Bookmark group $groupId does not exist.');
    }
    final before = target.bookmarkIds;
    final created = <Bookmark>[];
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
    List<Bookmark> bookmarks,
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
    String groupId,
  ) => _serialize(() async {
    final current = await future;
    final bookmarks = posts
        .map(
          (post) =>
              current.bookmarksByUniqueId[_bookmarkIdentity(post, config)],
        )
        .whereType<Bookmark>()
        .where(
          (bookmark) =>
              current.membershipsFor(bookmark.uniqueId).contains(groupId),
        )
        .toList();
    final result = await (await _service).removeBookmarksFromGroup(
      bookmarks,
      groupId,
    );
    await _publishCommittedMutation();
    _recordRemoval(result);
    return result;
  });

  Future<int> deleteBookmarksForPosts(
    BooruConfigAuth config,
    Iterable<Post> posts,
  ) => _serialize(() async {
    final current = await future;
    final bookmarks = posts
        .map(
          (post) =>
              current.bookmarksByUniqueId[_bookmarkIdentity(post, config)],
        )
        .whereType<Bookmark>()
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
    List<Bookmark> bookmarks,
  ) async {
    final configs = ref.read(booruConfigProvider);
    final settings = ref.read(settingsProvider);
    final downloader = ref.read(downloadServiceProvider);
    final logger = ref.read(loggerProvider);
    final groups = <(BooruConfig?, int, String, bool), List<Bookmark>>{};
    final sourceCounts = <(BooruConfig?, int, String), int>{};
    final sourceIndices = <Post, int>{};
    final engines = ref.read(booruEngineRegistryProvider);
    for (final bookmark in bookmarks) {
      final origin = bookmark.post.origin;
      final source = switch (const PostOriginResolver().resolve(
        origin,
        configs,
      )) {
        ResolvedPostOrigin(:final config) => config,
        _ => null,
      };
      final sourceKey = (source, origin.booruType.id, origin.sourceHost);
      sourceIndices[bookmark.post] =
          sourceCounts.update(
            sourceKey,
            (count) => count + 1,
            ifAbsent: () => 1,
          ) -
          1;
      final nativePayload =
          source != null &&
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
    // Capture source services before awaiting. The surrounding profile is never
    // authority for an orphan's credentials, filename template or destination.
    final operations = [
      for (final entry in groups.entries)
        () {
          final (source, _, host, nativePayload) = entry.key;
          final origin = entry.value.first.post.origin;
          final DownloadNotifierParams params;
          if (source != null) {
            final ordinary = ref.read(
              sourceDownloadNotifierParamsProvider((
                source.auth,
                source.download,
              )),
            );
            params = (
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
          } else {
            params = (
              auth: BooruConfigAuth(
                booruId: origin.booruId,
                booruIdHint: origin.booruId,
                url: host.isEmpty ? '' : 'https://$host',
                apiKey: null,
                login: null,
                passHash: null,
                proxySettings: null,
                networkSettings: null,
              ),
              download: const BooruConfigDownload(
                fileNameFormat: null,
                bulkFileNameFormat: null,
                location: null,
              ),
              profileIconUrl: null,
              downloadFileUrlExtractor: const UrlInsidePostExtractor(),
              filenameBuilder: snapshotFileNameBuilderFor(
                entry.value.first.post,
              ),
              observer: null,
              canDownloadMultipleFiles:
                  origin.booruType.canDownloadMultipleFiles
                  ? _snapshotBulkAllowed
                  : _snapshotBulkDenied,
              headers: const <String, String>{},
              settings: settings,
              downloader: downloader,
              logger: logger,
            );
          }
          return (
            notifier: ref.read(downloadNotifierProvider(params).notifier),
            bookmarks: List<Bookmark>.unmodifiable(entry.value),
            // Partitioning payloads must retain the original source group's
            // bulk filename template and bulk permission check.
            totalCount: sourceCounts[(source, entry.key.$2, host)]!,
          );
        }(),
    ];
    for (final operation in operations) {
      final links = {
        for (final bookmark in operation.bookmarks)
          bookmark.post: bookmark.sourceUrl,
      };
      if (operation.totalCount == 1) {
        final bookmark = operation.bookmarks.single;
        await operation.notifier.download(
          bookmark.post,
          postUrl: bookmark.sourceUrl,
        );
      } else {
        await operation.notifier.bulkDownload(
          [for (final bookmark in operation.bookmarks) bookmark.post],
          postUrlBuilder: (post) => links[post],
          totalCount: operation.totalCount,
          indexOf: (post) => sourceIndices[post]!,
        );
      }
    }
  }

  static bool _snapshotBulkAllowed() => true;
  static bool _snapshotBulkDenied() => false;

  Future<Bookmark> _createBookmark(
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

    Future<Bookmark?> findStored() async =>
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
