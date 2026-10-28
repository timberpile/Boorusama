import 'source_reference.dart';

/// A shared reference is not a Booru post, file hash or configured account.
final class PixivArtworkReference {
  const PixivArtworkReference._(this.id);

  final String id;
  String get url => 'https://www.pixiv.net/artworks/$id';

  /// Accept captioned shares without following redirects or fetching input URLs.
  /// Different artwork IDs in one share are ambiguous and must not be guessed.
  static PixivArtworkReference? parseSharedText(String? text) {
    if (text == null || text.isEmpty || text.length > 16384) return null;
    final ids = <String>{};
    for (final match in _urls.allMatches(text)) {
      final raw = match.group(0)!.replaceFirst(_trailingPunctuation, '');
      try {
        final uri = Uri.tryParse(raw);
        if (uri == null ||
            uri.userInfo.isNotEmpty ||
            (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
            (uri.queryParametersAll['illust_id']?.length ?? 0) > 1) {
          continue;
        }
        final id = pixivArtworkId(raw);
        if (id != null && id.length <= 20) ids.add(id);
        if (ids.length > 1) return null;
      } on FormatException {
        // Query decoding is lazy; malformed external input is not a crash.
        continue;
      }
    }
    return ids.length == 1 ? PixivArtworkReference._(ids.single) : null;
  }

  static final _urls = RegExp(
    r'''https?://[^\s<>"\x00-\x1f]+''',
    caseSensitive: false,
  );
  static final _trailingPunctuation = RegExp(r'[)\]},.!?。、）」』]+$');
}
