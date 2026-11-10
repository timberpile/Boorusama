import 'package:dio/dio.dart';

import '../posts/post/types.dart';
import 'anonymous_source_policy.dart';
import 'content_access.dart';

/// One transient, revocable transport per explicitly allowed public source and
/// access generation. Neither the scope nor its client is profile/backup data.
final class AnonymousReadScope {
  AnonymousReadScope({
    required this.source,
    required this.key,
    required Dio Function() createDio,
    required bool Function() current,
  }) : _createDio = createDio,
       _current = current {
    if (key.profileId != null ||
        key.engine != source.engine ||
        key.siteNamespace != normalizePostSourceHost(source.site.toString())) {
      throw const FormatException('Invalid anonymous access scope');
    }
  }

  final AnonymousSource source;
  final ContentAccessKey key;
  Dio Function()? _createDio;
  bool Function()? _current;
  Dio? _dio;
  var _disposed = false;

  String get cacheNamespace =>
      'public-read-v${AnonymousSourcePolicy.version}/${key.engine.id}/'
      '${Uri.encodeComponent(key.siteNamespace)}/${key.authEpoch}/${key.policyEpoch}';

  bool get isCurrent {
    if (_disposed) return false;
    try {
      return _current?.call() ?? false;
      // Riverpod's disposed-ref guard uses StateError rather than Exception.
      // ignore: avoid_catching_errors
    } on StateError {
      // A disposed provider reference cannot authorize another request.
      return false;
    }
  }

  Dio get dio {
    if (!isCurrent) {
      throw StateError('Anonymous access scope is no longer active');
    }
    return _dio ??= _createDio!();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dio?.close(force: true);
    _dio = null;
    // Cached auth keys may outlive a consumer; release all provider references.
    _createDio = null;
    _current = null;
  }
}
