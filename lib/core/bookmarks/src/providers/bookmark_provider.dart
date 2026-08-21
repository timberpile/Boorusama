// Dart imports:
import 'dart:async';

// Package imports:
import 'package:cache_manager/cache_manager.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
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
import '../types/bookmark.dart';
import '../types/bookmark_group_repository.dart';
import '../types/bookmark_repository.dart';

final bookmarkProvider = AsyncNotifierProvider<BookmarkNotifier, BookmarkState>(
  BookmarkNotifier.new,
  dependencies: [
    settingsProvider,
  ],
);

final bookmarkUrlResolverProvider = Provider.autoDispose
    .family<ImageUrlResolver, int?>((ref, booruId) {
      final booruType = intToBooruType(booruId);

      final registry = ref.watch(booruEngineRegistryProvider);

      final repo = registry.getRepository(booruType);

      return repo?.imageUrlResolver() ?? const DefaultImageUrlResolver();
    });

class BookmarkNotifier extends AsyncNotifier<BookmarkState> {
  ImageCacheManager? get _cacheManager =>
      ref.read(bookmarkImageCacheManagerProvider);

  @override
  FutureOr<BookmarkState> build() {
    return _loadState();
  }

  Future<BookmarkState> _loadState() async {
    final bookmarks = await (await bookmarkRepository)
        .getAllBookmarks(
          imageUrlResolver: (booruId) =>
              ref.read(bookmarkUrlResolverProvider(booruId)),
        )
        .run();

    return bookmarks.fold<Future<BookmarkState>>(
      (error) => Future.value(const BookmarkState(bookmarks: ISet.empty())),
      (bookmarks) async {
        final groupRepo = await bookmarkGroupRepository;
        final bookmarkIds = bookmarks.map((bookmark) => bookmark.id).toSet();

        await groupRepo.pruneStaleMemberships(bookmarkIds: bookmarkIds);
        final memberships = await groupRepo.getMembershipsByBookmark();

        return BookmarkState(
          bookmarks: {
            for (final bookmark in bookmarks) bookmark.uniqueId,
          }.toISet(),
          memberships: {
            for (final bookmark in bookmarks)
              bookmark.uniqueId: Set.unmodifiable(
                memberships[bookmark.id] ?? const <int>{},
              ),
          },
        );
      },
    );
  }

  Future<BookmarkRepository> get bookmarkRepository =>
      ref.read(bookmarkRepoProvider.future);

  Future<BookmarkGroupRepository> get bookmarkGroupRepository =>
      ref.read(bookmarkGroupRepoProvider.future);

  Future<void> _refreshState() async {
    state = AsyncValue.data(await _loadState());
  }

  Future<void> addBookmarks(
    BooruConfigAuth config,
    Iterable<Post> posts, {
    void Function(int count)? onSuccess,
    void Function()? onError,
  }) async {
    try {
      final booruId = config.booruIdHint;
      final currentState = await future;

      // filter out already bookmarked posts
      final filtered = posts
          .where(
            (post) => !currentState.isBookmarked(post, booruId),
          )
          .toList();

      await (await bookmarkRepository).addBookmarks(
        booruId,
        filtered,
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
        postLinkGenerator: (booruId) =>
            ref.read(postLinkGeneratorProvider(config)),
      );
      onSuccess?.call(filtered.length);

      await _refreshState();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> addBookmark(
    BooruConfigAuth config,
    Post post, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    try {
      final booruId = config.booruIdHint;
      final currentState = await future;

      // check if post is already bookmarked
      if (currentState.isBookmarked(post, booruId)) {
        return;
      }

      await (await bookmarkRepository).addBookmark(
        booruId,
        post,
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
        postLinkGenerator: (booruId) =>
            ref.read(postLinkGeneratorProvider(config)),
      );
      onSuccess?.call();
      await _refreshState();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> addBookmarkToGroup(
    BooruConfigAuth config,
    Post post,
    int groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    Bookmark? createdBookmark;

    try {
      final bookmarks = await (await bookmarkRepository).getAllBookmarksOrEmpty(
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
      );
      var bookmark = bookmarks.firstWhereOrNull(
        (bookmark) =>
            bookmark.uniqueId ==
            BookmarkUniqueId.fromPost(post, config.booruIdHint),
      );

      if (bookmark == null) {
        bookmark = await (await bookmarkRepository).addBookmark(
          config.booruIdHint,
          post,
          imageUrlResolver: (booruId) =>
              ref.read(bookmarkUrlResolverProvider(booruId)),
          postLinkGenerator: (booruId) =>
              ref.read(postLinkGeneratorProvider(config)),
        );
        createdBookmark = bookmark;
      }

      await (await bookmarkGroupRepository).addBookmarkToGroup(
        bookmarkId: bookmark.id,
        groupId: groupId,
      );
      await _refreshState();
      onSuccess?.call();
    } catch (e) {
      if (createdBookmark != null) {
        try {
          await (await bookmarkRepository).removeBookmark(createdBookmark);
        } catch (_) {
          // Preserve the original error for the caller.
        }
      }
      onError?.call();
    }
  }

  Future<void> addExistingBookmarkToGroup(
    Bookmark bookmark,
    int groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    try {
      await (await bookmarkGroupRepository).addBookmarkToGroup(
        bookmarkId: bookmark.id,
        groupId: groupId,
      );
      await _refreshState();
      onSuccess?.call();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> addBookmarkIdToGroup(
    BookmarkUniqueId bookmarkId,
    int groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    try {
      final bookmarks = await (await bookmarkRepository).getAllBookmarksOrEmpty(
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
      );
      final bookmark = bookmarks.firstWhereOrNull(
        (bookmark) => bookmark.uniqueId == bookmarkId,
      );
      if (bookmark == null) {
        onError?.call();
        return;
      }

      await (await bookmarkGroupRepository).addBookmarkToGroup(
        bookmarkId: bookmark.id,
        groupId: groupId,
      );
      await _refreshState();
      onSuccess?.call();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> removeBookmarkFromGroup(
    BookmarkUniqueId bookmarkId,
    int groupId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    try {
      final bookmarks = await (await bookmarkRepository).getAllBookmarksOrEmpty(
        imageUrlResolver: (booruId) =>
            ref.read(bookmarkUrlResolverProvider(booruId)),
      );
      final bookmark = bookmarks.firstWhereOrNull(
        (bookmark) => bookmark.uniqueId == bookmarkId,
      );

      if (bookmark == null) {
        onError?.call();
        return;
      }

      final groupRepo = await bookmarkGroupRepository;
      final memberships = await groupRepo.getMembershipsByBookmark();
      final bookmarkMemberships = memberships[bookmark.id] ?? const <int>{};

      if (bookmarkMemberships.length == 1 &&
          bookmarkMemberships.contains(groupId)) {
        await _removeBookmarksInternal([bookmark]);
      } else {
        await groupRepo.removeBookmarkFromGroup(
          bookmarkId: bookmark.id,
          groupId: groupId,
        );
      }

      await _refreshState();
      onSuccess?.call();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> removeBookmarkFromId(
    BookmarkUniqueId bookmarkId, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    final bookmarks = await (await bookmarkRepository).getAllBookmarksOrEmpty(
      imageUrlResolver: (booruId) =>
          ref.read(bookmarkUrlResolverProvider(booruId)),
    );

    final bookmark = bookmarks.firstWhereOrNull(
      (b) => b.uniqueId == bookmarkId,
    );

    if (bookmark == null) {
      onError?.call();
      return;
    }

    return removeBookmark(
      bookmark,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  Future<void> removeBookmark(
    Bookmark bookmark, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    try {
      await _removeBookmarksInternal([bookmark]);
      onSuccess?.call();
      await _refreshState();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> _removeBookmarksInternal(
    Iterable<Bookmark> bookmarks,
  ) async {
    final bookmarkList = bookmarks.toList();
    final groupRepo = await bookmarkGroupRepository;
    await Future.wait(
      bookmarkList.map(
        (bookmark) => groupRepo.removeBookmarkFromAllGroups(bookmark.id),
      ),
    );
    await (await bookmarkRepository).removeBookmarks(bookmarkList);

    // Clear all image variants for each bookmark.
    if (_cacheManager case final cache?) {
      await Future.wait(
        bookmarkList.expand(
          (b) => [
            cache.clearCache(
              cache.generateCacheKey(b.originalUrl),
            ),
            cache.clearCache(
              cache.generateCacheKey(b.sampleUrl),
            ),
            cache.clearCache(
              cache.generateCacheKey(b.thumbnailUrl),
            ),
          ],
        ),
      );
    }
  }

  Future<void> removeBookmarks(
    Iterable<Bookmark> bookmarks, {
    void Function()? onSuccess,
    void Function()? onError,
  }) async {
    try {
      await _removeBookmarksInternal(bookmarks);
      onSuccess?.call();
      await _refreshState();
    } catch (e) {
      onError?.call();
    }
  }

  Future<void> removeBookmarksByIds(
    Set<int> bookmarkIds,
  ) async {
    final bookmarks = await (await bookmarkRepository).getAllBookmarksOrEmpty(
      imageUrlResolver: (booruId) =>
          ref.read(bookmarkUrlResolverProvider(booruId)),
    );
    await _removeBookmarksInternal(
      bookmarks.where((bookmark) => bookmarkIds.contains(bookmark.id)),
    );
    await _refreshState();
  }

  Future<void> downloadBookmarks(
    BooruConfigAuth auth,
    BooruConfigDownload download,
    List<Bookmark> bookmarks,
  ) async {
    final settings = ref.read(settingsProvider);
    final downloader = ref.read(downloadServiceProvider);
    final headers = ref.read(httpHeadersProvider(auth));

    final fileNameBuilder = fallbackFileNameBuilder;

    final tasks = bookmarks.map(
      (bookmark) async {
        final fileName = await fileNameBuilder.generate(
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
          ),
        );
        return (
          result: result,
          fileName: fileName,
          thumbnailUrl: bookmark.thumbnailUrl,
        );
      },
    ).toList();

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

    if (failures.isNotEmpty) {
      final context = navigatorKey.currentContext;

      final uniqueErrors = failures
          .map((e) => e.error.getErrorMessage())
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

class BookmarkState extends Equatable {
  const BookmarkState({
    required this.bookmarks,
    this.memberships = const {},
    this.error = '',
  });
  final ISet<BookmarkUniqueId> bookmarks;
  final Map<BookmarkUniqueId, Set<int>> memberships;
  final String error;

  BookmarkState copyWith({
    ISet<BookmarkUniqueId>? bookmarks,
    Map<BookmarkUniqueId, Set<int>>? memberships,
    String? error,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      memberships: memberships ?? this.memberships,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [bookmarks, memberships, error];
}

extension BookmarkStateX on BookmarkState {
  bool isBookmarked(Post post, int booruId) {
    return bookmarks.contains(BookmarkUniqueId.fromPost(post, booruId));
  }

  Set<int> groupIdsFor(Post post, int booruId) {
    return memberships[BookmarkUniqueId.fromPost(post, booruId)] ??
        const <int>{};
  }

  bool isInGroup(Post post, int booruId, int groupId) {
    return groupIdsFor(post, booruId).contains(groupId);
  }

  bool isUngrouped(Post post, int booruId) {
    return isBookmarked(post, booruId) && groupIdsFor(post, booruId).isEmpty;
  }

  int groupCountFor(Post post, int booruId) {
    return groupIdsFor(post, booruId).length;
  }
}

extension BookmarkNotifierX on WidgetRef {
  BookmarkNotifier get bookmarks => read(bookmarkProvider.notifier);
}
