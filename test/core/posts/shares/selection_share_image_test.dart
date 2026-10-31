import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/shares/src/share_media_url_resolution.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../bulk_downloads/common.dart';

void main() {
  for (final entry in [
    (
      viewer: '',
      sample: 'https://site.test/sample.jpg',
      original: '',
      thumb: 'https://site.test/thumb.jpg',
      expected: 'https://site.test/sample.jpg',
    ),
    (
      viewer: 'https://site.test/view.webp',
      sample: 'https://site.test/sample.jpg',
      original: '',
      thumb: '',
      expected: 'https://site.test/view.webp',
    ),
    (
      viewer: 'invalid',
      sample: '',
      original: 'https://site.test/full.png',
      thumb: 'https://site.test/thumb.jpg',
      expected: 'https://site.test/full.png',
    ),
    (
      viewer: 'file:///private/image.jpg',
      sample: 'https://site.test/video.mp4',
      original: '',
      thumb: 'https://site.test/thumb.jpg',
      expected: 'https://site.test/thumb.jpg',
    ),
    (viewer: '', sample: '', original: '', thumb: '', expected: ''),
  ]) {
    test(
      'resolves a share display image from ${entry.viewer}/${entry.sample}/${entry.original}',
      () async {
        final post = dummyPost(
          id: 42,
          sampleImageUrl: entry.sample,
          originalImageUrl: entry.original,
          thumbnailImageUrl: entry.thumb,
        );
        final url = resolveShareImageUrl(
          post: post,
          viewerImageUrl: entry.viewer,
        );
        expect(url, entry.expected);
        final payloads = PostSharePayloads.build(
          isVideo: false,
          viewerImageUrl: url,
          originalUrl: post.originalImageUrl,
          booruLink: 'https://site.test/posts/42',
          sourceLink: null,
          postId: 42,
        );
        final image = payloads.media.firstWhere(
          (value) => value.id == SharePayloadId.image,
        );
        expect(image.available, entry.expected.isNotEmpty);
        if (image.available) {
          final resolved = await resolveShareMediaUrl(
            payload: image,
            post: post,
            extractor: const UrlInsidePostExtractor(),
          );
          expect(resolved.url, entry.expected);
        }
        expect(
          hasExactOriginalSource(post, const UrlInsidePostExtractor()),
          entry.original.isNotEmpty,
        );
      },
    );
  }

  test('a video poster never enables image or original media sharing', () {
    final post = dummyPost(
      id: 43,
      format: 'mp4',
      sampleImageUrl: 'https://site.test/poster.jpg',
      thumbnailImageUrl: 'https://site.test/thumb.jpg',
    );
    final image = resolveShareImageUrl(post: post, viewerImageUrl: '');
    expect(image, isEmpty);
    final payloads = PostSharePayloads.build(
      isVideo: true,
      viewerImageUrl: image,
      originalUrl: post.videoUrl,
      booruLink: '',
      sourceLink: null,
      postId: 43,
    );
    expect(payloads.media.map((value) => value.id), [SharePayloadId.video]);
    expect(payloads.media.single.available, isFalse);
  });
}
