import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../http/client/src/coordination/api_request_context.dart';

/// Native players receive only a loopback capability, never the upstream URL or
/// account headers. All upstream reads keep the existing guarded Dio boundary.
/// Streaming obeys socket backpressure and does not retain media on disk.
final class GuardedVideoStream {
  GuardedVideoStream._(
    this._server,
    this._transport,
    this._upstream,
    this._headers,
    this._current,
    this._cancellation,
  ) : _path = '/${const Uuid().v4()}/video';

  final HttpServer _server;
  final Dio _transport;
  final String _upstream;
  final Map<String, String> _headers;
  final bool Function() _current;
  final CancelToken _cancellation;
  final String _path;
  final _requests = <CancelToken, HttpResponse>{};
  final _failures = StreamController<void>();
  var _reportedFailure = false;
  var _closed = false;
  Future<void>? _closing;

  /// One route owns this stream; its first failure is buffered until the native
  /// player's owner has subscribed, including an error during initialization.
  Stream<void> get failures => _failures.stream;

  Uri get uri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
    path: _path,
  );

  static Future<GuardedVideoStream> open({
    required Dio transport,
    required String upstream,
    required Map<String, String> headers,
    required bool Function() isCurrent,
    required CancelToken cancellation,
  }) async {
    if (cancellation.isCancelled || !isCurrent()) {
      throw StateError('Video access revoked');
    }
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      backlog: 8,
      shared: false,
    );
    final stream = GuardedVideoStream._(
      server,
      transport,
      upstream,
      Map.unmodifiable(headers),
      isCurrent,
      cancellation,
    );
    if (!stream._allowed) {
      await stream.close();
      throw StateError('Video access revoked');
    }
    server.autoCompress = false;
    server.idleTimeout = const Duration(seconds: 30);
    server.listen(
      (request) => unawaited(stream._serve(request)),
      onError: (Object _, StackTrace __) {
        stream._reportFailure();
        unawaited(stream.close());
      },
    );
    unawaited(cancellation.whenCancel.then((_) => stream.close()));
    return stream;
  }

  bool get _allowed {
    if (_closed || _cancellation.isCancelled) return false;
    try {
      return _current();
    } catch (_) {
      return false;
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    CancelToken? token;
    try {
      // A request cannot supply a destination, credentials or additional query.
      if (!_allowed ||
          request.connectionInfo?.remoteAddress.isLoopback != true ||
          request.uri.path != _path ||
          request.uri.hasQuery ||
          request.contentLength > 0 ||
          request.headers.value(HttpHeaders.transferEncodingHeader) != null ||
          !const ['GET', 'HEAD'].contains(request.method)) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (_requests.length >= 4) {
        response.statusCode = HttpStatus.serviceUnavailable;
        return;
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null &&
          !RegExp(r'^bytes=(?:[0-9]+-[0-9]*|-[0-9]+)$').hasMatch(range)) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        return;
      }
      token = CancelToken();
      _requests[token] = response;
      final requestToken = token;
      unawaited(
        response.done.then<void>(
          (_) => requestToken.cancel('Native video request closed'),
          onError: (Object _, StackTrace __) =>
              requestToken.cancel('Native video request disconnected'),
        ),
      );
      // Only seek validators are accepted from the local player. In particular,
      // its Cookie/Authorization/Host headers cannot enter the source transport.
      final result = await _transport.request<ResponseBody>(
        _upstream,
        cancelToken: token,
        options: Options(
          method: request.method,
          responseType: ResponseType.stream,
          headers: {
            ..._headers,
            HttpHeaders.acceptEncodingHeader: 'identity',
            if (range != null) HttpHeaders.rangeHeader: range,
            if (request.headers.value(HttpHeaders.ifRangeHeader)
                case final value?)
              HttpHeaders.ifRangeHeader: value,
          },
          extra: const {apiMediaRequestKey: true},
          validateStatus: (status) => const [200, 206, 416].contains(status),
        ),
      );
      if (!_allowed) throw StateError('Video access revoked');
      response.statusCode = result.statusCode ?? HttpStatus.badGateway;
      response.bufferOutput = false;
      // Never forward Location, cookies, authentication challenges or source URLs.
      for (final name in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.etagHeader,
        HttpHeaders.lastModifiedHeader,
      ]) {
        final values = result.headers[name];
        if (values != null) response.headers.set(name, values);
      }
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final body = result.data;
      if (body == null) throw StateError('Missing video response');
      if (request.method == 'HEAD') {
        await body.stream.listen(null).cancel();
      } else {
        await response.addStream(
          body.stream.map((chunk) {
            if (!_allowed) throw StateError('Video access revoked');
            return chunk;
          }),
        );
      }
    } catch (_) {
      if (token != null && !token.isCancelled) _reportFailure();
      token?.cancel('Video stream stopped');
      // A failed preparation must never complete as an empty success. Once
      // headers are sent, terminate the socket rather than send any late bytes.
      try {
        response.statusCode = _allowed
            ? HttpStatus.badGateway
            : HttpStatus.forbidden;
        response.headers.clear();
        response.contentLength = 0;
      } catch (_) {
        try {
          final socket = await response.detachSocket(writeHeaders: false);
          socket.destroy();
        } catch (_) {}
      }
    } finally {
      if (token != null) {
        _requests.remove(token);
        token.cancel('Video request complete');
      }
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> close() => _closing ??= _close();

  void _reportFailure() {
    if (!_allowed || _reportedFailure || _failures.isClosed) return;
    _reportedFailure = true;
    _failures.add(null);
  }

  Future<void> _close() async {
    _closed = true;
    for (final entry in _requests.entries.toList()) {
      entry.key.cancel('Video access revoked');
    }
    await _server.close(force: true);
    _requests.clear();
    // A disposed preparation may never acquire a listener. Closing its signal
    // must not wait for that absent listener before releasing the server.
    unawaited(_failures.close());
  }
}
