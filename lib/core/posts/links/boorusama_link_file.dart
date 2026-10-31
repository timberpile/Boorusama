import 'dart:convert';
import 'dart:typed_data';

import '../../../foundation/filesystem.dart';
import 'boorusama_artist_link.dart';
import 'boorusama_post_link.dart';
import 'boorusama_search_link.dart';

/// A navigation document, never a backup or a source of account credentials.
final class BoorusamaLinkFile {
  const BoorusamaLinkFile._(this.uri, this.fileName);

  factory BoorusamaLinkFile.fromUri(String value) {
    if (BoorusamaPostLink.tryParse(value) case final post?) {
      final key = post.key.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-');
      return BoorusamaLinkFile._(
        post.uri,
        'boorusama-post-${key.replaceFirst('id-', '')}.bslink',
      );
    }
    if (BoorusamaSearchLink.tryParse(value) case final search?) {
      return BoorusamaLinkFile._(search.uri, 'boorusama-search.bslink');
    }
    if (BoorusamaArtistLink.tryParse(value) case final artist?) {
      return BoorusamaLinkFile.fromArtist(
        artist,
        profileName: artist.site.host,
      );
    }
    throw const FormatException('Unsupported Boorusama link');
  }

  /// The exported name belongs to the page's source profile, never the active
  /// navigation profile. The portable document still contains no profile name.
  factory BoorusamaLinkFile.fromArtist(
    BoorusamaArtistLink artist, {
    required String profileName,
  }) {
    String component(String name, String fallback) {
      final cleaned = name
          .replaceAll(
            RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]'),
            '_',
          )
          .trim()
          .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
      return cleaned.isEmpty ? fallback : cleaned;
    }

    String fit(String value, int bytes) {
      final result = StringBuffer();
      var used = 0;
      for (final rune in value.runes) {
        final character = String.fromCharCode(rune);
        final size = utf8.encode(character).length;
        if (used + size > bytes) break;
        result.write(character);
        used += size;
      }
      return result.toString().trimRight().replaceFirst(RegExp(r'[. ]+$'), '');
    }

    final profile = component(profileName, artist.site.host);
    final name = component(artist.artistName, 'artist');
    // Leave room for the separator and extension within the portable 255-byte
    // filename limit. Give either component the space the other does not need.
    final nameBytes = utf8.encode(name).length;
    final profileBudget = 247 - (nameBytes < 124 ? nameBytes : 124);
    final safeProfile = fit(profile, profileBudget);
    final safeArtist = fit(name, 247 - utf8.encode(safeProfile).length);
    var stem = '$safeProfile-$safeArtist';
    if (RegExp(
      r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$',
      caseSensitive: false,
    ).hasMatch(stem)) {
      stem = '_${fit(stem, 247)}';
    }
    return BoorusamaLinkFile._(artist.uri, '$stem.bslink');
  }

  static const mimeType = 'application/vnd.boorusama.link';
  static const maxBytes = 16 * 1024;
  final Uri uri;
  final String fileName;

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'boorusama-link',
        'version': 1,
        'uri': uri.toString(),
      }),
    ),
  );

  static BoorusamaLinkFile decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Invalid link document size');
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic> ||
        data.length != 3 ||
        data['format'] != 'boorusama-link' ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data['uri'] is! String) {
      throw const FormatException('Invalid link document');
    }
    return BoorusamaLinkFile.fromUri(data['uri'] as String);
  }

  /// Read at most the limit plus one byte, including when a provider lies about
  /// size or the user selected a renamed document. Never trust the extension.
  static Future<BoorusamaLinkFile> read(String path, AppFileSystem fs) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in fs.openRead(path, end: maxBytes + 1)) {
      bytes.add(chunk);
      if (bytes.length > maxBytes) {
        throw const FormatException('Link document is too large');
      }
    }
    return decode(bytes.takeBytes());
  }
}
