import 'package:boorusama/core/posts/shares/src/boorusama_link_image.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../bulk_downloads/common.dart';

void main() {
  test('still posts use the active viewer image, not an implicit original', () {
    final post = dummyPost(
      originalImageUrl: 'https://test.invalid/original.jpg',
    );
    expect(
      boorusamaLinkImagePayload(post, 'https://test.invalid/sample.jpg').value,
      'https://test.invalid/sample.jpg',
    );
    expect(boorusamaLinkImagePayload(post, '').available, isFalse);
  });

  test('videos share a preview, never their movie or a synthetic still', () {
    final post = dummyPost(
      videoUrl: 'https://test.invalid/movie.mp4',
      format: 'mp4',
      thumbnailImageUrl: 'https://test.invalid/thumb.png',
      sampleImageUrl: 'https://test.invalid/movie.mp4',
    );
    expect(
      boorusamaLinkImagePayload(post, post.videoUrl).value,
      post.thumbnailImageUrl,
    );
    final noPreview = dummyPost(
      videoUrl: post.videoUrl,
      format: 'mp4',
      sampleImageUrl: post.videoUrl,
    );
    expect(
      boorusamaLinkImagePayload(noPreview, post.videoUrl).available,
      isFalse,
    );
  });

  test('extensionless video aliases cannot masquerade as image previews', () {
    final post = dummyPost(
      videoUrl: 'https://test.invalid/media/42',
      format: 'mp4',
      thumbnailImageUrl: 'https://test.invalid/media/42',
    );
    expect(boorusamaLinkImagePayload(post, post.videoUrl).available, isFalse);
  });
}
