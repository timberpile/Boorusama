import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/http/client/coordination.dart';
import '../client_provider.dart';
import 'store.dart';

final nhentaiTagCacheProvider =
    Provider.family<NhentaiTagCache, BooruConfigAuth>(
      (ref, config) {
        final client = ref.watch(nhentaiClientProvider(config));
        final cache = NhentaiTagCache(
          store: ref.watch(nhentaiTagStoreProvider),
          lookup: (ids, token) => client.getTagsByIds(ids, cancelToken: token),
          catalog: (category, sort, page, token) => runWithApiRequestContext(
            ApiRequestContext(
              requestClass: ApiRequestClass.preload,
              replaySafety: ApiReplaySafety.safeRead,
              cancelToken: token,
              allowCooldownRetry: false,
              admissionBehavior: ApiAdmissionBehavior.dropIfUnavailable,
            ),
            () => client.getTagCatalog(
              category,
              sort: sort,
              page: page,
              cancelToken: token,
            ),
          ),
        );
        ref.onDispose(cache.dispose);
        return cache;
      },
    );

/// Foreground initial/continued sweep. User-facing reads remain independent
/// from transient catalog transport and storage failures.
Future<void> warmNhentaiTags(
  NhentaiTagCache cache,
  Set<int> visibleIds,
  CancelToken token, {
  required bool warmCatalog,
}) async {
  try {
    await cache.resolveVisible(visibleIds, cancelToken: token);
    if (warmCatalog && !token.isCancelled) {
      final category = await _nextCatalog(cache);
      if (category != null && !token.isCancelled) {
        await cache.warmCatalog(category, cancelToken: token);
      }
    }
  } catch (_) {
    // The persisted checkpoint is retried on the next foreground visit.
  }
}

Future<String?> _nextCatalog(NhentaiTagCache cache) async {
  NhentaiTagCheckpoint? oldest;
  for (final category in const [
    'language',
    'category',
    'tag',
    'artist',
    'character',
    'parody',
    'group',
  ]) {
    final checkpoint = await cache.store.readCheckpoint(
      NhentaiTagCache.source,
      category,
      'popular',
    );
    if (checkpoint == null) return category;
    if (checkpoint.nextPage != null &&
        (oldest == null || checkpoint.observedAt.isBefore(oldest.observedAt))) {
      oldest = checkpoint;
    }
  }
  return oldest?.category;
}
