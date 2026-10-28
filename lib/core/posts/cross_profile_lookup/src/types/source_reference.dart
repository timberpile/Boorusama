/// Only single URL tokens are safe to interpolate into a site's search grammar.
/// Preserve query parameters and path case; they may identify a different work.
String? lookupSourceUrl(String? raw) {
  if (raw == null || raw.isEmpty || RegExp(r'''[\s*"'\\]''').hasMatch(raw)) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.removeFragment().toString();
}

String? pixivArtworkId(String? raw) {
  // Gelbooru returns HTML-escaped query separators even in its JSON API.
  final url = lookupSourceUrl(raw?.replaceAll('&amp;', '&'));
  if (url == null) return null;
  final uri = Uri.parse(url);
  if ((uri.queryParametersAll['illust_id']?.length ?? 0) > 1) return null;
  final host = uri.host.toLowerCase();
  String? id;
  if (host == 'pixiv.net' || host.endsWith('.pixiv.net')) {
    id = RegExp(r'^/(?:[a-z]{2}/)?artworks/([0-9]+)/?$')
        .firstMatch(uri.path)
        ?.group(1);
    if (uri.path == '/member_illust.php') {
      id ??= uri.queryParameters['illust_id'];
    }
  }
  if (host == 'pximg.net' ||
      host.endsWith('.pximg.net') ||
      host.endsWith('.pixiv.net')) {
    id ??= RegExp(r'/([0-9]+)_p[0-9]+(?:_[a-zA-Z0-9]+)?\.[a-zA-Z0-9]+$')
        .firstMatch(uri.path)
        ?.group(1);
  }
  return id != null && RegExp(r'^[1-9][0-9]*$').hasMatch(id) ? id : null;
}
