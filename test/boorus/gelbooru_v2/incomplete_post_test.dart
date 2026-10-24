import 'package:booru_clients/gelbooru.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains a legacy post with missing media and nullable metadata', () {
    // Negative-rating searches on Safebooru can include incomplete records.
    final dto = PostV2Dto.fromJson({
      'id': 42,
      'file_url': null,
      'preview_url': null,
      'sample_url': null,
      'directory': null,
      'image': null,
      'width': null,
      'height': null,
      'rating': null,
      'score': null,
      'tags': 'landscape',
    }, 'https://safebooru.org');
    final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
      dto,
      const GelbooruV2ImageUrlResolver(),
    );
    expect(post.id, 42);
    expect(post.originalImageUrl, isEmpty);
    expect(post.format, isEmpty);
    expect(post.tags, {'landscape'});
  });
}
