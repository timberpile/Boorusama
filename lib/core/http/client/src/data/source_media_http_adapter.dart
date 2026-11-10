import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../configs/network/types.dart';
import '../coordination/api_request_context.dart';

/// Restricts credentials and redirects while borrowing the source transport.
final class SourceMediaHttpClientAdapter implements HttpClientAdapter {
  SourceMediaHttpClientAdapter({
    required this.delegate,
    required this.source,
    required this.current,
  });

  final HttpClientAdapter delegate;
  final Uri source;
  final bool Function() current;
  final _pending = <Completer<void>>{};
  var _closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.extra[apiMediaRequestKey] != true ||
        !const ['GET', 'HEAD'].contains(options.method.toUpperCase()) ||
        options.data != null ||
        requestStream != null) {
      throw DioException(
        requestOptions: options,
        message: 'Invalid media request',
      );
    }
    final cancelled = Completer<void>();
    _pending.add(cancelled);
    if (cancelFuture != null) {
      unawaited(
        cancelFuture.then(
          (_) {
            if (!cancelled.isCompleted) cancelled.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!cancelled.isCompleted) cancelled.complete();
          },
        ),
      );
    }
    void check() {
      if (_closed || cancelled.isCompleted || !current()) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Media access revoked',
        );
      }
    }

    var request = options;
    Uri? previous;
    var redirects = 0;
    var handedOff = false;
    try {
      while (true) {
        check();
        final uri = request.uri;
        if (!_validUri(uri) ||
            (previous?.scheme == 'https' && uri.scheme != 'https')) {
          throw DioException(
            requestOptions: options,
            message: 'Invalid media destination',
          );
        }
        final headers = _withinSource(uri)
            ? Map<String, dynamic>.of(request.headers)
            : _safeHeaders(request.headers);
        final fetch = delegate
            .fetch(
              request.copyWith(headers: headers, followRedirects: false),
              null,
              cancelled.future,
            )
            .then((body) {
              if (cancelled.isCompleted || _closed || !current()) {
                unawaited(body.stream.listen(null).cancel());
              }
              return body;
            });
        final body = await Future.any<ResponseBody?>([
          fetch,
          cancelled.future.then((_) => null),
        ]);
        if (body == null) {
          check();
          throw StateError('Media access revoked');
        }
        if (_closed || cancelled.isCompleted || !current()) {
          if (!_closed && !cancelled.isCompleted) {
            await body.stream.listen(null).cancel();
          }
          check();
        }
        final location = [
          for (final entry in body.headers.entries)
            if (entry.key.toLowerCase() == 'location') ...entry.value,
        ];
        final redirect = const [
          301,
          302,
          303,
          307,
          308,
        ].contains(body.statusCode);
        if (!redirect || !options.followRedirects || location.isEmpty) {
          final original = body.stream;
          body.stream = _guardStream(original, cancelled, check);
          handedOff = true;
          return body;
        }
        await body.stream.listen(null).cancel();
        check();
        if (location.length != 1 || redirects++ >= options.maxRedirects) {
          throw DioException(
            requestOptions: options,
            message: 'Invalid media redirect',
          );
        }
        previous = uri;
        request = request.copyWith(
          path: uri.resolve(location.single).toString(),
          baseUrl: '',
          queryParameters: const {},
          headers: headers,
        );
      }
    } finally {
      if (!handedOff) _finish(cancelled);
    }
  }

  Stream<Uint8List> _guardStream(
    Stream<Uint8List> stream,
    Completer<void> cancelled,
    void Function() check,
  ) async* {
    final iterator = StreamIterator(stream);
    final cancellation = cancelled.future.then<bool>((_) => false);
    try {
      while (await Future.any([iterator.moveNext(), cancellation])) {
        check();
        yield iterator.current;
      }
      check();
    } finally {
      await iterator.cancel();
      _finish(cancelled);
    }
  }

  void _finish(Completer<void> cancelled) {
    _pending.remove(cancelled);
    if (!cancelled.isCompleted) cancelled.complete();
  }

  bool _validUri(Uri uri) =>
      const ['http', 'https'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;

  bool _withinSource(Uri uri) {
    return MediaRequest.permitsSourceHeaders(uri, source);
  }

  Map<String, dynamic> _safeHeaders(Map<String, dynamic> headers) {
    final strings = <String, String>{};
    for (final entry in headers.entries) {
      if (entry.value is String) strings[entry.key] = entry.value as String;
    }
    final result = <String, dynamic>{
      ...MediaRequest.filterSourceHeaders(strings),
    };
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'referer' || entry.value is! String) {
        continue;
      }
      final referer = Uri.tryParse(entry.value as String);
      if (referer != null &&
          referer.scheme == 'https' &&
          referer.scheme == source.scheme &&
          referer.host == source.host &&
          referer.port == source.port &&
          referer.userInfo.isEmpty &&
          !referer.hasQuery &&
          !referer.hasFragment &&
          const ['', '/'].contains(referer.path)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final cancellation in _pending.toList()) {
      if (!cancellation.isCompleted) cancellation.complete();
    }
    _pending.clear();
  }
}
