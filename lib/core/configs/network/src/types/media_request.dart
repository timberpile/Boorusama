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
        !permitsSourceHeaders(uri, source)) {
      return MediaRequest._(
        url: uri.replace(userInfo: '').toString(),
        headers: {
          ...filterSourceHeaders(headers),
          for (final entry in headers.entries)
            if (entry.key.toLowerCase() == 'referer' &&
                isSafeRootReferer(entry.value, source, uri))
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

  /// A public root Referer is not authority to send profile credentials.
  /// Keep the same decision at URL resolution and every transport redirect hop.
  static bool isSafeRootReferer(String value, Uri source, Uri destination) {
    final referer = Uri.tryParse(value);
    if (referer == null ||
        referer.scheme != 'https' ||
        referer.userInfo.isNotEmpty ||
        referer.hasQuery ||
        referer.hasFragment ||
        !const ['', '/'].contains(referer.path)) {
      return false;
    }
    if (referer.scheme == source.scheme &&
        referer.host == source.host &&
        referer.port == source.port) {
      return true;
    }

    // The catalog uses pixiv.net, but Pixiv's media contract uses www.pixiv.net.
    // This exact public alias is only valid for the known HTTPS media hosts;
    // it must not become a general www alias or authenticated-origin exception.
    return source.scheme == 'https' &&
        source.host == 'pixiv.net' &&
        source.port == 443 &&
        source.userInfo.isEmpty &&
        !source.hasQuery &&
        !source.hasFragment &&
        const ['', '/'].contains(source.path) &&
        referer.host == 'www.pixiv.net' &&
        referer.port == 443 &&
        destination.scheme == 'https' &&
        destination.port == 443 &&
        destination.userInfo.isEmpty &&
        const ['i.pximg.net', 's.pximg.net'].contains(destination.host);
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
