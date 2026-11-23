import 'package:booru_clients/pixiv.dart';
import 'package:test/test.dart';

void main() {
  group('tag observation', () {
    test('distinguishes omitted and invalid fields from explicit empty', () {
      for (final json in [
        <String, dynamic>{},
        {'tags': null},
        {'tags': 'invalid'},
      ]) {
        final dto = PixivIllustDto.fromJson(json);
        expect(dto.tags, isEmpty);
        expect(dto.tagCoverage, PixivTagCoverage.unknown);
      }
      final dto = PixivIllustDto.fromJson({'tags': []});
      expect(dto.tags, isEmpty);
      expect(dto.tagCoverage, PixivTagCoverage.complete);
    });

    test(
      'malformed members retain valid native names as partial observations',
      () {
        final dto = PixivIllustDto.fromJson({
          'tags': [
            {'name': 'native', 'translated_name': 'Native'},
            null,
            3,
            {'name': 4},
            {'name': ''},
            {'translated_name': 'missing name'},
            {'name': 'valid', 'translated_name': 42},
          ],
        });
        expect(dto.tagCoverage, PixivTagCoverage.partial);
        expect(dto.tags.map((tag) => tag.name), ['native', 'valid']);
        expect(dto.tags.map((tag) => tag.translatedName), ['Native', null]);
      },
    );
  });

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

    test('keeps unavailable metadata slots in their original positions', () {
      final illust = PixivIllustDto.fromJson({
        'page_count': 5,
        'meta_pages': [
          {
            'image_urls': {'original': 'https://i.pximg.net/p0.jpg'},
          },
          null,
          'invalid page',
          <String, dynamic>{},
          {
            'image_urls': {'original': 'https://i.pximg.net/p4.jpg'},
          },
        ],
      });

      expect(illust.metaPages.map((page) => page.imageUrls?.original), [
        'https://i.pximg.net/p0.jpg',
        null,
        null,
        null,
        'https://i.pximg.net/p4.jpg',
      ]);
    });
  });
}
