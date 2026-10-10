import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image and original stay distinct when their URLs coincide', () {
    final payloads = PostSharePayloads.build(
      isVideo: false,
      viewerImageUrl: 'https://site.test/full.jpg',
      originalUrl: 'https://site.test/full.jpg',
      booruLink: 'https://site.test/posts/42',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media.map((p) => p.id), [
      SharePayloadId.image,
      SharePayloadId.original,
    ]);
    expect(payloads.media[0].canCopy, isTrue);
    expect(payloads.media[0].canShare, isTrue);
    expect(payloads.media[1].canCopy, isTrue);
    expect(payloads.media[1].canShare, isTrue);
    expect(payloads.media[0].value, payloads.media[1].value);
    expect(payloads.links.last.canShare, isTrue);
  });

  test('missing links and unproven Original stay disabled', () {
    final payloads = PostSharePayloads.build(
      isVideo: false,
      viewerImageUrl: '',
      originalUrl: '',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.links.map((p) => p.id), [
      SharePayloadId.booruLink,
      SharePayloadId.sourceLink,
      SharePayloadId.imageLink,
      SharePayloadId.postId,
    ]);
    expect(payloads.links.take(3).every((p) => !p.available), isTrue);
    expect(payloads.media.first.available, isFalse);
    expect(payloads.media[1].available, isFalse);
  });

  test('image link matches the viewer variant chosen for Image', () {
    final payloads = PostSharePayloads.build(
      isVideo: false,
      viewerImageUrl: 'https://site.test/sample.png',
      originalUrl: 'https://site.test/full.jpg',
      booruLink: '',
      sourceLink: null,
      postId: 42,
    );

    expect(payloads.media.first.value, 'https://site.test/sample.png');
    expect(payloads.links[2].value, 'https://site.test/sample.png');
    expect(payloads.media[1].value, 'https://site.test/full.jpg');
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
