// Package imports:
import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:booru_clients/src/gelbooru_v2/post_v2_dto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  group('Realbooru video thumbnails', () {
    test(
      'GIF listing rows show the GIF type while keeping a static grid preview',
      () {
        final post = _toPost('scenery, gif');
        expect(post.isGif, isTrue);
        expect(post.isVideo, isFalse);
        expect(post.showsAnimatedBadge, isTrue);
        expect(post.originalImageUrl, _posterUrl.replaceFirst('.jpg', '.gif'));
        const storedCodec = StoredPostCodec();
        const dataCodec = GelbooruV2PostCodec();
        final decoded = storedCodec.decode(
          storedCodec.encode(post, dataCodec: dataCodec),
          dataCodec: dataCodec,
        );
        expect(decoded, isA<StoredPostDecodeSuccess>());
        expect((decoded as StoredPostDecodeSuccess).post.isGif, isTrue);
        for (final quality in ImageQuality.values) {
          final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
            post,
            _settings(quality),
          );
          expect(media.url, _thumbnailUrl);
          expect(media.fallbackUrls, isEmpty);
        }
      },
    );
    final markerCases = [
      (
        title: 'rating:explicit, video, video with sound',
        isVideoPreview: true,
      ),
      (
        title: 'rating:safe, video_game, video with sound',
        isVideoPreview: false,
      ),
      (title: 'rating:safe video score:5', isVideoPreview: true),
      (title: 'rating:safe\tVIDEO\nscore:5', isVideoPreview: true),
      (title: 'rating:safe video_game', isVideoPreview: false),
      (title: 'rating:safe not_video', isVideoPreview: false),
      (title: '', isVideoPreview: false),
    ];

    for (final c in markerCases) {
      test('detects the exact video marker in ${c.title}', () {
        final dto = _parsePost(c.title);

        expect(dto.isVideoPreview, c.isVideoPreview);
        final post = _toPost(c.title);
        expect(post.showsAnimatedBadge, c.isVideoPreview);
        // A badge must not make the static poster playable video media.
        expect(post.isVideo, isFalse);
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
        expect(post.showsAnimatedBadge, isTrue);
        expect(media.url, _posterUrl);
        expect(media.placeholderUrl, _thumbnailUrl);
        expect(media.fallbackUrl, _thumbnailUrl);
      },
    );

    test(
      'uses larger image candidates for normal rows at Automatic quality',
      () {
        final post = _toPost('rating:safe, scenery');

        final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
          post,
          _settings(ImageQuality.automatic),
        );

        expect(media.url, _posterUrl);
        expect(media.fallbackUrl, _thumbnailUrl);
        expect(post.showsAnimatedBadge, isFalse);
      },
    );

    for (final video in [false, true]) {
      test('Medium loads a larger static image for video=$video', () {
        final post = _toPost('scenery', videoBorder: video);
        final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
          post,
          _settings(ImageQuality.high),
        );
        expect(media.url, _posterUrl);
        expect(media.placeholderUrl, _thumbnailUrl);
        expect(media.fallbackUrl, _thumbnailUrl);
        expect(post.showsAnimatedBadge, video);
        expect(post.isVideo, isFalse);
        expect(
          media.fallbackUrls,
          video
              ? isEmpty
              : [
                  for (final extension in ['jpeg', 'png', 'webp', 'avif'])
                    _posterUrl.replaceFirst('.jpg', '.$extension'),
                ],
        );
      });

      test('Low keeps the small thumbnail for video=$video', () {
        final post = _toPost('scenery', videoBorder: video);
        final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
          post,
          _settings(ImageQuality.low),
        );
        expect(media.url, _thumbnailUrl);
        expect(media.fallbackUrls, isEmpty);
      });
    }

    test('a resolved JPEG or PNG uses its known URL without guessing', () {
      for (final extension in ['jpeg', 'png']) {
        final original = _posterUrl.replaceFirst('.jpg', '.$extension');
        final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
          PostV2Dto(id: 123, fileUrl: original, previewUrl: _thumbnailUrl),
          const GelbooruV2ImageUrlResolver(),
        );
        final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
          post,
          _settings(ImageQuality.high),
        );
        expect(media.url, original);
        expect(media.fallbackUrls, isEmpty);
        expect(media.fallbackUrl, _thumbnailUrl);
      }
    });

    test('does not invent image paths for unrelated thumbnail-only sites', () {
      final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
        PostV2Dto(
          id: 123,
          fileUrl: 'https://other.test/thumbnail.jpg',
          previewUrl: 'https://other.test/thumbnail.jpg',
        ),
        const GelbooruV2ImageUrlResolver(),
      );
      final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
        post,
        _settings(ImageQuality.high),
      );
      expect(media.url, post.thumbnailImageUrl);
      expect(media.fallbackUrls, isEmpty);
    });

    for (final extension in ['mp4', 'webm', 'MP4']) {
      test('recognizes resolved $extension media with a URL query', () {
        final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
          PostV2Dto(
            id: 123,
            fileUrl: 'https://realbooru.test/images/clip.$extension?v=2#media',
            previewUrl: _thumbnailUrl,
          ),
          const GelbooruV2ImageUrlResolver(),
        );
        expect(post.isVideo, isTrue);
        expect(post.showsAnimatedBadge, isTrue);
      });
    }

    test('does not throw or invent a video for an extensionless URL', () {
      final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
        PostV2Dto(id: 123, fileUrl: 'https://realbooru.test/media/123'),
        const GelbooruV2ImageUrlResolver(),
      );
      expect(post.isVideo, isFalse);
      expect(post.showsAnimatedBadge, isFalse);
    });
  });
}

const _thumbnailUrl =
    'https://realbooru.test/thumbnails/ab/cd/thumbnail_0123456789abcdef0123456789abcdef.jpg';
const _posterUrl =
    'https://realbooru.test/images/ab/cd/0123456789abcdef0123456789abcdef.jpg';

PostV2Dto _parsePost(String title, {bool videoBorder = false}) {
  final response = Response<String>(
    requestOptions: RequestOptions(path: '/index.php?page=post&s=list'),
    data:
        '<span class="thumb"><a id="p123"><img src="$_thumbnailUrl" title="$title" '
        '${videoBorder ? 'style="border: 3px solid #0000ff;"' : ''}'
        '></a></span>',
  );

  return parseRbPostsHtml(response, const {}).posts.single;
}

Post _toPost(String title, {bool videoBorder = false}) =>
    gelbooruV2PostDtoToGelbooruPostNoMetadata(
      _parsePost(title, videoBorder: videoBorder),
      const GelbooruV2ImageUrlResolver(),
    );

GridThumbnailSettings _settings(ImageQuality quality) => GridThumbnailSettings(
  imageQuality: quality,
  animatedPostsDefaultState: AnimatedPostsDefaultState.static,
  gridSize: GridSize.large,
);
