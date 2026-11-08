import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/content_access.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/content_media_access.dart';
import '../../../images/providers.dart';

/// Bound failed reads per source generation, shared by visible lazy cards.
/// Cached, currently authorized renditions can still render during backoff.
final bookmarkCoverFailuresProvider =
    NotifierProvider<BookmarkCoverFailures, Map<ContentAccessKey, Set<int>>>(
      BookmarkCoverFailures.new,
    );

class BookmarkCoverFailures extends Notifier<Map<ContentAccessKey, Set<int>>> {
  @override
  Map<ContentAccessKey, Set<int>> build() => const {};
  void record(ContentAccessKey key, int id) {
    if (ref.read(contentAccessContextProvider(key)) == null ||
        (state[key]?.contains(id) ?? false))
      return;
    final next = Map.of(state);
    if (next.length >= 32 && !next.containsKey(key))
      next.remove(next.keys.first);
    next[key] = {...?next[key], id}.take(12).toSet();
    state = Map.unmodifiable(next);
  }

  void retry(ContentAccessKey key) {
    if (state.containsKey(key)) state = Map.of(state)..remove(key);
  }
}

final bookmarkCoverCachedProvider = FutureProvider.autoDispose
    .family<bool, ({ContentAccessKey access, String url})>(
      (ref, request) async {
        final manager = ref.watch(
          contentMediaCacheManagerProvider((
            manager: ref.watch(defaultImageCacheManagerProvider),
            access: request.access,
          )),
        );
        final key = manager.generateCacheKey(request.url);
        return manager.hasValidCache(key);
      },
      dependencies: [
        contentMediaCacheManagerProvider,
        defaultImageCacheManagerProvider,
      ],
    );
