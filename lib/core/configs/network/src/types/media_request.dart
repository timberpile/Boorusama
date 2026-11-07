// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import 'media_host_override.dart';

final class MediaRequest extends Equatable {
  MediaRequest._({
    required this.url,
    required Map<String, String> headers,
    required this.overridden,
  }) : headers = Map.unmodifiable(headers);

  factory MediaRequest.resolve(
    String url, {
    required Iterable<MediaHostOverride> overrides,
    Map<String, String> headers = const {},
    String? sourceUrl,
  }) {
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      for (final rule in overrides) {
        if (uri.host.toLowerCase() != rule.from) {
          continue;
        }
        return MediaRequest._(
          url: uri.replace(host: rule.to, userInfo: '').toString(),
          headers: filterSourceHeaders(headers),
          overridden: true,
        );
      }
    }
    final source = sourceUrl == null ? null : Uri.tryParse(sourceUrl);
    if (source != null &&
        source.hasAuthority &&
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme != source.scheme ||
            uri.host != source.host ||
            uri.port != source.port)) {
      return MediaRequest._(
        url: uri.replace(userInfo: '').toString(),
        headers: {
          ...filterSourceHeaders(headers),
          for (final entry in headers.entries)
            if (entry.key.toLowerCase() == 'referer' &&
                _safeRootReferer(entry.value, source))
              entry.key: entry.value,
        },
        overridden: true,
      );
    }
    return MediaRequest._(url: url, headers: headers, overridden: false);
  }

  final String url;
  final Map<String, String> headers;
  final bool overridden;

  static bool _safeRootReferer(String value, Uri source) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.scheme == source.scheme &&
        uri.host == source.host &&
        uri.port == source.port &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        const ['', '/'].contains(uri.path);
  }

  /// Filters source-profile headers before sending to a replacement host.
  /// Apply destination-host clearance after this, not before.
  static Map<String, String> filterSourceHeaders(Map<String, String> headers) {
    const allowed = {
      'user-agent',
      'accept',
      'accept-encoding',
      'accept-language',
      'range',
      'if-range',
      'if-none-match',
      'if-modified-since',
    };
    return Map.fromEntries(
      headers.entries.where(
        (entry) => allowed.contains(entry.key.toLowerCase()),
      ),
    );
  }

  @override
  List<Object?> get props => [url, headers, overridden];
}
