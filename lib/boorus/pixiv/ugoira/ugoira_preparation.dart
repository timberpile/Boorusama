import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/content/content_access.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/settings/providers.dart';
import '../../../foundation/utils/file_utils.dart';
import 'ugoira_frames.dart';
import 'ugoira_source.dart';

typedef PixivUgoiraRequest = ({ContentAccessKey access, int illustId});

final pixivUgoiraDownloadProgressProvider = Provider.autoDispose
    .family<ValueNotifier<double?>, PixivUgoiraRequest>(
      (ref, request) {
        final progress = ValueNotifier<double?>(null);
        ref.onDispose(progress.dispose);
        return progress;
      },
      dependencies: [pixivUgoiraLoaderProvider, settingsProvider],
    );

Future<void> retryPixivUgoira(WidgetRef ref, PixivUgoiraRequest request) async {
  ref.read(_pixivUgoiraReadyCacheProvider).removeWhere((key) => key == request);
  try {
    await ref
        .read(pixivUgoiraSourceProvider(request.access))
        ?.evict(request.illustId);
  } catch (_) {
    // Cache failure does not prevent retrying playback.
  }
  if (ref.context.mounted) {
    ref.invalidate(pixivUgoiraPreparationProvider(request));
  }
}

final pixivUgoiraPreparationProvider = FutureProvider.autoDispose
    .family<PreparedPixivUgoira, PixivUgoiraRequest>(
      (ref, request) {
        final loader = ref.watch(pixivUgoiraLoaderProvider(request.access));
        if (loader == null) throw StateError('Ugoira access unavailable');
        final cache = ref.watch(_pixivUgoiraReadyCacheProvider);
        final generation = ref.watch(_imageCacheGenerationProvider);
        final keepReady = ref.watch(
          settingsProvider.select((value) => !value.imageCacheMaxSize.isZero),
        );
        final ready = keepReady ? cache.get(request) : null;
        if (ready != null) {
          ready.retain();
          ref.onDispose(ready.release);
          return ready;
        }

        final progress = ref.watch(
          pixivUgoiraDownloadProgressProvider(request),
        );
        final token = CancelToken();
        ref.onDispose(token.cancel);
        // Reset a replacement request's progress outside the widget build.
        return Future.microtask(() {
          if (token.cancelError case final error?) throw error;
          progress.value = null;
          return loader(request.illustId, token, (value) {
            if (!token.isCancelled) progress.value = value;
          });
        }).then((ready) {
          if (token.isCancelled) {
            ready.release();
            throw token.cancelError!;
          }
          ref.onDispose(ready.release);
          if (keepReady && generation == imageCacheClearGeneration.value) {
            cache.put(request, ready);
          }
          return ready;
        });
      },
      dependencies: [
        pixivUgoiraLoaderProvider,
        pixivUgoiraDownloadProgressProvider,
        _pixivUgoiraReadyCacheProvider,
        _imageCacheGenerationProvider,
        settingsProvider,
      ],
    );

final _imageCacheGenerationProvider = Provider<int>((ref) {
  final generation = imageCacheClearGeneration;
  generation.addListener(ref.invalidateSelf);
  ref.onDispose(() => generation.removeListener(ref.invalidateSelf));
  return generation.value;
});

final _pixivUgoiraReadyCacheProvider = Provider<_ReadyAnimations>((ref) {
  final cache = _ReadyAnimations();
  imageCacheClearGeneration.addListener(cache.clear);
  ref.listen(settingsProvider.select((value) => value.imageCacheMaxSize), (
    _,
    size,
  ) {
    if (size.isZero) cache.clear();
  });
  ref.listen(contentAccessScopesProvider, (_, scopes) {
    cache.removeWhere((request) {
      final scope = scopes[request.access.profileId];
      return scope == null || scope.authEpoch != request.access.authEpoch;
    });
  });
  ref.onDispose(() {
    imageCacheClearGeneration.removeListener(cache.clear);
    cache.clear();
  });
  return cache;
}, dependencies: [settingsProvider, contentAccessScopesProvider]);

/// Owns a separate reference from the provider and the playback surface.
class _ReadyAnimations {
  final _entries = <PixivUgoiraRequest, PreparedPixivUgoira>{};

  PreparedPixivUgoira? get(PixivUgoiraRequest request) {
    final animation = _entries.remove(request);
    if (animation != null) _entries[request] = animation;
    return animation;
  }

  void put(PixivUgoiraRequest request, PreparedPixivUgoira ready) {
    _entries.remove(request)?.release();
    ready.retain();
    _entries[request] = ready;
    while (_entries.length > 3 ||
        _entries.values.fold(0, (bytes, value) => bytes + value.encodedBytes) >
            64 * 1024 * 1024 ||
        _entries.values.fold(0, (bytes, value) => bytes + value.decodedBytes) >
            32 * 1024 * 1024) {
      _entries.remove(_entries.keys.first)!.release();
    }
  }

  void removeWhere(bool Function(PixivUgoiraRequest request) matches) {
    for (final request in _entries.keys.where(matches).toList()) {
      _entries.remove(request)!.release();
    }
  }

  void clear() => removeWhere((_) => true);
}
