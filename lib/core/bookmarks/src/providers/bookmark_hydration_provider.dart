import 'dart:async';

import '../../../content/groups/owned_read_cache.dart';
import '../../../content/content_access.dart';
import '../../../posts/cross_profile_lookup/src/data/post_lookup_visibility.dart';
import '../../../posts/rating/types.dart';
import 'bookmark_read_access.dart';

import 'package:dio/dio.dart';

import '../../../blacklists/providers.dart';
import '../../../content/content_access_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boorus/engine/providers.dart';
import '../../../http/client/coordination.dart';
import '../../../configs/config/types.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import '../services/bookmark_hydration_service.dart';
import 'bookmark_provider.dart';

final bookmarkRecoveryServiceProvider = Provider<BookmarkRecoveryService>((
  ref,
) {
  final reads = OwnedReadCache<(ContentAccessKey, int), Post?>();
  ref.onDispose(reads.dispose);
  Future<Post?> fetchPost(
    BooruConfig config,
    int id, {
    bool share = false,
  }) async {
    if (ref.read(booruRepoProvider(config.auth)) == null) {
      throw StateError('Post repository unavailable');
    }
    await ref.read(blacklistTagsProvider(config.filter).future);
    final key =
        config.anonymousReadScope?.key ??
        ref.read(contentProfileAccessProvider(config.id))?.key;
    final access = key == null
        ? null
        : ref.read(contentAccessContextProvider(key));
    if (access == null || access.config != config)
      throw StateError('Bookmark reader revoked');
    bool current() =>
        ref
            .read(contentAccessContextProvider(access.key))
            ?.hasSameAuthorization(access) ==
        true;
    Future<Post?> load() async {
      final caller = share
          ? ApiRequestContext.current()
          : const ApiRequestContext();
      final cancellation = CancelToken();
      if (caller.cancelToken case final token?) {
        unawaited(
          token.whenCancel.then(
            (_) => cancellation.cancel('Owner revoked'),
          ),
        );
      }
      final subscription = ref.listen(
        contentAccessContextProvider(access.key),
        (_, next) {
          if (next?.hasSameAuthorization(access) != true)
            cancellation.cancel('Bookmark reader revoked');
        },
      );
      try {
        final result = await runWithApiRequestContext(
          ApiRequestContext(
            cancelToken: cancellation,
            canStart: () => current() && (caller.canStart?.call() ?? true),
            canAdmit: () => current() && (caller.canAdmit?.call() ?? true),
            requestClassResolver: () => caller.requestClass,
            allowCooldownRetryResolver: () => caller.allowCooldownRetry,
            changes: caller.changes,
            onStarted: caller.onStarted,
          ),
          () => ref
              .read(originAwarePostRepoProvider(config))
              .getPost(NumericPostId(id))
              .run(),
        );
        if (!current()) throw StateError('Bookmark reader revoked');
        return result.fold((error) => throw error, (post) => post);
      } finally {
        subscription.close();
      }
    }

    return share ? reads.load((access.key, id), load) : load();
  }

  return BookmarkRecoveryService(
    resolutionGuard: (config) {
      final key =
          config.anonymousReadScope?.key ??
          ref.read(contentProfileAccessProvider(config.id))?.key;
      final access = key == null
          ? null
          : ref.read(contentAccessContextProvider(key));
      return () =>
          access != null &&
          access.config == config &&
          ref
                  .read(contentAccessContextProvider(access.key))
                  ?.hasSameAuthorization(access) ==
              true;
    },
    latestBookmark: (post) async =>
        (await ref.read(bookmarkProvider.future)).bookmarkForPost(post),
    commitResolved: (bookmark, post, current) async {
      if (ref
              .read(bookmarkProvider)
              .valueOrNull
              ?.localBookmarkIds
              .contains(bookmark.id) ==
          true) {
        await ref
            .read(bookmarkProvider.notifier)
            .upgradeBookmarkSnapshot(bookmark, post, canUpgrade: current);
      }
    },
    canUseResolved: (post, config) async {
      final blacklist = await ref.read(
        blacklistTagsProvider(config.filter).future,
      );
      // The detail HTML has no verified rating/status. Do not borrow those
      // facts from the listing when a current policy requires them.
      final filter = config.search.filter;
      if (post.isRealbooru &&
          ((post.rating == Rating.unknown &&
                  filter.ratingFilter != BooruConfigRatingFilter.none) ||
              (post.status == null &&
                  (filter.deletedItemBehavior.isHidden ||
                      filter.bannedPostVisibility.isHidden))))
        return false;
      return isExactLookupPostVisible(post, config, blacklist);
    },
    fetchPost: fetchPost,
    fetchListedPost: (config, id) => fetchPost(config, id, share: true),
    codecFor: (post) => ref
        .read(booruEngineRegistryProvider)
        .getPostCapability(post.origin.booruType)
        ?.codecFor(post.origin, post.booruData),
  );
});

final bookmarkHydrationProvider =
    NotifierProvider<BookmarkHydrationNotifier, BookmarkHydrationProgress>(
      BookmarkHydrationNotifier.new,
    );

class BookmarkHydrationNotifier extends Notifier<BookmarkHydrationProgress> {
  BookmarkHydrationCancellation? _cancellation;

  @override
  BookmarkHydrationProgress build() => const BookmarkHydrationProgress();

  void cancel() => _cancellation?.cancel();

  Future<void> start() async {
    if (_cancellation != null) return;
    final cancellation = BookmarkHydrationCancellation();
    _cancellation = cancellation;
    state = const BookmarkHydrationProgress(running: true);
    try {
      await runWithApiRequestContext(
        ApiRequestContext(
          requestClass: ApiRequestClass.bulkTransfer,
          allowCooldownRetry: false,
          canStart: () => !cancellation.cancelled,
        ),
        () async {
          await ref
              .read(bookmarkProvider.notifier)
              .hydrateBookmarks(
                configs: ref.read(bookmarkReadProfilesProvider),
                recovery: ref.read(bookmarkRecoveryServiceProvider),
                cancellation: cancellation,
                onProgress: (progress) => state = progress,
              );
        },
      );
    } catch (_) {
      state = BookmarkHydrationProgress(
        total: state.total,
        updated: state.updated,
        skipped: state.skipped,
        failed: state.failed,
        cancelled: cancellation.cancelled,
        rateLimitedSites: state.rateLimitedSites,
        logEntries: state.logEntries,
        retryPass: state.retryPass,
      );
      rethrow;
    } finally {
      _cancellation = null;
    }
  }
}
