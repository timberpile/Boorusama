import 'dart:async';

import 'package:booru_clients/pixiv.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../types/lookup_result.dart';

final class PixivOriginalHashes {
  const PixivOriginalHashes(this.hashes, {this.issue});
  final List<String> hashes;
  final PixivLookupCoverageIssue? issue;
}

/// Carries an access decision without retaining restricted artwork metadata.
final class PixivOriginalAccessDenied implements Exception {
  const PixivOriginalAccessDenied();
}

/// Application-wide bound; each artwork also processes its pages serially.
final class PixivHashDownloadQueue {
  PixivHashDownloadQueue({this.concurrency = 2})
    : assert(concurrency > 0, 'Download concurrency must be positive');
  final int concurrency;
  var _running = 0;
  final _waiting = <_HashTicket>[];

  Future<String> run(
    Future<String> Function() action,
    CancelToken token,
  ) async {
    if (_running >= concurrency) {
      final ticket = _HashTicket();
      _waiting.add(ticket);
      unawaited(
        token.whenCancel.then((error) {
          if (!ticket.granted && _waiting.remove(ticket)) {
            ticket.ready.completeError(error);
          }
        }),
      );
      await ticket.ready.future;
    } else {
      _running++;
    }
    try {
      if (token.isCancelled) throw token.cancelError!;
      return await action();
    } finally {
      if (_waiting.isEmpty) {
        _running--;
      } else {
        final next = _waiting.removeAt(0)..granted = true;
        next.ready.complete();
      }
    }
  }
}

final class _HashTicket {
  final ready = Completer<void>();
  var granted = false;
}

final class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// This client must be separate from authenticated Pixiv API clients. It follows
/// no redirects and stores no media; only the digest survives the streamed read.
final class PixivOriginalMediaHasher {
  const PixivOriginalMediaHasher({required this.dio, required this.queue});
  final Dio dio;
  final PixivHashDownloadQueue queue;

  Future<String> hash(
    Uri uri,
    int maxBytes,
    void Function(int) consumeBytes,
    CancelToken session,
  ) => queue.run(() async {
    final token = CancelToken();
    unawaited(session.whenCancel.then((_) => token.cancel()));
    // Large permitted originals need time on mobile connections, within the
    // resolver's separate 90-second artwork budget.
    final timer = Timer(const Duration(seconds: 60), () => token.cancel());
    try {
      if (session.isCancelled) throw session.cancelError!;
      final response = await dio.getUri<ResponseBody>(
        uri,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) => status == 200,
          headers: const {'Referer': 'https://www.pixiv.net/'},
        ),
      );
      final contentType = response.headers
          .value('content-type')
          ?.split(';')
          .first;
      if (!const {
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
      }.contains(contentType)) {
        throw const FormatException('Original is not a supported image');
      }
      final length = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (length != null && (length < 1 || length > maxBytes)) {
        throw const FormatException('Original exceeds the transfer limit');
      }
      final body = response.data;
      if (body == null) throw const FormatException('Missing original body');
      final sink = _DigestSink();
      final digest = md5.startChunkedConversion(sink);
      var bytes = 0;
      try {
        await for (final chunk in body.stream) {
          if (session.isCancelled) throw session.cancelError!;
          bytes += chunk.length;
          consumeBytes(chunk.length);
          if (bytes > maxBytes) {
            throw const FormatException('Original exceeds the transfer limit');
          }
          digest.add(chunk);
        }
      } finally {
        digest.close();
      }
      if (bytes == 0 || (length != null && length != bytes)) {
        throw const FormatException('Incomplete original body');
      }
      return sink.value!.toString();
    } finally {
      timer.cancel();
      token.cancel();
    }
  }, session);
}

typedef PixivOriginalHasher = Future<String> Function(
  Uri uri,
  int maxBytes,
  void Function(int) consumeBytes,
  CancelToken cancellation,
);

/// One on-demand resolution is shared by every target in a results session.
/// The limits also bound work for exceptionally large/many-page artworks.
final class PixivOriginalHashResolver {
  PixivOriginalHashResolver({
    required this.artworkId,
    required this.hashOriginal,
    this.loadArtwork,
    this.isSourceCurrent,
    this.maxPages = 20,
    this.maxFileBytes = 32 * 1024 * 1024,
    this.maxTotalBytes = 128 * 1024 * 1024,
  });

  final String artworkId;
  final Future<PixivIllustDto?> Function()? loadArtwork;
  final PixivOriginalHasher hashOriginal;
  final bool Function()? isSourceCurrent;
  final int maxPages;
  final int maxFileBytes;
  final int maxTotalBytes;
  final _cancellation = CancelToken();
  Future<PixivOriginalHashes>? _pending;

  Future<PixivOriginalHashes> resolve() async {
    if (_cancellation.isCancelled || isSourceCurrent?.call() == false) {
      return const PixivOriginalHashes(
        [],
        issue: PixivLookupCoverageIssue.originalsUnavailable,
      );
    }
    final result = await (_pending ??= _resolve().timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        dispose();
        return const PixivOriginalHashes(
          [],
          issue: PixivLookupCoverageIssue.originalsUnavailable,
        );
      },
    ));
    return _cancellation.isCancelled || isSourceCurrent?.call() == false
        ? const PixivOriginalHashes(
            [],
            issue: PixivLookupCoverageIssue.originalsUnavailable,
          )
        : result;
  }

  void dispose() => _cancellation.cancel();

  Future<PixivOriginalHashes> _resolve() async {
    final loader = loadArtwork;
    if (loader == null) {
      return const PixivOriginalHashes(
        [],
        issue: PixivLookupCoverageIssue.authentication,
      );
    }
    final hashes = <String>{};
    PixivLookupCoverageIssue? issue;
    final timer = Timer(const Duration(seconds: 90), dispose);
    try {
      final dto = await loader().timeout(const Duration(seconds: 10));
      if (dto == null ||
          dto.id.toString() != artworkId ||
          isSourceCurrent?.call() == false) {
        throw const FormatException('Artwork is unavailable');
      }
      if (dto.visible == false || (dto.isMuted ?? false)) {
        throw const PixivOriginalAccessDenied();
      }
      if (dto.type == 'ugoira') {
        return const PixivOriginalHashes(
          [],
          issue: PixivLookupCoverageIssue.ugoira,
        );
      }
      if (dto.type != 'illust' && dto.type != 'manga') {
        throw const FormatException('Unsupported artwork type');
      }
      final count = dto.pageCount;
      if (count == null || count < 1) {
        throw const FormatException('Missing pages');
      }
      if (count > maxPages) {
        issue = PixivLookupCoverageIssue.originalsUnavailable;
      }
      var totalBytes = 0;
      for (var page = 0; page < count && page < maxPages; page++) {
        if (_cancellation.isCancelled || isSourceCurrent?.call() == false) {
          throw const FormatException('Artwork source is no longer available');
        }
        final url = count == 1
            ? dto.metaSinglePage?.originalImageUrl
            : page < dto.metaPages.length
            ? dto.metaPages[page].imageUrls?.original
            : null;
        final uri = safeOriginalUri(url, artworkId, page);
        if (uri == null || totalBytes >= maxTotalBytes) {
          issue = PixivLookupCoverageIssue.originalsUnavailable;
          continue;
        }
        try {
          final remaining = maxTotalBytes - totalBytes;
          final hash = await hashOriginal(
            uri,
            remaining < maxFileBytes ? remaining : maxFileBytes,
            (bytes) => totalBytes += bytes,
            _cancellation,
          );
          if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(hash)) {
            throw const FormatException('Invalid digest');
          }
          hashes.add(hash);
        } catch (_) {
          issue = PixivLookupCoverageIssue.originalsUnavailable;
        }
      }
    } catch (error) {
      issue = switch (error) {
        PixivOriginalAccessDenied() => PixivLookupCoverageIssue.restricted,
        DioException(response: final response?)
            when response.statusCode == 401 =>
          PixivLookupCoverageIssue.authentication,
        _ => PixivLookupCoverageIssue.originalsUnavailable,
      };
    } finally {
      timer.cancel();
    }
    return PixivOriginalHashes(List.unmodifiable(hashes), issue: issue);
  }

  static Uri? safeOriginalUri(String? value, String id, int page) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'pximg.net' || uri.host.endsWith('.pximg.net')) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith('/img-original/') ||
        !RegExp('/${id}_p$page\\.(?:jpg|jpeg|png|gif|webp)\$')
            .hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }
}
