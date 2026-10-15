// Package imports:
import 'package:booru_clients/danbooru.dart' as danbooru_api;
import 'package:booru_clients/e621.dart' as e621_api;
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/post/src/converter.dart'
    as danbooru;
import 'package:boorusama/boorus/e621/posts/parser.dart' as e621;

void main() {
  final cases = [
    (name: 'missing', value: null),
    (name: 'malformed', value: 'not-a-timestamp'),
  ];

  for (final testCase in cases) {
    test('keeps a ${testCase.name} Danbooru upload timestamp unknown', () {
      final post = danbooru.postDtoToPostNoMetadata(
        danbooru_api.PostDto.fromJson({
          'id': 1,
          'created_at': testCase.value,
          'tag_string': 'cat',
        }),
      );

      expect(post.createdAt, isNull);
    });

    test('keeps a ${testCase.name} e621 upload timestamp unknown', () {
      final post = e621.postDtoToPostNoMetadata(
        e621_api.PostDto.fromJson({
          'id': 1,
          'created_at': testCase.value,
          'file': {'url': 'https://static.example.test/1.jpg'},
          'tags': <String, List<dynamic>>{},
        }),
      );

      expect(post?.createdAt, isNull);
    });
  }
}
