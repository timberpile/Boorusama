import 'boorusama_post_link.dart';
import 'boorusama_search_link.dart';

/// A single plain-text line accompanies the .bslink attachment. Display
/// text is bounded and sanitized; the attachment retains the entire address.
String postLinkShareMessage(
  BoorusamaPostLink link, {
  required String profileName,
  required String postTemplate,
  required String postByArtistTemplate,
  Iterable<String> artists = const [],
}) {
  final parts = link.key.split(':');
  final id = parts.first == 'work-page' ? parts[1] : link.key.substring(3);
  final artistNames =
      artists
          .map((artist) => _singleLine(artist, 60))
          .where((artist) => artist.isNotEmpty && !_unknownArtist(artist))
          .toSet()
          .toList()
        ..sort();
  final profile = _singleLine(profileName, 100);
  final artist = artistNames.firstOrNull;
  return _interpolate(
    artist == null ? postTemplate : postByArtistTemplate,
    {
      'id': id,
      'profile': profile.isEmpty ? link.site.host : profile,
      if (artist != null) 'artist': artist,
    },
  );
}

String searchLinkShareMessage(
  BoorusamaSearchLink link, {
  required String profileName,
  required String searchTemplate,
}) {
  final query = _singleLine(link.typedTags?.join(' ') ?? link.query, 180);
  final profile = _singleLine(profileName, 100);
  return _interpolate(searchTemplate, {
    'query': query,
    'profile': profile.isEmpty ? link.site.host : profile,
  });
}

bool _unknownArtist(String value) => {
  'unknown_artist',
  'artist_request',
  'no_artist',
  'anonymous_artist',
}.contains(value.toLowerCase().replaceAll(' ', '_'));

String _interpolate(String template, Map<String, String> values) =>
    template.replaceAllMapped(
      RegExp(r'\{(id|artist|profile|query)\}'),
      (match) => values[match.group(1)] ?? match.group(0)!,
    );

String _singleLine(String value, int limit) {
  // Sender-controlled names and site metadata must not inject caption lines
  // or bidirectional formatting controls into the receiving messenger.
  final text = value
      .replaceAll(RegExp(r'[\u202a-\u202e\u2066-\u2069]'), '')
      .replaceAll(RegExp(r'[\s\x00-\x1f\x7f]+'), ' ')
      .trim();
  // Truncate at Unicode scalar boundaries, never inside a surrogate pair.
  final runes = text.runes.take(limit + 1).toList();
  return runes.length <= limit
      ? text
      : '${String.fromCharCodes(runes.take(limit - 1))}…';
}
