import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../configs/network/types.dart';
import '../../../../images/media_diagnostics.dart';
import '../coordination/api_request_context.dart';

/// Restricts credentials and redirects while borrowing the source transport.
final class SourceMediaHttpClientAdapter implements HttpClientAdapter {
  SourceMediaHttpClientAdapter({
    required this.delegate,
    required this.source,
    required this.current,
    this.mediaHostOverrides = const [],
    this.ownsDelegate = false,
    this.diagnostics,
    this.diagnosticBinding = MediaDiagnosticBinding.bound,
  });

  final HttpClientAdapter delegate;
  final Uri source;
  final bool Function() current;
  final List<MediaHostOverride> mediaHostOverrides;
  final bool ownsDelegate;
  final MediaDiagnostics? diagnostics;
  final MediaDiagnosticBinding diagnosticBinding;
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
    var finalHeaders = options.headers;
    int? correlation;
    var destination = options.path;
    var stage = 'resolution';
    Uri? previous;
    var redirects = 0;
    var handedOff = false;
    try {
      while (true) {
        check();
        stage = 'resolution';
        final uri = request.uri;
        destination = uri.toString();
        correlation ??= diagnostics?.correlationFor(destination);
        if (!_validUri(uri) ||
            (previous?.scheme == 'https' && uri.scheme != 'https')) {
          throw DioException(
            requestOptions: options,
            message: 'Invalid media destination',
          );
        }
        final headers = _withinSource(uri)
            ? Map<String, dynamic>.of(request.headers)
            : _safeHeaders(request.headers, uri);
        finalHeaders = headers;
        stage = 'request';
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
          if (body.statusCode >= 400) {
            final failedRequest = request.copyWith(headers: headers);
            diagnostics?.failure(
              url: uri.toString(),
              error: DioException(
                requestOptions: failedRequest,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: failedRequest,
                  statusCode: body.statusCode,
                ),
              ),
              headers: headers,
              binding: diagnosticBinding,
              correlation: correlation,
              stage: 'request',
            );
          }
          final original = body.stream;
          body.stream = _guardStream(
            original,
            cancelled,
            check,
            url: uri.toString(),
            headers: headers,
            correlation: correlation,
          );
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
    } catch (error, stack) {
      diagnostics?.failure(
        url: destination,
        error: error,
        stackTrace: stack,
        headers: finalHeaders,
        binding: diagnosticBinding,
        correlation: correlation,
        stage: MediaDiagnostics.isCancellation(error) ? 'request' : stage,
      );
      rethrow;
    } finally {
      if (!handedOff) _finish(cancelled);
    }
  }

  Stream<Uint8List> _guardStream(
    Stream<Uint8List> stream,
    Completer<void> cancelled,
    void Function() check, {
    required String url,
    required Map<String, dynamic> headers,
    int? correlation,
  }) async* {
    final iterator = StreamIterator(stream);
    final cancellation = cancelled.future.then<bool>((_) => false);
    try {
      while (await Future.any([iterator.moveNext(), cancellation])) {
        check();
        yield iterator.current;
      }
      check();
    } catch (error, stack) {
      diagnostics?.failure(
        url: url,
        error: error,
        stackTrace: stack,
        headers: headers,
        binding: diagnosticBinding,
        correlation: correlation,
        stage: 'request',
      );
      rethrow;
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

  Map<String, dynamic> _safeHeaders(
    Map<String, dynamic> headers,
    Uri destination,
  ) {
    final strings = <String, String>{};
    for (final entry in headers.entries) {
      if (entry.value is String) strings[entry.key] = entry.value as String;
    }
    // An explicitly configured replacement retains the original media role.
    // Re-evaluate on every hop so an unrelated redirect cannot inherit it.
    final original = mediaHostOverrides
        .where((rule) => rule.to == destination.host)
        .firstOrNull;
    final mediaDestination = original == null
        ? destination
        : destination.replace(host: original.from);
    return MediaRequest.filterMediaHeaders(
      strings,
      source: source,
      destination: mediaDestination,
    );
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    for (final cancellation in _pending.toList()) {
      if (!cancellation.isCompleted) cancellation.complete();
    }
    _pending.clear();
    if (ownsDelegate) delegate.close(force: force);
  }
}
