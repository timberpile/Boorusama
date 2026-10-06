import 'dart:async';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_libavif/flutter_libavif.dart';
import 'package:retriable/retriable.dart';

@immutable
class CustomCachedNetworkAvifImageProvider
    extends AvifImageProvider<CustomCachedNetworkAvifImageProvider> {
  CustomCachedNetworkAvifImageProvider(
    this.url, {
    super.scale = 1.0,
    Map<String, String>? headers,
    required this.dio,
    this.cancelToken,
    this.fetchStrategy,
    this.cacheKey,
    this.cacheMaxAge,
    ImageCacheManager? cacheManager,
    super.cacheWidth,
    super.cacheHeight,
    super.options,
  }) : headers = Map.unmodifiable(headers ?? const <String, String>{}),
       cacheManager = cacheManager ?? DefaultImageCacheManager();

  final String url;
  final Map<String, String> headers;
  final ImageCacheManager cacheManager;
  final Dio dio;
  final CancelToken? cancelToken;
  final FetchStrategyBuilder? fetchStrategy;
  final String? cacheKey;
  final Duration? cacheMaxAge;

  @override
  Future<CustomCachedNetworkAvifImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture<CustomCachedNetworkAvifImageProvider>(this);

  @override
  AvifImageSource loadAvifSource(CustomCachedNetworkAvifImageProvider key) {
    assert(key == this);

    final chunkEvents = StreamController<ImageChunkEvent>();
    final requestCancelToken = cancelToken ?? CancelToken();

    return AvifImageSource(
      bytes: _loadBytes(chunkEvents, requestCancelToken),
      chunkEvents: chunkEvents.stream,
      cancel: () {
        if (!requestCancelToken.isCancelled) {
          requestCancelToken.cancel('AVIF image source disposed.');
        }
        if (!chunkEvents.isClosed) {
          unawaited(chunkEvents.close());
        }
      },
    );
  }

  Future<Uint8List> _loadBytes(
    StreamController<ImageChunkEvent> chunkEvents,
    CancelToken requestCancelToken,
  ) async {
    final cacheKey = cacheManager.generateCacheKey(
      url,
      customKey: this.cacheKey,
    );

    try {
      final cachedBytes = await cacheManager.getCachedFileBytes(
        cacheKey,
        maxAge: cacheMaxAge,
      );
      if (cachedBytes != null) {
        return cachedBytes;
      }

      final resolved = Uri.base.resolve(url);
      final response = await tryGetResponse<List<int>>(
        resolved,
        dio: dio,
        cancelToken: requestCancelToken,
        fetchStrategy: fetchStrategy,
        options: Options(
          responseType: ResponseType.bytes,
          extra: const {'boorusama.request.media': true},
          headers: headers,
        ),
        onReceiveProgress: (count, total) {
          if (!chunkEvents.isClosed && total >= 0) {
            chunkEvents.add(
              ImageChunkEvent(
                cumulativeBytesLoaded: count,
                expectedTotalBytes: total,
              ),
            );
          }
        },
      );

      if (response == null || response.data == null) {
        throw StateError('Failed to load $url: Empty response');
      }

      final bytes = Uint8List.fromList(response.data!);
      if (bytes.isEmpty) {
        throw StateError('$url is empty and cannot be decoded.');
      }

      await cacheManager.saveFile(cacheKey, bytes);
      return bytes;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw StateError('User canceled request $url.');
      }
      throw StateError('Failed to load $url: $error');
    } finally {
      if (!chunkEvents.isClosed) {
        unawaited(chunkEvents.close());
      }
    }
  }

  @override
  String describeAvifSource(CustomCachedNetworkAvifImageProvider key) =>
      key.url;

  @override
  bool operator ==(Object other) =>
      other is CustomCachedNetworkAvifImageProvider &&
      other.url == url &&
      other.scale == scale &&
      mapEquals(other.headers, headers) &&
      other.cacheWidth == cacheWidth &&
      other.cacheHeight == cacheHeight &&
      other.options == options &&
      other.cacheKey == cacheKey &&
      other.cancelToken == cancelToken;

  @override
  int get hashCode => Object.hash(
    url,
    scale,
    Object.hashAllUnordered(
      headers.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
    cacheWidth,
    cacheHeight,
    options,
    cacheKey,
    cancelToken,
  );

  @override
  String toString() =>
      'CustomCachedNetworkAvifImageProvider($url, scale: $scale)';
}
