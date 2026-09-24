// Package imports:
import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:booru_clients/src/gelbooru_v2/post_v2_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';

void main() {
  group('Realbooru video thumbnails', () {
    final markerCases = [
      (
        title: 'rating:explicit, video, video with sound',
        isVideoPreview: true,
      ),
      (
        title: 'rating:safe, video_game, video with sound',
        isVideoPreview: false,
      ),
    ];

    for (final c in markerCases) {
      test('detects the exact video marker in ${c.title}', () {
        final dto = _parsePost(c.title);

        expect(dto.isVideoPreview, c.isVideoPreview);
      });
    }

    test('uses the small thumbnail for video rows at Low quality', () {
      final post = _toPost('rating:explicit, video');

      final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
        post,
        _settings(ImageQuality.low),
      );

      expect(media.url, _thumbnailUrl);
      expect(media.fallbackUrl, isNull);
    });

    test(
      'loads the derived static poster for video rows at Automatic quality',
      () {
        final post = _toPost('rating:explicit, video');

        final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
          post,
          _settings(ImageQuality.automatic),
        );

        expect(post.isVideo, isFalse);
        expect(media.url, _posterUrl);
        expect(media.placeholderUrl, _thumbnailUrl);
        expect(media.fallbackUrl, _thumbnailUrl);
      },
    );

    test('keeps the small thumbnail for normal image rows', () {
      final post = _toPost('rating:safe, scenery');

      final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
        post,
        _settings(ImageQuality.automatic),
      );

      expect(media.url, _thumbnailUrl);
      expect(media.fallbackUrl, isNull);
    });
  });
}

const _thumbnailUrl =
    'https://realbooru.test/thumbnails/ab/cd/thumbnail_0123456789abcdef0123456789abcdef.jpg';
const _posterUrl =
    'https://realbooru.test/images/ab/cd/0123456789abcdef0123456789abcdef.jpg';

PostV2Dto _parsePost(String title) {
  final response = Response<String>(
    requestOptions: RequestOptions(path: '/index.php?page=post&s=list'),
    data:
        '<span class="thumb"><a id="p123"><img src="$_thumbnailUrl" title="$title"></a></span>',
  );

  return parseRbPostsHtml(response, const {}).posts.single;
}

Post _toPost(String title) => gelbooruV2PostDtoToGelbooruPostNoMetadata(
  _parsePost(title),
  const GelbooruV2ImageUrlResolver(),
);

GridThumbnailSettings _settings(ImageQuality quality) => GridThumbnailSettings(
  imageQuality: quality,
  animatedPostsDefaultState: AnimatedPostsDefaultState.static,
  gridSize: GridSize.large,
);
