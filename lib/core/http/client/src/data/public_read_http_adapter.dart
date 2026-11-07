import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../content/anonymous_source_policy.dart';
import '../coordination/coordinated_dio.dart';

/// Restricts the existing transport, including redirects performed below Dio's
/// interceptors. It does not create another request queue or HTTP client.
final class PublicReadHttpClientAdapter implements HttpClientAdapter {
  PublicReadHttpClientAdapter({
    required this.delegate,
    required this.source,
    required this.current,
  });

  final HttpClientAdapter delegate;
  final AnonymousSource source;
  final bool Function() current;
  var _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var request = options;
    var redirects = 0;
    while (true) {
      _requireCurrent(options);
      final method = request.method.toUpperCase();
      final uri = request.uri;
      if (!const ['GET', 'HEAD'].contains(method) ||
          !isApiSafeRead(request) ||
          request.data != null ||
          requestStream != null ||
          (!source.allowsApi(uri) && !source.allowsMedia(uri)) ||
          request.headers.entries.any(_unsafeHeader)) {
        throw DioException(
          requestOptions: options,
          message: 'Request is outside the public read policy',
        );
      }
      // Native/IO automatic redirect following must never bypass this guard.
      final body = await delegate.fetch(
        request.copyWith(followRedirects: false),
        null,
        cancelFuture,
      );
      if (!_isCurrent) {
        await body.stream.listen(null).cancel();
        throw _cancelled(options);
      }
      final redirect = const [
        301,
        302,
        303,
        307,
        308,
      ].contains(body.statusCode);
      final locations = [
        for (final entry in body.headers.entries)
          if (entry.key.toLowerCase() == 'location') ...entry.value,
      ];
      if (!redirect || !options.followRedirects || locations.isEmpty) {
        // An adapter can finish its headers before cancellation. Late bytes are
        // still rejected, including responses buffered by a transport boundary.
        body.stream = body.stream.map((chunk) {
          _requireCurrent(options);
          return chunk;
        });
        return body;
      }
      await body.stream.listen(null).cancel();
      if (locations.length != 1 || redirects++ >= options.maxRedirects) {
        throw DioException(
          requestOptions: options,
          message: 'Invalid public read redirect',
        );
      }
      final target = uri.resolve(locations.single);
      // The next loop validates the effective URI before any further transport.
      request = request.copyWith(
        path: target.toString(),
        baseUrl: '',
        queryParameters: const {},
      );
    }
  }

  bool get _isCurrent => !_closed && current();

  bool _unsafeHeader(MapEntry<String, dynamic> entry) {
    final name = entry.key.toLowerCase();
    if (!const {
      'accept',
      'accept-encoding',
      'accept-language',
      'user-agent',
      'content-type',
      'range',
      'if-range',
      'if-none-match',
      'if-modified-since',
      'referer',
    }.contains(name)) {
      return true;
    }
    if (name != 'referer') return false;
    final value = entry.value;
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri == null ||
        uri.scheme != 'https' ||
        uri.host != source.site.host ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !const ['', '/'].contains(uri.path);
  }

  void _requireCurrent(RequestOptions options) {
    if (!_isCurrent) throw _cancelled(options);
  }

  DioException _cancelled(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.cancel,
    message: 'Public read scope is no longer active',
  );

  @override
  void close({bool force = false}) {
    if (_closed) return;
    _closed = true;
    delegate.close(force: force);
  }
}
