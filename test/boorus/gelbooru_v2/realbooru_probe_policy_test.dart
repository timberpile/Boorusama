import 'package:booru_clients/src/gelbooru_v2/parsers/rb_parsers.dart';
import 'package:booru_clients/src/gelbooru_v2/post_v2_dto.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/parser.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const thumbnail =
    'https://realbooru.test/thumbnails/ab/cd/thumbnail_0123456789abcdef0123456789abcdef.jpg';

void main() {
  for (final entry in [
    (tags: 'scenery', quality: ImageQuality.high, probes: true),
    (tags: 'scenery', quality: ImageQuality.low, probes: false),
    (tags: 'scenery gif', quality: ImageQuality.high, probes: false),
    (tags: 'scenery video', quality: ImageQuality.high, probes: false),
  ]) {
    test(
      'format probing is ${entry.probes} for ${entry.tags} at ${entry.quality}',
      () {
        final dto = parseRbPostsHtml(
          Response<String>(
            requestOptions: RequestOptions(path: '/index.php?page=post&s=list'),
            data:
                '<span class="thumb"><a id="p123"><img src="$thumbnail" title="${entry.tags}"></a></span>',
          ),
          const {},
        ).posts.single;
        final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
          dto,
          const GelbooruV2ImageUrlResolver(),
        );
        final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
          post,
          _settings(entry.quality),
        );
        expect(media.probeImageFormats, entry.probes);
        if (entry.probes) {
          expect(Uri.parse(media.url).path, endsWith('.jpg'));
          expect(Uri.parse(media.fallbackUrls.first).path, endsWith('.jpeg'));
          expect(media.fallbackUrl, thumbnail);
        }
      },
    );
  }

  test('a known sample does not probe other formats', () {
    final post = gelbooruV2PostDtoToGelbooruPostNoMetadata(
      PostV2Dto(
        id: 123,
        fileUrl: 'https://realbooru.test/images/sample.png',
        previewUrl: thumbnail,
      ),
      const GelbooruV2ImageUrlResolver(),
    );
    final media = gelbooruV2ThumbnailOnlyGridThumbnailMedia(
      post,
      _settings(ImageQuality.high),
    );
    expect(media.probeImageFormats, isFalse);
    expect(media.fallbackUrls, isEmpty);
  });
}

GridThumbnailSettings _settings(ImageQuality quality) => GridThumbnailSettings(
  imageQuality: quality,
  animatedPostsDefaultState: AnimatedPostsDefaultState.static,
  gridSize: GridSize.large,
);
