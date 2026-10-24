import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boorusama_post_link_test.dart' show config;

const postUri =
    'boorusama://post/open?v=1&engine=danbooru&site=https%3A%2F%2Fsite.test&key=id%3A42';

void main() {
  test('post and search documents round trip through the existing strict resolvers', () {
    final search = BoorusamaSearchLink.fromTags(
      auth: config('https://site.test').auth,
      tags: ['one_piece', '-rating:s'],
    )!;
    for (final uri in [postUri, search.uri.toString()]) {
      final file = BoorusamaLinkFile.fromUri(uri);
      expect(BoorusamaLinkFile.decode(file.encode()).uri, Uri.parse(uri));
      expect(file.fileName, endsWith('.bslink'));
      expect(file.encode().length, lessThan(BoorusamaLinkFile.maxBytes));
    }
  });

  test('untrusted documents cannot open other routes or carry credentials', () {
    final good = jsonDecode(
      utf8.decode(BoorusamaLinkFile.fromUri(postUri).encode()),
    ) as Map<String, dynamic>;
    for (final value in [
      '',
      'not json',
      '[]',
      jsonEncode({...good, 'version': 2}),
      jsonEncode({...good, 'version': 1.0}),
      jsonEncode({...good, 'format': 'bsexport'}),
      jsonEncode({...good, 'extra': 'unexpected'}),
      jsonEncode({...good, 'uri': 'boorusama://profile/?id=42'}),
      jsonEncode({...good, 'uri': 'https://site.test/posts/42'}),
      jsonEncode({...good, 'uri': '$postUri&key=id%3A43'}),
      jsonEncode({
        ...good,
        'uri': postUri.replaceFirst(
          'https%3A%2F%2Fsite.test',
          'https%3A%2F%2Fuser%3Asecret%40site.test',
        ),
      }),
      'a' * (BoorusamaLinkFile.maxBytes + 1),
    ]) {
      expect(
        () => BoorusamaLinkFile.decode(utf8.encode(value)),
        throwsFormatException,
      );
    }
    expect(() => BoorusamaLinkFile.decode([0xff, 0xfe]), throwsFormatException);
  });

  test('a renamed document can be opened through the picker but large files are bounded', () async {
    final root = await Directory.systemTemp.createTemp('bslink-read-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/renamed.bin');
    await file.writeAsBytes(BoorusamaLinkFile.fromUri(postUri).encode());
    expect(
      (await BoorusamaLinkFile.read(file.path, const IoFileSystem())).uri,
      Uri.parse(postUri),
    );
    await file.writeAsBytes(List.filled(BoorusamaLinkFile.maxBytes + 1, 32));
    await expectLater(
      BoorusamaLinkFile.read(file.path, const IoFileSystem()),
      throwsFormatException,
    );
  });
}
