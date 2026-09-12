import 'package:booru_clients/pixiv.dart';
import 'package:test/test.dart';

void main() {
  group('PixivIllustDto original URL resolution', () {
    test('resolves a single-page illust from meta_single_page', () {
      final illust = PixivIllustDto.fromJson({
        'id': 1,
        'page_count': 1,
        'meta_single_page': {
          'original_image_url': 'https://i.pximg.net/img-original/1.jpg',
        },
        'meta_pages': [],
        'image_urls': {'medium': 'https://i.pximg.net/medium/1.jpg'},
      });

      expect(illust.originalImageUrls, [
        'https://i.pximg.net/img-original/1.jpg',
      ]);
    });

    test('resolves a multi-page illust from meta_pages in order', () {
      final illust = PixivIllustDto.fromJson({
        'id': 2,
        'page_count': 3,
        'meta_single_page': <String, dynamic>{},
        'meta_pages': [
          {
            'image_urls': {'original': 'https://i.pximg.net/p0.jpg'},
          },
          {
            'image_urls': {'original': 'https://i.pximg.net/p1.jpg'},
          },
          {
            'image_urls': {'original': 'https://i.pximg.net/p2.jpg'},
          },
        ],
      });

      expect(illust.originalImageUrls, [
        'https://i.pximg.net/p0.jpg',
        'https://i.pximg.net/p1.jpg',
        'https://i.pximg.net/p2.jpg',
      ]);
    });

    test('parses an illust carrying unknown extra keys without throwing', () {
      expect(
        () => PixivIllustDto.fromJson({
          'id': 3,
          'title': 'test',
          'page_count': 1,
          'restriction_attributes': ['nsfw'],
          'seasonal_effect_animation_urls': {'foo': 'bar'},
          'event_banners': [
            {'id': 1},
          ],
          'is_accept_request': true,
          'some_completely_new_field_from_the_future': 42,
        }),
        returnsNormally,
      );
    });
  });
}
