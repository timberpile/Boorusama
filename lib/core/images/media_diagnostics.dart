import 'dart:async';

import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../foundation/loggers.dart';
import '../configs/config/types.dart';

/// Uses the existing logger; only bounded transient correlation/coalescing state
/// is retained. These identifiers never participate in persistent cache keys.
final mediaDiagnosticsProvider = Provider.autoDispose
    .family<MediaDiagnostics?, BooruConfigAuth>((ref, config) {
      try {
        return MediaDiagnostics(
          logger: ref.watch(loggerProvider),
          engine: config.booruType.name,
          source: Uri.tryParse(config.url),
        );
      } catch (_) {
        // Reduced hosts may omit logging. Diagnostics never authorize a request
        // or turn an otherwise usable image into a provider failure.
        return null;
      }
    }, dependencies: [loggerProvider]);

enum MediaDiagnosticBinding { unbound, bound, anonymous, override }

enum MediaDiagnosticRendition {
  primary,
  placeholder,
  fallback,
  preview,
  intermediate,
  target,
}

class MediaDiagnostics {
  MediaDiagnostics({required this.logger, required this.engine, this.source});

  final Logger logger;
  final String engine;
  final Uri? source;
  final _correlations = <String, int>{};
  final _reported = <String>{};
  static var _nextCorrelation = 0;

  int correlationFor(String url) {
    if (_correlations[url] case final value?) return value;
    if (_correlations.length >= 128) {
      _correlations.remove(_correlations.keys.first);
    }
    return _correlations[url] = ++_nextCorrelation;
  }

  void retry(String url) {
    _correlations.remove(url);
    _reported.clear();
  }

  static bool isCancellation(Object error) =>
      error is DioException && error.type == DioExceptionType.cancel ||
      error is StateError &&
          (error.message.contains('cancel') ||
              error.message.contains('canceled'));

  String _stage(Object error) =>
      error is DioException ||
          error is StateError &&
              (error.message.contains('Empty response') ||
                  error.message.contains('empty file'))
      ? 'request'
      : 'decode';

  String _signature(
    String url,
    String stage,
    Object error,
    MediaDiagnosticRendition rendition,
    Map<String, dynamic> headers,
    MediaDiagnosticBinding binding,
  ) =>
      '$stage|${Uri.tryParse(url)?.host}|${error.runtimeType}|'
      '${error is DioException ? error.response?.statusCode : null}|${rendition.name}|'
      '${isCancellation(error)}|${binding.name}|${_hasHeader(headers, 'referer')}|${_hasHeader(headers, 'user-agent')}';

  bool _claim(String signature) {
    if (!_reported.add(signature)) return false;
    if (_reported.length > 64) _reported.remove(_reported.first);
    return true;
  }

  void failure({
    required String url,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic> headers = const {},
    MediaDiagnosticBinding binding = MediaDiagnosticBinding.unbound,
    MediaDiagnosticRendition rendition = MediaDiagnosticRendition.primary,
    String? stage,
    int? correlation,
    String cacheEntry = 'unknown',
  }) {
    final actualStage = stage ?? _stage(error);
    if (!_claim(
      _signature(url, actualStage, error, rendition, headers, binding),
    )) {
      return;
    }
    _emit(
      url: url,
      error: error,
      stackTrace: stackTrace,
      headers: headers,
      binding: binding,
      rendition: rendition,
      stage: actualStage,
      correlation: correlation ?? correlationFor(url),
      cacheEntry: cacheEntry,
    );
  }

  /// A terminal error may inspect this one existing cache entry. Loading never
  /// waits for this observation, and repeated source failures are coalesced
  /// before any optional I/O. Presence describes the failure-time entry, not an
  /// invented claim that a particular fetch used the disk cache.
  Future<void> imageFailure({
    required String url,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic> headers = const {},
    MediaDiagnosticBinding binding = MediaDiagnosticBinding.unbound,
    MediaDiagnosticRendition rendition = MediaDiagnosticRendition.primary,
    ImageCacheManager? manager,
    bool suppliedBytes = false,
  }) async {
    final observedUrl = error is DioException
        ? requestUrl(error.requestOptions)
        : url;
    final observedHeaders = error is DioException
        ? error.requestOptions.headers
        : headers;
    final stage = _stage(error);
    if (!_claim(
      _signature(
        observedUrl,
        stage,
        error,
        rendition,
        observedHeaders,
        binding,
      ),
    )) {
      return;
    }
    final correlation = correlationFor(url);
    var cacheEntry = suppliedBytes ? 'supplied_bytes' : 'unknown';
    if (!isCancellation(error) && !suppliedBytes && manager != null) {
      try {
        cacheEntry = await manager.hasValidCache(manager.generateCacheKey(url))
            ? 'present'
            : 'absent';
      } catch (_) {
        cacheEntry = 'unavailable';
      }
    }
    _emit(
      url: observedUrl,
      error: error,
      stackTrace: stackTrace,
      headers: observedHeaders,
      binding: binding,
      rendition: rendition,
      stage: stage,
      correlation: correlation,
      cacheEntry: cacheEntry,
    );
  }

  static String requestUrl(RequestOptions options) {
    try {
      return options.uri.toString();
    } catch (_) {
      return options.path;
    }
  }

  void event({
    required String url,
    required String stage,
    required String outcome,
    MediaDiagnosticRendition rendition = MediaDiagnosticRendition.primary,
    LogLevel level = LogLevel.debug,
  }) {
    if (!_claim(
      'event|$stage|${_safeHost(Uri.tryParse(url))}|$outcome|${rendition.name}',
    )) {
      return;
    }
    try {
      logger.log(
        'Media',
        'stage=$stage; engine=$engine; source_host=${_safeHost(source)}; '
            'destination_host=${_safeHost(Uri.tryParse(url))}; rendition=${rendition.name}; '
            'request=media-${correlationFor(url)}; outcome=$outcome',
        level: level,
      );
    } catch (_) {}
  }

  static bool _hasHeader(Map<String, dynamic> headers, String name) =>
      headers.entries.any(
        (entry) =>
            entry.key.toLowerCase() == name &&
            entry.value is String &&
            (entry.value as String).isNotEmpty,
      );

  static String _safeHost(Uri? uri) {
    final host = uri?.host;
    return host != null &&
            host.isNotEmpty &&
            host.length <= 253 &&
            RegExp(r'^[a-zA-Z0-9.:\[\]-]+$').hasMatch(host)
        ? host
        : 'unknown';
  }

  void _emit({
    required String url,
    required Object error,
    StackTrace? stackTrace,
    required Map<String, dynamic> headers,
    required MediaDiagnosticBinding binding,
    required MediaDiagnosticRendition rendition,
    required String stage,
    required int correlation,
    required String cacheEntry,
  }) {
    final referer = _hasHeader(headers, 'referer');
    final agent = _hasHeader(headers, 'user-agent');
    final credentials = headers.keys.any(
      (key) => const {
        'authorization',
        'cookie',
        'hydrus-client-api-access-key',
        'x-api-key',
        'api-key',
      }.contains(key.toLowerCase()),
    );
    final context =
        'stage=$stage; engine=$engine; source_host=${_safeHost(source)}; '
        'destination_host=${_safeHost(Uri.tryParse(url))}; rendition=${rendition.name}; '
        'binding=${binding.name}; request=media-$correlation; cache_entry=$cacheEntry; '
        'referer_required=${engine == 'pixiv'}; referer_present=$referer; user_agent_present=$agent; credential_headers_present=$credentials';
    try {
      if (isCancellation(error)) {
        logger.debug('Media', '$context; outcome=cancelled');
      } else {
        logger.handledError(
          'Media',
          context,
          error: error,
          stackTrace: stackTrace,
          outcome: 'failed',
          level: LogLevel.warning,
        );
      }
    } catch (_) {
      // Logging must not replace the original transport/decode outcome.
    }
  }
}

/// Ordinary timeline media uses the source's existing Dio. Observe only marked
/// media errors without altering its API/session interceptors or requests.
class MediaDiagnosticInterceptor extends Interceptor {
  MediaDiagnosticInterceptor(
    this.diagnostics, {
    this.binding = MediaDiagnosticBinding.unbound,
  });
  final MediaDiagnostics diagnostics;
  final MediaDiagnosticBinding binding;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['boorusama.request.media'] == true) {
      diagnostics.correlationFor(MediaDiagnostics.requestUrl(options));
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final error = err;
    if (error.requestOptions.extra['boorusama.request.media'] == true) {
      diagnostics.failure(
        url: MediaDiagnostics.requestUrl(error.requestOptions),
        error: error,
        stackTrace: error.stackTrace,
        headers: error.requestOptions.headers,
        binding: binding,
        stage: 'request',
      );
    }
    handler.next(error);
  }
}
