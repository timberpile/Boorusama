import 'dart:typed_data';

import 'package:booru_clients/nhentai.dart';
import 'package:dio/dio.dart';

import '../http/client/coordination.dart';
import '../http/client/src/data/public_read_http_adapter.dart';
import 'anonymous_source_policy.dart';

/// Shares validated config between model mapping and the final media boundary.
final class NhentaiPublicTransport implements HttpClientAdapter {
  NhentaiPublicTransport({
    required Dio dio,
    required AnonymousSource source,
    required bool Function() current,
  }) : _client = NhentaiClient(dio: dio),
       _current = current,
       _source = source {
    dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20);
    _guard = PublicReadHttpClientAdapter(
      delegate: dio.httpClientAdapter,
      source: source,
      current: current,
      validateMedia: _allowsMedia,
    );
  }

  static NhentaiPublicTransport of(Dio dio) => switch (dio.httpClientAdapter) {
    final NhentaiPublicTransport transport => transport,
    CoordinatedHttpClientAdapter(
      delegate: final NhentaiPublicTransport transport,
    ) =>
      transport,
    _ => throw StateError('Gallery transport unavailable'),
  };

  final NhentaiClient _client;
  final AnonymousSource _source;
  final bool Function() _current;
  final _lifetime = CancelToken();
  late final PublicReadHttpClientAdapter _guard;
  Future<NhentaiMediaPolicy>? _config;

  Future<NhentaiMediaPolicy> mediaPolicy() {
    if (_lifetime.isCancelled || !_current()) {
      return Future.error(StateError('Gallery transport unavailable'));
    }
    final existing = _config;
    if (existing != null) return existing;

    late final Future<NhentaiMediaPolicy> pending;
    pending =
        runWithApiRequestContext(
          ApiRequestContext(
            cancelToken: _lifetime,
            replaySafety: ApiReplaySafety.safeRead,
            canStart: _current,
            canAdmit: _current,
            allowCooldownRetry: false,
          ),
          () => _client.getMediaPolicy(cancelToken: _lifetime),
        ).onError<Object>((error, stack) {
          if (identical(_config, pending)) _config = null;
          Error.throwWithStackTrace(error, stack);
        });
    return _config = pending;
  }

  void invalidateMediaPolicy() => _config = null;

  Future<bool> _allowsMedia(Uri uri) async {
    final segments = uri.pathSegments;
    if (segments.length != 3) return false;
    final pending = mediaPolicy();
    final policy = await pending;
    return identical(_config, pending) &&
        policy.allows(
          uri,
          mediaId: segments[1],
          thumbnail: uri.host.startsWith('t'),
        );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.extra[apiMediaRequestKey] == true &&
        !_source.allowsMedia(options.uri)) {
      return Future.error(
        DioException(
          requestOptions: options,
          message: 'Invalid Gallery media destination',
        ),
      );
    }
    return _guard.fetch(
      options.copyWith(followRedirects: false),
      requestStream,
      cancelFuture,
    );
  }

  @override
  void close({bool force = false}) {
    _lifetime.cancel('Gallery transport disposed');
    _guard.close(force: force);
  }
}
