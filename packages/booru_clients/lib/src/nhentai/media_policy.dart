/// Source configuration supplies a subset of the service-owned CDN family.
/// Imported media addresses cannot add destinations to this permission.
final class NhentaiMediaPolicy {
  NhentaiMediaPolicy({
    required Iterable<String> imageServers,
    required Iterable<String> thumbnailServers,
  }) : images = _roots(imageServers, 'i'),
       thumbnails = _roots(thumbnailServers, 't');
  factory NhentaiMediaPolicy.fromJson(Map<String, dynamic> json) {
    Iterable<String> servers(String key) {
      final raw = json[key];
      if (raw is! List || raw.any((e) => e is! String)) {
        throw const FormatException('Missing CDN server list');
      }
      return raw.cast<String>();
    }

    return NhentaiMediaPolicy(
      imageServers: servers('image_servers'),
      thumbnailServers: servers('thumb_servers'),
    );
  }
  final List<Uri> images;
  final List<Uri> thumbnails;
  static List<Uri> _roots(Iterable<String> values, String family) {
    final roots = <Uri>{};
    for (final value in values) {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !_safe(uri) ||
          !RegExp('^$family[1-9][0-9]*\\.nhentai\\.net\$').hasMatch(uri.host) ||
          !const ['', '/'].contains(uri.path) ||
          uri.hasQuery) {
        throw const FormatException('Untrusted nhentai CDN root');
      }
      roots.add(uri.replace(path: ''));
    }
    if (roots.isEmpty || roots.length > 16) {
      throw const FormatException('Invalid CDN budget');
    }
    return List.unmodifiable(roots);
  }

  static bool _safe(Uri uri) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment;

  Uri resolve({
    required String mediaId,
    required String path,
    bool thumbnail = false,
    int serverIndex = 0,
  }) {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(mediaId) ||
        path.contains('%') ||
        path.contains(r'\') ||
        path.split('/').any((part) => part == '.' || part == '..') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const FormatException('Unsafe source media path');
    }
    final roots = thumbnail ? thumbnails : images;
    if (serverIndex < 0 || serverIndex >= roots.length) {
      throw RangeError.index(serverIndex, roots);
    }
    final parsed = Uri.tryParse(path);
    if (parsed == null) {
      throw const FormatException('Invalid source media path');
    }
    final absolute = parsed.hasScheme || parsed.hasAuthority;
    final candidate = absolute ? parsed : roots[serverIndex].resolve(path);
    if (!allows(candidate, mediaId: mediaId, thumbnail: thumbnail)) {
      throw const FormatException(
        'Media destination outside source permission',
      );
    }
    return candidate;
  }

  bool allows(Uri uri, {required String mediaId, bool thumbnail = false}) {
    final roots = thumbnail ? thumbnails : images;
    if (!_safe(uri) ||
        uri.hasQuery ||
        !roots.any((root) => root.host == uri.host) ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch(mediaId)) {
      return false;
    }
    return RegExp(
      '^/galleries/$mediaId/[A-Za-z0-9_-]+(?:\\.(?:jpg|jpeg|png|gif|webp|avif))+\$',
    ).hasMatch(uri.path);
  }
}
