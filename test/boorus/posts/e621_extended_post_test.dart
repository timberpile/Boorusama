import 'package:booru_clients/e621.dart';
import 'package:boorusama/boorus/e621/posts/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extended responses keep WebP previews and original media facts', () {
    const base = 'https://example.test';
    final post = postDtoToPostNoMetadata(
      PostDto.fromJson({
        'id': 121,
        'files': {
          'original': {
            'url': '$base/movie.webm',
            'width': 2400,
            'height': 1600,
          },
          'meta': {'size': 1200, 'ext': 'webm'},
          'preview': {'webp': '$base/preview.webp'},
          'sample': {'webp': '$base/sample.webp'},
          'video': {
            'original': {'url': '$base/movie.mp4'},
          },
        },
        'stats': {'fav_count': 0, 'comment_count': 3},
      }),
    )!;
    expect(post.thumbnailImageUrl, '$base/preview.webp');
    expect(post.sampleImageUrl, '$base/sample.webp');
    expect(post.originalImageUrl, '$base/movie.webm');
    expect(post.videoUrl, '$base/movie.mp4');
    expect(post.detailFacts.originalByteSize, 1200);
    expect(post.detailFacts.originalWidth, 2400);
    expect(post.detailFacts.originalHeight, 1600);
    expect(post.detailFacts.originalFormat, 'webm');
    expect(post.detailFacts.favoriteCount, 0);
    expect(post.detailFacts.commentCount, 3);
  });

  test('ignores malformed names in a flat tag list when converting a post', () {
    final dto = PostDto.fromJson({
      'id': 42,
      'files': {
        'original': {'url': 'https://example.test/42.jpg'},
      },
      'tags': ['valid_tag', null, 17],
    });
    final post = postDtoToPostNoMetadata(dto)!;
    expect(post.tags, {'valid_tag'});
  });

  test('a restricted post has no displayable original', () {
    expect(
      postDtoToPostNoMetadata(
        PostDto.fromJson({
          'id': 121,
          'files': {
            'preview': {'webp': 'https://example.test/preview.webp'},
          },
        }),
      ),
      isNull,
    );
  });
}
