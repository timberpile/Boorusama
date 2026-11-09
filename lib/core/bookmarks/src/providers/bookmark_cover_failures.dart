import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../foundation/loggers.dart';
import '../../../images/media_diagnostics.dart';

import '../../../content/content_access.dart';
import '../../../content/content_access_provider.dart';
import '../../../content/content_media_access.dart';
import '../../../images/providers.dart';
import '../../../configs/network/providers.dart';
import '../../../http/client/providers.dart';
import '../../../configs/config/types.dart';

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
    if ((state[key]?.length ?? 0) < 12) {
      try {
        ref
            .read(loggerProvider)
            .warn(
              'Media',
              'stage=resolution; engine=${key.engine.name}; rendition=cover; outcome=metadata_unavailable',
            );
      } catch (_) {}
    }
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
        final config = ref
            .watch(contentAccessContextProvider(request.access))
            ?.config;
        if (config == null) return false;
        final media = ref
            .watch(networkSettingsProvider(config.auth))
            .resolveMedia(
              request.url,
              headers: ref.watch(httpHeadersProvider(config.auth)),
              sourceUrl: config.url,
            );
        final manager = ref.watch(
          contentMediaCacheManagerProvider((
            manager: ref.watch(defaultImageCacheManagerProvider),
            access: request.access,
          )),
        );
        final key = manager.generateCacheKey(media.url);
        final cached = await manager.hasValidCache(key);
        try {
          ref
              .read(mediaDiagnosticsProvider(config.auth))
              ?.event(
                url: media.url,
                stage: 'cache',
                outcome: cached ? 'cover_cache_hit' : 'cover_cache_miss',
              );
        } catch (_) {
          // The cover may have left the viewport while the cache read completed.
        }
        return cached;
      },
      dependencies: [
        contentMediaCacheManagerProvider,
        defaultImageCacheManagerProvider,
        contentAccessContextProvider,
        networkSettingsProvider,
        httpHeadersProvider,
        mediaDiagnosticsProvider,
      ],
    );

/// A small cover may reuse an already cached sample, without downloading the
/// original or crawling the source when its preferred thumbnail is absent.
final bookmarkCoverCachedRenditionProvider = FutureProvider.autoDispose
    .family<
      String?,
      ({ContentAccessKey access, String primary, String sample})
    >((ref, request) async {
      for (final url in {request.primary, request.sample}) {
        if (url.isEmpty) continue;
        if (await ref.watch(
          bookmarkCoverCachedProvider((access: request.access, url: url))
              .future,
        ))
          return url;
      }
      return null;
    }, dependencies: [bookmarkCoverCachedProvider]);
