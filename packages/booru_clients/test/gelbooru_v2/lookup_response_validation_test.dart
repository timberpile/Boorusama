import 'package:booru_clients/src/gelbooru_v2/parsers/gel_parsers.dart';
import 'package:booru_clients/src/gelbooru_v2/parsers/r34_parsers.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

Response<dynamic> response(Object? data, {String tags = ''}) => Response(
  requestOptions: RequestOptions(
    path: '/index.php',
    queryParameters: {'tags': tags},
  ),
  data: data,
);

void main() {
  test('Safebooru empty XML is a completed empty page', () {
    final result = parseGelPosts(
      response('<posts count="0" offset="0"></posts>'),
      const {},
    );
    expect(result.posts, isEmpty);
    expect(result.count, 0);
  });

  for (final xml in [
    '<response success="false" reason="search down"/>',
    '<posts success="false"/>',
    '<html><body>unavailable</body></html>',
  ]) {
    test('an XML API error cannot become an empty lookup: $xml', () {
      expect(
        () => parseGelPosts(response(xml), const {}),
        throwsFormatException,
      );
    });
  }

  for (final parser in [parseGelPosts, parseR34PostsApi]) {
    test('$parser preserves missing hashes for lookup identity validation', () {
      final data = [
        {
          'id': 42,
          'file_url': 'https://media.test/42.png',
          'source': 'https://www.pixiv.net/artworks/12345',
        },
      ];
      for (final query in [
        'md5:0123456789abcdef0123456789abcdef',
        'source:*pixiv.net/*artworks/12345*',
      ]) {
        final result = parser(response(data, tags: query), const {
          'baseUrl': 'https://safebooru.org',
        });
        expect(result.posts, hasLength(1));
        expect(result.posts.single.hash, isNull);
      }
      expect(parser(response(data), const {}).posts, isEmpty);
    });
  }
}
