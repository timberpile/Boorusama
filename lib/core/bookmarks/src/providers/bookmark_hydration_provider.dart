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
  return BookmarkRecoveryService(
    fetchPost: (config, id) async {
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
      final cancellation = CancelToken();
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
            canStart: current,
            canAdmit: current,
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
    },
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
