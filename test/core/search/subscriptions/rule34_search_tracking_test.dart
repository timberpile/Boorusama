import 'package:booru_clients/gelbooru.dart';
import 'package:booru_clients/src/gelbooru_v2/parsers/gel_parsers.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/subscriptions/src/refresh/chronological_search_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

Post rule34Post(Object? uploadedAt) =>
    gelbooruV2PostDtoToGelbooruPostNoMetadata(
      PostV2Dto.fromJson({
        'id': 1,
        'created_at': uploadedAt,
        'change': 1800000000,
        'file_url': 'https://example.test/1.jpg',
      }, 'https://rule34.xxx'),
      const GelbooruV2ImageUrlResolver(),
    );

void main() {
  test(
    'tracks Safebooru XML uploads with total counts and numeric fields',
    () async {
      final response = parseGelPosts(
        Response(
          requestOptions: RequestOptions(),
          data:
              '<posts count="2" offset="0"> '
              '<post id="7153902" hash="abc" created_at="Thu Sep 17 22:00:18 +0200 2026" '
              'file_url="https://example.test/1.jpg" score="5" has_notes="1" /> '
              '<post id="7153892" hash="def" created_at="Thu Sep 17 22:00:15 +0200 2026" '
              'file_url="https://example.test/2.jpg" score="0" has_notes="0" /> '
              '</posts>',
        ),
        {'baseUrl': 'https://safebooru.org'},
      );
      final posts = response.posts
          .map(
            (dto) => gelbooruV2PostDtoToGelbooruPostNoMetadata(
              dto,
              const GelbooruV2ImageUrlResolver(),
            ),
          )
          .toList();
      expect(response.count, 2);
      expect(posts.first.createdAt, DateTime.utc(2026, 9, 17, 20, 0, 18));
      expect(posts.first.score, 5);
      expect(posts.map((p) => p.hasNotes), [true, false]);
      final result = await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async =>
            Either.right(posts.toResult(total: response.count)),
      );
      expect(result, LoadedSearchSnapshot(posts));
    },
  );

  test(
    'establishes a Rule34 baseline using the server upload timestamp',
    () async {
      final post = rule34Post('Mon Jun 29 21:48:39 +0000 2020');
      expect(post.createdAt, DateTime.utc(2020, 6, 29, 21, 48, 39));
      final result = await ChronologicalSearchScanner().scanSnapshot(
        fetchPage: (_, _) async => Either.right([post].toResult()),
      );
      expect(result, LoadedSearchSnapshot([post]));
    },
  );

  test('loads Rule34 upload timestamps with timezone offsets', () async {
    final post = rule34Post('Mon Jun 29 23:48:39 +0200 2020');
    final result = await ChronologicalSearchScanner().scanSnapshot(
      fetchPage: (_, _) async => Either.right([post].toResult()),
    );
    expect(result, LoadedSearchSnapshot([post]));
  });

  test('preserves a single-digit Rule34 upload day in UTC', () {
    expect(
      rule34Post('Wed Jul  1 00:48:39 +0300 2020').createdAt,
      DateTime.utc(2020, 6, 30, 21, 48, 39),
    );
  });

  test('keeps older Rule34 uploads available for snapshot previews', () async {
    final post = rule34Post('Mon Jun 29 21:48:39 +0000 2020');
    final result = await ChronologicalSearchScanner().scanSnapshot(
      fetchPage: (_, _) async => Either.right([post].toResult()),
    );
    expect(result, LoadedSearchSnapshot([post]));
  });

  for (final c in [
    (name: 'missing', value: null),
    (name: 'malformed', value: 'not-a-date'),
    (name: 'non-string', value: 123),
  ]) {
    test(
      'keeps a ${c.name} Rule34 upload time unknown despite metadata changes',
      () {
        expect(rule34Post(c.value).createdAt, isNull);
      },
    );
  }
}
