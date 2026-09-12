// Package imports:
import 'package:booru_clients/pixiv.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/boorus/pixiv/posts/link_generator.dart';
import 'package:boorusama/boorus/pixiv/posts/parser.dart';
import 'package:boorusama/boorus/pixiv/posts/query.dart';
import 'package:boorusama/core/posts/rating/types.dart';

void main() {
  PixivIllustDto illust({
    int? id = 100,
    String? type = 'illust',
    Map<String, dynamic>? imageUrls,
    Object? user = const {'id': 5, 'name': 'Artist', 'account': 'artist_acc'},
    List<Map<String, dynamic>> tags = const [],
    int? pageCount = 1,
    Map<String, dynamic>? metaSinglePage,
    List<Map<String, dynamic>> metaPages = const [],
    int? xRestrict = 0,
    int? sanityLevel = 2,
    bool? visible = true,
    bool? isMuted = false,
    String? createDate,
  }) => PixivIllustDto.fromJson({
    'id': id,
    'title': 'title',
    'type': type,
    'image_urls': imageUrls ?? {'square_medium': 'sq.jpg', 'medium': 'med.jpg'},
    'user': user,
    'tags': tags,
    'create_date': createDate,
    'page_count': pageCount,
    'width': 100,
    'height': 200,
    'sanity_level': sanityLevel,
    'x_restrict': xRestrict,
    'meta_single_page':
        metaSinglePage ??
        {'original_image_url': 'https://i.pximg.net/img-original/100_p0.jpg'},
    'meta_pages': metaPages,
    'visible': visible,
    'is_muted': isMuted,
  });

  group('flattening a work into one entry per page', () {
    test('produces one entry per page in order, sharing the page count', () {
      final result = illustDtoToPosts(
        illust(
          pageCount: 3,
          metaSinglePage: {},
          metaPages: [
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p0.jpg'},
            },
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p1.jpg'},
            },
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p2.jpg'},
            },
          ],
        ),
      );

      expect(result.map((e) => e.originalImageUrl), [
        'https://i.pximg.net/img/100_p0.jpg',
        'https://i.pximg.net/img/100_p1.jpg',
        'https://i.pximg.net/img/100_p2.jpg',
      ]);
      expect(result.map((e) => e.pageIndex), [0, 1, 2]);
      expect(result.every((e) => e.pageCount == 3), isTrue);
    });

    test('yields exactly one entry using the single-page url', () {
      final result = illustDtoToPosts(
        illust(
          metaSinglePage: {
            'original_image_url': 'https://i.pximg.net/img/100_p0.jpg',
          },
        ),
      );

      expect(result, hasLength(1));
      expect(
        result.single.originalImageUrl,
        'https://i.pximg.net/img/100_p0.jpg',
      );
      expect(result.single.pageIndex, 0);
      expect(result.single.pageCount, 1);
    });
  });

  group('visibility filtering', () {
    test('excludes a work marked not visible', () {
      expect(illustDtoToPosts(illust(visible: false)), isEmpty);
    });

    test('excludes a work marked muted', () {
      expect(illustDtoToPosts(illust(isMuted: true)), isEmpty);
    });

    test('excludes a work missing an id or author', () {
      expect(illustDtoToPosts(illust(id: null)), isEmpty);
      expect(illustDtoToPosts(illust(user: null)), isEmpty);
    });
  });

  group('placeholder image detection', () {
    final cases = [
      (
        url: 'https://s.pximg.net/common/images/limit_sanity_level_360.png',
        restricted: true,
      ),
      (
        url: 'https://s.pximg.net/common/images/limit_unviewable_360.png',
        restricted: true,
      ),
      (
        url: 'https://s.pximg.net/common/images/limit_mypixiv_360.png',
        restricted: true,
      ),
      (url: 'https://i.pximg.net/img-original/100_p0.jpg', restricted: false),
    ];

    for (final c in cases) {
      test(
        '${c.restricted ? 'flags' : 'does not flag'} ${c.url} as restricted',
        () {
          final result = illustDtoToPosts(
            illust(metaSinglePage: {'original_image_url': c.url}),
          ).single;

          expect(result.isRestricted, c.restricted);
        },
      );
    }
  });

  group('tags', () {
    test('includes a translated name alongside the original', () {
      final result = illustDtoToPosts(
        illust(
          tags: [
            {'name': 'niji', 'translated_name': 'rainbow'},
          ],
        ),
      ).single;

      expect(result.tags, {'niji', 'rainbow'});
    });

    test('does not duplicate a translated name identical to the original', () {
      final result = illustDtoToPosts(
        illust(
          tags: [
            {'name': 'sky', 'translated_name': 'sky'},
          ],
        ),
      ).single;

      expect(result.tags, {'sky'});
    });

    test('omits a translation when Accept-Language yielded none', () {
      final result = illustDtoToPosts(
        illust(
          tags: [
            {'name': 'sky', 'translated_name': null},
          ],
        ),
      ).single;

      expect(result.tags, {'sky'});
    });
  });

  group('rating mapping', () {
    final cases = [
      (xRestrict: 1, sanityLevel: null, expected: Rating.explicit),
      (xRestrict: 2, sanityLevel: 2, expected: Rating.explicit),
      (xRestrict: 0, sanityLevel: 6, expected: Rating.explicit),
      (xRestrict: 0, sanityLevel: 4, expected: Rating.questionable),
      (xRestrict: 0, sanityLevel: 2, expected: Rating.general),
      (xRestrict: 0, sanityLevel: 0, expected: Rating.general),
      (xRestrict: null, sanityLevel: 2, expected: Rating.unknown),
      (xRestrict: null, sanityLevel: null, expected: Rating.unknown),
    ];

    for (final c in cases) {
      test(
        'x_restrict=${c.xRestrict} sanity_level=${c.sanityLevel} maps to ${c.expected}',
        () {
          expect(
            pixivRatingFrom(xRestrict: c.xRestrict, sanityLevel: c.sanityLevel),
            c.expected,
          );
        },
      );
    }
  });

  group('synthetic per-page ids', () {
    test('differ between pages of the same work', () {
      final result = illustDtoToPosts(
        illust(
          pageCount: 2,
          metaSinglePage: {},
          metaPages: [
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p0.jpg'},
            },
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p1.jpg'},
            },
          ],
        ),
      );

      expect(result.map((e) => e.id).toSet(), hasLength(2));
    });

    test('are unchanged when the same page is parsed again', () {
      int idOf() => syntheticPostId(illustId: 100, pageIndex: 2);

      expect(idOf(), idOf());
    });

    test('do not collide between different works', () {
      final first = syntheticPostId(illustId: 100, pageIndex: 0);
      final second = syntheticPostId(illustId: 101, pageIndex: 0);

      expect(first, isNot(second));
    });
  });

  group('resolving a search into api parameters', () {
    test('scopes to a user given a user meta-tag', () {
      final query = PixivQuery.parse(['user:12345']);

      expect(query.hasUser, isTrue);
      expect(query.userId, 12345);
      expect(query.text, isNull);
    });

    test('treats unprefixed terms as free text', () {
      final query = PixivQuery.parse(['landscape', 'sunset']);

      expect(query.hasUser, isFalse);
      expect(query.text, 'landscape sunset');
    });

    test('ignores a malformed user meta-tag', () {
      final cases = ['user:', 'user:abc', 'user:0', 'user:-5'];

      for (final entry in cases) {
        expect(PixivQuery.parse([entry]).hasUser, isFalse);
      }
    });

    test('lets a later user replace an earlier one', () {
      final query = PixivQuery.parse(['user:1', 'user:2']);

      expect(query.userId, 2);
    });

    test('round-trips a user through its meta-tag form', () {
      final tag = PixivQuery.userTag(12345);
      final query = PixivQuery.parse([tag]);

      expect(query.userId, 12345);
    });

    test('ignores blank entries', () {
      final query = PixivQuery.parse(['', '   ']);

      expect(query.hasUser, isFalse);
      expect(query.text, isNull);
    });
  });

  group('sample url resolution', () {
    test('prefers the large variant for a single-page work', () {
      final result = illustDtoToPosts(
        illust(
          imageUrls: {
            'square_medium': 'sq.jpg',
            'medium': 'med.jpg',
            'large': 'large.jpg',
          },
        ),
      ).single;

      expect(result.sampleImageUrl, 'large.jpg');
    });

    test(
      'falls back to medium when large is absent for a single-page work',
      () {
        final result = illustDtoToPosts(
          illust(
            imageUrls: {'square_medium': 'sq.jpg', 'medium': 'med.jpg'},
          ),
        ).single;

        expect(result.sampleImageUrl, 'med.jpg');
      },
    );

    test('prefers the large variant for a page from meta_pages', () {
      final result = illustDtoToPosts(
        illust(
          imageUrls: {
            'square_medium': 'sq0.jpg',
            'medium': 'med0.jpg',
            'large': 'large0.jpg',
          },
          pageCount: 2,
          metaSinglePage: const {},
          metaPages: [
            {
              'image_urls': {
                'square_medium': 'sq0.jpg',
                'medium': 'med0.jpg',
                'large': 'large0.jpg',
                'original': 'https://i.pximg.net/img/100_p0.jpg',
              },
            },
            {
              'image_urls': {
                'square_medium': 'sq1.jpg',
                'medium': 'med1.jpg',
                'large': 'large1.jpg',
                'original': 'https://i.pximg.net/img/100_p1.jpg',
              },
            },
          ],
        ),
      );

      expect(result.map((e) => e.sampleImageUrl), ['large0.jpg', 'large1.jpg']);
    });

    test(
      'falls back to medium when large is absent for a page from meta_pages',
      () {
        final result = illustDtoToPosts(
          illust(
            imageUrls: {'square_medium': 'sq0.jpg', 'medium': 'med0.jpg'},
            pageCount: 2,
            metaSinglePage: const {},
            metaPages: [
              {
                'image_urls': {
                  'square_medium': 'sq0.jpg',
                  'medium': 'med0.jpg',
                  'original': 'https://i.pximg.net/img/100_p0.jpg',
                },
              },
              {
                'image_urls': {
                  'square_medium': 'sq1.jpg',
                  'medium': 'med1.jpg',
                  'original': 'https://i.pximg.net/img/100_p1.jpg',
                },
              },
            ],
          ),
        );

        expect(result.map((e) => e.sampleImageUrl), ['med0.jpg', 'med1.jpg']);
      },
    );
  });

  group('link generation', () {
    test('produces the canonical artwork url for every page of a work', () {
      const generator = PixivPostLinkGenerator();

      final result = illustDtoToPosts(
        illust(
          pageCount: 2,
          metaSinglePage: {},
          metaPages: [
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p0.jpg'},
            },
            {
              'image_urls': {'original': 'https://i.pximg.net/img/100_p1.jpg'},
            },
          ],
        ),
      );

      for (final post in result) {
        expect(generator.getLink(post), 'https://www.pixiv.net/artworks/100');
      }
    });
  });
}
