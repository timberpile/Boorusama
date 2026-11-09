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
          headers: filterMediaHeaders(
            headers,
            source: sourceUrl == null ? null : Uri.tryParse(sourceUrl),
            destination: uri,
            preserveSourceRootReferer: false,
          ),
          overridden: true,
        );
      }
    }
    final source = sourceUrl == null ? null : Uri.tryParse(sourceUrl);
    if (source != null &&
        source.hasAuthority &&
        uri != null &&
        uri.hasAuthority &&
        !permitsSourceHeaders(uri, source)) {
      return MediaRequest._(
        url: uri.replace(userInfo: '').toString(),
        headers: filterMediaHeaders(headers, source: source, destination: uri),
        overridden: true,
      );
    }
    return MediaRequest._(url: url, headers: headers, overridden: false);
  }

  final String url;
  final Map<String, String> headers;
  final bool overridden;

  /// Source credentials belong to one authority and configured installation.
  /// This is also the final adapter's rule for each media redirect hop.
  static bool permitsSourceHeaders(Uri uri, Uri source) {
    if (!const ['http', 'https'].contains(uri.scheme) ||
        !const ['http', 'https'].contains(source.scheme) ||
        uri.userInfo.isNotEmpty ||
        source.userInfo.isNotEmpty ||
        uri.scheme != source.scheme ||
        uri.host != source.host ||
        uri.port != source.port)
      return false;
    if (uri.path.contains(r'\') ||
        RegExp(
          '%(?:2f|5c|2e|25)',
          caseSensitive: false,
        ).hasMatch(uri.toString().split('?').first.split('#').first) ||
        uri.pathSegments.any((part) => part == '.' || part == '..'))
      return false;
    final base = source.path.replaceFirst(RegExp(r'/+$'), '');
    return base.isEmpty || uri.path == base || uri.path.startsWith('$base/');
  }

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

  /// Pixiv's public image Referer is a media protocol header, not API auth.
  /// Validate both roles explicitly; a redirect to another host loses it.
  static bool permitsMediaReferer(String value, Uri source, Uri destination) {
    const pixivSites = {'pixiv.net', 'www.pixiv.net', 'app-api.pixiv.net'};
    if (pixivSites.contains(source.host.toLowerCase())) {
      final referer = Uri.tryParse(value);
      final host = destination.host.toLowerCase();
      return source.scheme == 'https' &&
          source.userInfo.isEmpty &&
          destination.scheme == 'https' &&
          destination.userInfo.isEmpty &&
          destination.port == 443 &&
          (host == 'pximg.net' || host.endsWith('.pximg.net')) &&
          referer != null &&
          referer.toString() == 'https://www.pixiv.net/';
    }
    return _safeRootReferer(value, source);
  }

  static Map<String, String> filterMediaHeaders(
    Map<String, String> headers, {
    required Uri? source,
    required Uri destination,
    bool preserveSourceRootReferer = true,
  }) => {
    ...filterSourceHeaders(headers),
    if (source != null)
      for (final entry in headers.entries)
        if ((preserveSourceRootReferer ||
                const {
                  'pixiv.net',
                  'www.pixiv.net',
                  'app-api.pixiv.net',
                }.contains(source.host)) &&
            entry.key.toLowerCase() == 'referer' &&
            permitsMediaReferer(entry.value, source, destination))
          entry.key: entry.value,
  };

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
