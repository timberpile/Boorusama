// Dart imports:
import 'dart:async';

// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import '../../../boorus/booru/types.dart';
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../download_activity/activity.dart';
import '../../../downloads/downloader/providers.dart';
import '../../../downloads/downloader/types.dart';
import '../../../downloads/filename/types.dart';
import '../../../http/client/providers.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import '../../../router.dart';
import '../../../settings/providers.dart';
import '../data/bookmark_convert.dart';
import '../data/providers.dart';
import '../services/bookmark_library_service.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_repository.dart';
import '../types/bookmark_target.dart';

final bookmarkLibraryProvider =
    AsyncNotifierProvider<BookmarkLibraryNotifier, BookmarkLibraryState>(
      BookmarkLibraryNotifier.new,
      dependencies: [settingsProvider],
    );

final bookmarkProvider = bookmarkLibraryProvider;

typedef BookmarkNotifier = BookmarkLibraryNotifier;

final bookmarkUrlResolverProvider = Provider.autoDispose
    .family<ImageUrlResolver, int?>((ref, booruId) {
      final booruType = intToBooruType(booruId);
      final registry = ref.watch(booruEngineRegistryProvider);
      return registry.getRepository(booruType)?.imageUrlResolver() ??
          const DefaultImageUrlResolver();
    });

class BookmarkLibraryNotifier extends AsyncNotifier<BookmarkLibraryState> {
  Future<void> _mutationTail = Future.value();

  ImageCacheManager? get _cacheManager =>
      ref.read(bookmarkImageCacheManagerProvider);

  Future<BookmarkRepository> get bookmarkRepository =>
      ref.read(bookmarkRepoProvider.future);

  Future<BookmarkLibraryService> get _service async => BookmarkLibraryService(
    bookmarkRepository: await bookmarkRepository,
    groupRepository: await ref.read(bookmarkGroupRepoProvider.future),
    imageUrlResolver: (booruId) =>
        ref.read(bookmarkUrlResolverProvider(booruId)),
    clearBookmarkCache: _clearBookmarkCache,
  );

  @override
  FutureOr<BookmarkLibraryState> build() async {
    final activeGroupId = ref.watch(
      settingsProvider.select((settings) => settings.activeBookmarkGroupId),
    );
    return (await _service).load(BookmarkTarget.fromGroupId(activeGroupId));
  }

  Future<bool> setActiveTarget(BookmarkTarget target) async {
    final saved = await ref
        .read(settingsNotifierProvider.notifier)
        .updateWith(
          (settings) => settings.copyWith(
            activeBookmarkGroupId: target.groupId,
          ),
        );
    if (saved) await _reload();
    return saved;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _reload() async {
    final current = state.valueOrNull;
    final target = current?.activeTarget ?? const BookmarkTarget.ungrouped();
    state = AsyncValue.data(await (await _service).load(target));
  }

  Future<void> _clearBookmarkCache(Bookmark bookmark) async {
    if (_cacheManager case final cache?) {
      await Future.wait([
        cache.clearCache(cache.generateCacheKey(bookmark.originalUrl)),
        cache.clearCache(cache.generateCacheKey(bookmark.sampleUrl)),
        cache.clearCache(cache.generateCacheKey(bookmark.thumbnailUrl)),
      ]);
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

      await (await bookmarkRepository).addBookmarks(
        booruId,
        filtered,
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
        postLinkGenerator: (booruId) =>
            ref.read(postLinkGeneratorProvider(config)),
      );
      await _reload();
      onSuccess?.call(filtered.length);
    } catch (_) {
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
      final booruId = config.booruIdHint;
      final currentState = await future;
      final existing = currentState
          .bookmarksByUniqueId[BookmarkUniqueId.fromPost(post, booruId)];
      if (currentState.activeTarget.groupId case final groupId?) {
        await (await _service).addBookmarkToGroup(
          groupId: groupId,
          existingBookmark: existing,
          createBookmark: existing == null
              ? () => bookmarkRepository.then(
                  (repository) => repository.addBookmark(
                    booruId,
                    post,
                    imageUrlResolver: (booruId) =>
                        ref.read(bookmarkUrlResolverProvider(booruId)),
                    postLinkGenerator: (booruId) =>
                        ref.read(postLinkGeneratorProvider(config)),
                  ),
                )
              : null,
        );
      } else {
        if (existing != null) {
          await (await _service).moveBookmarkToUngrouped(existing);
        } else {
          await (await bookmarkRepository).addBookmark(
            booruId,
            post,
            imageUrlResolver: (booruId) =>
                ref.read(bookmarkUrlResolverProvider(booruId)),
            postLinkGenerator: (booruId) =>
                ref.read(postLinkGeneratorProvider(config)),
          );
        }
      }
      await _reload();
      onSuccess?.call();
    } catch (_) {
      onError?.call();
    }
  });

  Future<BookmarkGroup> createGroup(String name, {bool activate = false}) =>
      _serialize(() async {
        final group = await (await ref.read(
          bookmarkGroupRepoProvider.future,
        )).createGroup(name);
        if (activate) {
          await ref
              .read(settingsNotifierProvider.notifier)
              .updateWith(
                (settings) => settings.copyWith(
                  activeBookmarkGroupId: group.id,
                ),
              );
        }
        await _reload();
        return group;
      });

  Future<BookmarkGroup> duplicateGroup(String groupId, String name) =>
      _serialize(() async {
        final group = await (await ref.read(
          bookmarkGroupRepoProvider.future,
        )).duplicateGroup(groupId, name: name);
        await _reload();
        return group;
      });

  Future<void> renameGroup(String groupId, String name) => _serialize(() async {
    await (await ref.read(
      bookmarkGroupRepoProvider.future,
    )).renameGroup(groupId, name);
    await _reload();
  });

  Future<BookmarkGroupDeletionPreview> deleteGroup(String groupId) =>
      _serialize(() async {
        final preview = await (await _service).deleteGroup(groupId);
        final active = (await future).activeTarget.groupId;
        if (active == groupId) {
          await ref
              .read(settingsNotifierProvider.notifier)
              .updateWith(
                (settings) => settings.copyWith(activeBookmarkGroupId: null),
              );
        }
        await _reload();
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
      await _reload();
      onSuccess?.call();
    } catch (_) {
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
      await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).addBookmarks(
        groupId,
        bookmarks.map((bookmark) => bookmark.id).toSet(),
      );
      await _reload();
      onSuccess?.call();
    } catch (_) {
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
        createBookmark: existing == null
            ? () async => (await bookmarkRepository).addBookmark(
                booruId,
                post,
                imageUrlResolver: (booruId) =>
                    ref.read(bookmarkUrlResolverProvider(booruId)),
                postLinkGenerator: (booruId) =>
                    ref.read(postLinkGeneratorProvider(config)),
              )
            : null,
      );
      await _reload();
      onSuccess?.call();
    } catch (_) {
      onError?.call();
    }
  });

  Future<void> removeFromGroup(
    Iterable<Bookmark> bookmarks,
    String groupId, {
    bool deleteWhenMembershipBecomesEmpty = false,
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      await (await _service).removeBookmarksFromGroup(
        bookmarks,
        groupId,
        deleteWhenMembershipBecomesEmpty: deleteWhenMembershipBecomesEmpty,
      );
      await _reload();
      onSuccess?.call();
    } catch (_) {
      onError?.call();
    }
  });

  Future<void> removeFromGroupAndDeleteIfLast(
    BookmarkUniqueId bookmarkId,
    String groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    final bookmark = (await future).bookmarksByUniqueId[bookmarkId];
    if (bookmark == null) {
      onError?.call();
      return;
    }
    return removeFromGroup(
      [bookmark],
      groupId,
      deleteWhenMembershipBecomesEmpty: true,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> removeBookmarkFromId(
    BookmarkUniqueId bookmarkId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    final bookmark = (await future).bookmarksByUniqueId[bookmarkId];
    if (bookmark == null) {
      onError?.call();
      return;
    }
    return removeBookmark(bookmark, onSuccess: onSuccess, onError: onError);
  }

  Future<void> removeBookmark(
    Bookmark bookmark, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => removeBookmarks(
    [bookmark],
    onSuccess: onSuccess,
    onError: onError,
  );

  Future<void> removeBookmarks(
    Iterable<Bookmark> bookmarks, {
    void Function()? onSuccess,
    void Function()? onError,
  }) => _serialize(() async {
    try {
      await (await _service).deleteBookmarks(bookmarks);
      await _reload();
      onSuccess?.call();
    } catch (_) {
      onError?.call();
    }
  });

  Future<void> downloadBookmarks(
    BooruConfigAuth auth,
    BooruConfigDownload download,
    List<Bookmark> bookmarks,
  ) async {
    final settings = ref.read(settingsProvider);
    final networkConstraint = await resolveDownloadNetworkConstraint(
      ref,
      settings.downloadNetworkPolicy,
    );
    if (networkConstraint == null) return;

    final downloader = ref.read(downloadServiceProvider);
    final headers = ref.read(httpHeadersProvider(auth));
    final tasks = bookmarks.map((bookmark) async {
      final fileName = await fallbackFileNameBuilder.generate(
        settings,
        download,
        bookmark.toPost(),
        downloadUrl: bookmark.originalUrl,
      );
      final result = await downloader.download(
        DownloadOptions.fromSettings(
          settings,
          config: download,
          url: bookmark.originalUrl,
          metadata: DownloaderMetadata(
            thumbnailUrl: bookmark.thumbnailUrl,
            fileSize: null,
            siteUrl: bookmark.sourceUrl,
            group: null,
          ),
          filename: fileName,
          headers: headers,
          networkConstraint: networkConstraint,
        ),
      );
      return (
        result: result,
        fileName: fileName,
        thumbnailUrl: bookmark.thumbnailUrl,
      );
    }).toList();

    final results = await Future.wait(tasks);
    for (final outcome in results) {
      ref
          .read(immediateDownloadActivitiesProvider.notifier)
          .recordImmediateOutcome(
            outcome.result,
            label: outcome.fileName,
            thumbnailUrl: outcome.thumbnailUrl,
          );
    }
    final failures = results
        .map((outcome) => outcome.result)
        .whereType<DownloadFailure>()
        .toList();
    if (failures.isEmpty) return;
    final context = navigatorKey.currentContext;
    final uniqueErrors = failures
        .map((error) => error.error.getErrorMessage())
        .toSet()
        .take(3)
        .join('\n');
    if (context != null && context.mounted) {
      Kurumi.showErrorToast(
        context,
        'Download failed:\n$uniqueErrors',
        duration: const Duration(seconds: 5),
      );
    }
  }
}

extension BookmarkCubitToastX on BookmarkNotifier {
  Future<void> addBookmarkWithToast(
    BooruConfigAuth config,
    Post post,
  ) async {
    final context = navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      return;
    }

    await addBookmark(
      config,
      post,
      onSuccess: () =>
          Kurumi.showSuccessToast(context, context.t.bookmark.added),
      onError: () =>
          Kurumi.showErrorToast(context, context.t.bookmark.failed_to_add),
    );
  }

  Future<void> addBookmarksWithToast(
    BooruConfigAuth config,
    String booruUrl,
    Iterable<Post> posts,
  ) async {
    final context = navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      return;
    }

    await addBookmarks(
      config,
      posts,
      onSuccess: (count) => Kurumi.showSuccessToast(
        context,
        context.t.bookmark.many_added.replaceAll('{0}', '$count'),
      ),
      onError: () =>
          Kurumi.showErrorToast(context, context.t.bookmark.failed_to_add_many),
    );
  }

  Future<void> removeBookmarkWithToast(
    BookmarkUniqueId bookmarkId, {
    void Function()? onSuccess,
  }) async {
    final context = navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      return;
    }

    await removeBookmarkFromId(
      bookmarkId,
      onSuccess: () {
        Kurumi.showSuccessToast(context, context.t.bookmark.removed);
        onSuccess?.call();
      },
      onError: () =>
          Kurumi.showErrorToast(context, context.t.bookmark.failed_to_remove),
    );
  }
}

extension BookmarkNotifierX on WidgetRef {
  BookmarkNotifier get bookmarks => read(bookmarkProvider.notifier);
}
