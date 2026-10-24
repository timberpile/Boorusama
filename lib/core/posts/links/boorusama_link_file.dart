import 'dart:convert';
import 'dart:typed_data';

import '../../../foundation/filesystem.dart';
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
    throw const FormatException('Unsupported Boorusama link');
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
