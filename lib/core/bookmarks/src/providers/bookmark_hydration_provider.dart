import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../boorus/engine/providers.dart';
import '../../../configs/manage/providers.dart';
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
      final result = await ref
          .read(originAwarePostRepoProvider(config))
          .getPost(NumericPostId(id))
          .run();
      return result.fold((error) => throw error, (post) => post);
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
                configs: ref.read(booruConfigProvider),
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
