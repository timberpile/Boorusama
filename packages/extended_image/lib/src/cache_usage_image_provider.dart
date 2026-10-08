import 'dart:async';

import 'package:cache_manager/cache_manager.dart';
import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Records actual resolution before an inner resize/custom decoded cache can
/// satisfy it. Keys/status/eviction remain delegated pure operations.
class CacheUsageImageProvider extends ImageProvider<Object>
    with ExtendedImageProvider<Object> {
  const CacheUsageImageProvider(this.inner, this.manager, this.logicalKey);
  final ImageProvider<Object> inner;
  final ManagedImageCacheManager manager;
  final String logicalKey;

  static ImageProvider<Object> wrap(
    ImageProvider<Object> inner, {
    required ImageCacheManager? manager,
    required String url,
    String? customKey,
  }) => manager is ManagedImageCacheManager
      ? CacheUsageImageProvider(
          inner,
          manager,
          manager.generateCacheKey(url, customKey: customKey),
        )
      : inner;

  ExtendedImageProvider? get _extended =>
      inner is ExtendedImageProvider ? inner as ExtendedImageProvider : null;
  @override
  bool get cacheRawData => _extended?.cacheRawData ?? false;
  @override
  String? get imageCacheName => _extended?.imageCacheName;
  @override
  ImageCache get imageCache =>
      _extended?.imageCache ?? PaintingBinding.instance.imageCache;
  @override
  Uint8List get rawImageData => _extended!.rawImageData;
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      inner.obtainKey(configuration);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    Object key,
    ImageErrorListener handleError,
  ) {
    // Enqueue use before disk policy, but retain synchronous decoded handoff.
    // Bookkeeping failure cannot become a failed image representation.
    unawaited(
      manager.touch(logicalKey).catchError((Object error, StackTrace stack) {
        if (kDebugMode) debugPrint('[ImageCache] Usage could not be recorded.');
      }),
    );
    inner.resolveStreamForKey(configuration, stream, key, handleError);
  }

  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) =>
      inner.loadImage(key, decode);
  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
    bool includeLive = true,
  }) =>
      _extended?.evict(
        cache: cache,
        configuration: configuration,
        includeLive: includeLive,
      ) ??
      inner.evict(cache: cache, configuration: configuration);
  @override
  Future<ImageCacheStatus?> obtainCacheStatus({
    required ImageConfiguration configuration,
    ImageErrorListener? handleError,
  }) => inner.obtainCacheStatus(
    configuration: configuration,
    handleError: handleError,
  );
  @override
  bool operator ==(Object other) =>
      other is CacheUsageImageProvider &&
      inner == other.inner &&
      identical(manager.cacheDomain, other.manager.cacheDomain) &&
      logicalKey == other.logicalKey;
  @override
  int get hashCode => Object.hash(inner, manager.cacheDomain, logicalKey);
}
