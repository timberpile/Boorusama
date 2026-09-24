// Flutter imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/common/grid_thumbnail_url.dart';
import 'package:boorusama/boorus/gelbooru/posts/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';

void main() {
  group('Gelbooru video thumbnail quality', () {
    final higherQualities = [
      ImageQuality.automatic,
      ImageQuality.high,
      ImageQuality.highest,
      ImageQuality.original,
    ];

    test('keeps the small thumbnail at Low quality', () {
      final media = gelbooruGridThumbnailMedia(
        _post(format: 'mp4'),
        _settings(ImageQuality.low),
      );

      expect(media.url, 'https://example.test/thumbnail.jpg');
      expect(media.fallbackUrl, isNull);
    });

    for (final quality in higherQualities) {
      test('uses the static poster at $quality quality', () {
        final media = gelbooruGridThumbnailMedia(
          _post(format: 'mp4'),
          _settings(quality),
        );

        expect(media.url, 'https://example.test/poster.jpg');
        expect(media.placeholderUrl, 'https://example.test/thumbnail.jpg');
        expect(media.fallbackUrl, 'https://example.test/thumbnail.jpg');
      });
    }

    final unchangedCases = [
      (format: 'jpg', quality: ImageQuality.high),
      (format: 'gif', quality: ImageQuality.automatic),
    ];

    for (final c in unchangedCases) {
      test('keeps default behavior for ${c.format} at ${c.quality}', () {
        final post = _post(format: c.format);
        final settings = _settings(c.quality);

        expect(
          gelbooruGridThumbnailMedia(post, settings),
          defaultGridThumbnailMedia(post, settings),
        );
      });
    }
  });
}

GelbooruPost _post({required String format}) => GelbooruPost(
  format: format,
  height: 720,
  id: 1,
  md5: 'hash',
  originalImageUrl: 'https://example.test/video.$format',
  rating: Rating.general,
  sampleImageUrl: 'https://example.test/poster.jpg',
  source: PostSource.none(),
  tags: const {},
  thumbnailImageUrl: 'https://example.test/thumbnail.jpg',
  width: 1280,
  hasComment: false,
  hasParentOrChildren: false,
  fileSize: 0,
  score: 0,
  createdAt: null,
  parentId: null,
  uploaderId: null,
  uploaderName: null,
  metadata: null,
  status: null,
);

GridThumbnailSettings _settings(ImageQuality quality) => GridThumbnailSettings(
  imageQuality: quality,
  animatedPostsDefaultState: AnimatedPostsDefaultState.static,
  gridSize: GridSize.large,
);
