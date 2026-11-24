import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/configs/config/types.dart';
import '../../../core/content/content_access.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_dio.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/images/providers.dart';
import '../../../core/settings/providers.dart';
import '../../../foundation/utils/file_utils.dart';
import '../client_provider.dart';
import '../configs/extra_data.dart';
import 'ugoira_archive.dart';
import 'ugoira_frames.dart';

typedef PixivUgoiraLoader = Future<PreparedPixivUgoira> Function(
  int illustId,
  CancelToken cancelToken,
  ValueChanged<double?> onDownloadProgress,
);

final pixivUgoiraLoaderProvider = Provider.autoDispose
    .family<PixivUgoiraLoader?, ContentAccessKey>(
      (ref, key) {
        final source = ref.watch(pixivUgoiraSourceProvider(key));
        if (source == null) return null;
        return (id, token, onDownloadProgress) => source.prepare(
          id,
          token,
          (animation) => PreparedPixivUgoira.prepare(animation, token),
          onDownloadProgress: onDownloadProgress,
        );
      },
      dependencies: [pixivUgoiraSourceProvider],
    );

final pixivUgoiraSourceProvider = Provider.autoDispose
    .family<PixivUgoiraSource?, ContentAccessKey>(
      (ref, key) {
        final access = ref.watch(contentAccessContextProvider(key));
        final auth = access?.config?.auth;
        final profile = key.profileId;
        if (auth == null || profile == null) return null;
        final account = PixivExtraData.fromPassHash(auth.passHash).userId;
        final cacheSize = ref.watch(
          settingsProvider.select((s) => s.imageCacheMaxSize),
        );
        final cache = account == null || account.isEmpty || cacheSize.isZero
            ? null
            : ref.watch(defaultImageCacheManagerProvider);
        return PixivUgoiraSource(
          client: ref.watch(pixivClientProvider(auth)),
          media: ref.watch(contentMediaDioProvider(key)),
          cache: cache,
          cacheScope: jsonEncode([key.siteNamespace, profile, account]),
          maxCacheBytes: cacheSize.bytes,
        );
      },
      dependencies: [
        contentAccessContextProvider,
        contentMediaDioProvider,
        settingsProvider,
        defaultImageCacheManagerProvider,
      ],
    );

class PixivUgoiraSource {
  const PixivUgoiraSource({
    required this.client,
    required this.media,
    this.cache,
    this.cacheScope,
    this.maxCacheBytes = pixivUgoiraArchiveByteLimit,
  });

  final PixivClient client;
  final Dio media;
  final ImageCacheManager? cache;
  final String? cacheScope;
  final int maxCacheBytes;

  String? _cacheKey(int illustId) {
    final scope = cacheScope;
    return scope == null
        ? null
        : cache?.generateCacheKey('pixiv-ugoira-v1:$scope:$illustId');
  }

  Future<void> evict(int illustId) async {
    if (_cacheKey(illustId) case final key?) await cache?.clearCache(key);
  }

  Future<PixivUgoiraAnimation> load(int illustId, CancelToken token) =>
      prepare(illustId, token, (animation) => animation);

  Future<T> prepare<T>(
    int illustId,
    CancelToken token,
    FutureOr<T> Function(PixivUgoiraAnimation animation) openingFrames, {
    ValueChanged<double?>? onDownloadProgress,
  }) async {
    _checkCancellation(token);
    final manager = cache;
    final key = _cacheKey(illustId);
    final generation = imageCacheClearGeneration.value;
    if (manager != null && key != null) {
      try {
        final bytes = await manager.getCachedFileBytes(key);
        _checkCancellation(token);
        if (bytes != null) {
          final animation = await compute(
            (bytes) => decodePixivUgoiraArchive(_readCacheRecord(bytes)),
            bytes,
          );
          _checkCancellation(token);
          return await openingFrames(animation);
        }
      } catch (_) {
        _checkCancellation(token);
        try {
          await manager.clearCache(key);
        } catch (_) {
          // Cache access failures fall through to the authorized transport.
        }
      }
    }

    final data = await _download(illustId, token, onDownloadProgress);
    final animation = await compute(decodePixivUgoiraArchive, data);
    _checkCancellation(token);
    final prepared = await openingFrames(animation);
    if (!token.isCancelled && manager != null && key != null) {
      unawaited(_save(manager, key, data, generation));
    }
    return prepared;
  }

  Future<void> _save(
    ImageCacheManager manager,
    String key,
    PixivUgoiraArchiveData data,
    int generation,
  ) async {
    if (generation != imageCacheClearGeneration.value ||
        data.zip.length > maxCacheBytes) {
      return;
    }
    try {
      final bytes = await compute(_writeCacheRecord, data);
      if (bytes.length > maxCacheBytes ||
          generation != imageCacheClearGeneration.value) {
        return;
      }
      if (manager is ManagedImageCacheManager) {
        final write = await manager.beginFileWrite(key);
        try {
          if (generation == imageCacheClearGeneration.value) {
            await write.saveBytes(bytes);
          }
        } finally {
          await write.abort();
        }
      } else if (generation == imageCacheClearGeneration.value) {
        await manager.saveFile(key, bytes);
      }
    } catch (_) {
      // Cache writes are optional for playback.
    }
  }

  Future<PixivUgoiraArchiveData> _download(
    int illustId,
    CancelToken token,
    ValueChanged<double?>? onDownloadProgress,
  ) async {
    _checkCancellation(token);
    final metadata = await client.getUgoiraMetadata(
      illustId: illustId,
      cancelToken: token,
    );
    _checkCancellation(token);
    final zip = Uri.tryParse(metadata?.zipUrlMedium ?? '');
    if (metadata == null ||
        metadata.frames.isEmpty ||
        zip == null ||
        zip.scheme != 'https' ||
        zip.port != 443 ||
        zip.userInfo.isNotEmpty ||
        !const ['i.pximg.net', 's.pximg.net'].contains(zip.host)) {
      throw const FormatException('Ugoira archive is unavailable');
    }

    final response = await media.get<ResponseBody>(
      zip.toString(),
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: const {'Referer': kPixivImageReferer},
        extra: const {apiMediaRequestKey: true},
      ),
    );
    final body = response.data;
    if (body == null) throw const FormatException('Missing Ugoira archive');
    final advertisedLength = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    final encoding = response.headers[Headers.contentEncodingHeader]?.join(',');
    // A transport may decompress the stream while keeping the wire length.
    final total =
        advertisedLength != null &&
            advertisedLength > 0 &&
            advertisedLength <= pixivUgoiraArchiveByteLimit &&
            (encoding == null || encoding.trim().toLowerCase() == 'identity')
        ? advertisedLength
        : null;
    final archive = BytesBuilder(copy: false);
    try {
      if (total != null) onDownloadProgress?.call(0);
      await for (final chunk in body.stream) {
        _checkCancellation(token);
        if ((advertisedLength ?? 0) > pixivUgoiraArchiveByteLimit ||
            chunk.length > pixivUgoiraArchiveByteLimit - archive.length) {
          throw const FormatException('Ugoira archive exceeds its size limit');
        }
        archive.add(chunk);
        if (total != null) {
          onDownloadProgress?.call(
            archive.length <= total ? archive.length / total : null,
          );
        }
      }
    } finally {
      if (total != null) onDownloadProgress?.call(null);
    }
    _checkCancellation(token);
    return (zip: archive.takeBytes(), frames: metadata.frames);
  }
}

const _maxCacheHeaderBytes = 64 * 1024;
const _cachePrefixSize = 4;

Uint8List _writeCacheRecord(PixivUgoiraArchiveData data) {
  final header = utf8.encode(
    jsonEncode([
      for (final frame in data.frames)
        {'file': frame.file, 'delay': frame.delay},
    ]),
  );
  if (header.length > _maxCacheHeaderBytes) {
    throw const FormatException('Ugoira cache header exceeds its size limit');
  }
  return (BytesBuilder(copy: false)
        ..add(
          (ByteData(
            _cachePrefixSize,
          )..setUint32(0, header.length)).buffer.asUint8List(),
        )
        ..add(header)
        ..add(data.zip))
      .takeBytes();
}

PixivUgoiraArchiveData _readCacheRecord(Uint8List bytes) {
  if (bytes.length < _cachePrefixSize + 1 ||
      bytes.length >
          _cachePrefixSize +
              _maxCacheHeaderBytes +
              pixivUgoiraArchiveByteLimit) {
    throw const FormatException('Invalid Ugoira cache record');
  }
  final headerLength = ByteData.sublistView(
    bytes,
    0,
    _cachePrefixSize,
  ).getUint32(0);
  final zipStart = _cachePrefixSize + headerLength;
  if (headerLength > _maxCacheHeaderBytes || zipStart >= bytes.length) {
    throw const FormatException('Invalid Ugoira cache header');
  }
  final frames = jsonDecode(
    utf8.decode(Uint8List.sublistView(bytes, _cachePrefixSize, zipStart)),
  ) as List<dynamic>;
  return (
    zip: Uint8List.sublistView(bytes, zipStart),
    frames: [
      for (final frame in frames)
        PixivUgoiraFrame.fromJson(frame as Map<String, dynamic>),
    ],
  );
}

void _checkCancellation(CancelToken token) {
  if (token.cancelError case final error?) throw error;
}
