import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image and original are the only image media rows', () {
    final payloads = PostSharePayloads.build(
      isVideo: false,
      viewerImageUrl: 'https://site.test/sample.jpg',
      originalUrl: 'https://site.test/preview.jpg',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media.map((payload) => payload.id), [
      SharePayloadId.image,
      SharePayloadId.original,
    ]);
    expect(payloads.media.last.value, 'https://site.test/preview.jpg');
  });

  test('Original stays disabled when only a sample URL is stored', () {
    final payloads = PostSharePayloads.build(
      isVideo: false,
      viewerImageUrl: 'https://site.test/sample.jpg',
      originalUrl: '',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media[0].available, isTrue);
    expect(payloads.media[1].available, isFalse);
  });

  test('video stays available through an exact lazy extractor', () {
    final payloads = PostSharePayloads.build(
      isVideo: true,
      canResolveExactVideo: true,
      viewerImageUrl: 'https://site.test/poster.jpg',
      originalUrl: '',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media.first.available, isTrue);
    expect(payloads.media, hasLength(1));
  });
  test(
    'extractor-owned Original stays available without stored media URLs',
    () {
      final payloads = PostSharePayloads.build(
        isVideo: false,
        canResolveExactOriginal: true,
        viewerImageUrl: '',
        originalUrl: '',
        booruLink: '',
        sourceLink: null,
        postId: 42,
      );

      expect(payloads.media[0].available, isFalse);
      expect(payloads.media[1].available, isTrue);
      expect(payloads.media, hasLength(2));
    },
  );

  test('extractor-owned Video stays available without stored media URLs', () {
    final payloads = PostSharePayloads.build(
      isVideo: true,
      canResolveExactVideo: true,
      viewerImageUrl: '',
      originalUrl: '',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media[0].available, isTrue);
    expect(payloads.media, hasLength(1));
  });

  test('preview-only video leaves its media row unavailable', () {
    final payloads = PostSharePayloads.build(
      isVideo: true,
      viewerImageUrl: 'https://site.test/thumb.jpg',
      originalUrl: '',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media.first.available, isFalse);
    expect(payloads.media, hasLength(1));
  });
}
