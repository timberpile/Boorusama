import 'package:booru_clients/nhentai.dart';
import 'package:test/test.dart';

Map<String, dynamic> detail({List<Map<String, dynamic>>? pages, int? count}) =>
    {
      'id': 101,
      'media_id': '7001',
      'title': {'english': 'Fixture Gallery'},
      'pages':
          pages ??
          [
            for (var number in [1, 2, 3])
              {
                'number': number,
                'path': 'galleries/7001/$number.webp',
                'width': 100,
                'height': 200,
              },
          ],
      'num_pages': count ?? 3,
      'cover': {
        'path': 'galleries/7001/cover.webp.webp',
        'width': 350,
        'height': 494,
      },
      'thumbnail': {
        'path': 'galleries/7001/thumb.webp',
        'width': 250,
        'height': 353,
      },
      'tags': [
        {'id': 9, 'type': 'future_type', 'name': 'synthetic tag'},
      ],
    };
void main() {
  test('Gallery ID, media ID and original Page numbers remain independent', () {
    final gallery = NhentaiGalleryDetails.fromJson(
      detail(
        pages: [
          {'number': 3, 'path': 'galleries/7001/3.webp'},
          {'number': 1, 'path': 'galleries/7001/1.webp'},
          {'number': 2},
        ],
      ),
    );
    expect(gallery.id, 101);
    expect(gallery.mediaId, '7001');
    expect(gallery.sourceKey, 'gallery:101');
    expect(gallery.pages!.map((p) => p.number), [3, 1, 2]);
    expect(gallery.pages!.map((p) => p.sourcePosition), [2, 0, 1]);
    expect(gallery.pages!.last.path, isNull);
    expect(gallery.pages!.last.width, isNull);
    expect(gallery.hasCompleteManifest, isTrue);
    expect(gallery.cover!.path, 'galleries/7001/cover.webp.webp');
    expect(gallery.tags.single.type, 'future_type');
    expect(gallery.favoriteCount, isNull);
    expect(gallery.uploadedAt, isNull);
  });
  test('missing/default manifest and explicit empty Gallery stay distinct', () {
    final absent = detail()..remove('pages');
    expect(NhentaiGalleryDetails.fromJson(absent).pages, isNull);
    expect(NhentaiGalleryDetails.fromJson(absent).hasCompleteManifest, isFalse);
    expect(
      NhentaiGalleryDetails.fromJson(detail(pages: [])).hasCompleteManifest,
      isFalse,
    );
    expect(
      NhentaiGalleryDetails.fromJson(
        detail(pages: [], count: 0),
      ).hasCompleteManifest,
      isTrue,
    );
    final gap = NhentaiGalleryDetails.fromJson(
      detail(
        pages: [
          {'number': 1},
          {'number': 3},
        ],
      ),
    );
    expect(gap.pages!.map((p) => p.number), [1, 3]);
    expect(gap.hasCompleteManifest, isFalse);
    expect(
      NhentaiGalleryDetails.fromJson(detail()..['num_pages'] = -3).pageCount,
      isNull,
    );
    expect(
      () => NhentaiGalleryDetails.fromJson(
        detail(
          pages: [
            {'number': 2},
            {'number': 2},
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => NhentaiGalleryDetails.fromJson(
        detail(
          pages: [
            {'number': 0},
          ],
        ),
      ),
      throwsFormatException,
    );
  });
  test(
    'summary evidence remains nullable, preserving duplicate source rows',
    () {
      final response = NhentaiResultPage<NhentaiGallerySummary>.fromJson(
        {
          'result': [
            {'id': 101, 'media_id': '7001'},
            {'id': 101},
          ],
          'total': 50,
          'num_pages': 5,
          'per_page': 120,
        },
        page: 2,
        parse: NhentaiGallerySummary.fromJson,
      );
      expect(response.items.map((g) => g.id), [101, 101]);
      expect(response.rawCount, 2);
      expect(response.reportedPerPage, 120);
      expect(response.hasMore, isTrue);
      expect(response.items.first.pageCount, isNull);
      expect(response.items.last.mediaId, isNull);
      expect(response.items.first.favoriteCount, isNull);
      expect(const NhentaiResultPage<int>(items: [], page: 1).hasMore, isNull);
      expect(
        () => NhentaiResultPage<NhentaiGallerySummary>.fromJson(
          {'total': 0},
          page: 1,
          parse: NhentaiGallerySummary.fromJson,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'Page pairing is stable and collision-free without an assumed maximum page count',
    () {
      final values = <int>{};
      for (var gallery = 1; gallery < 250; gallery++) {
        for (var page = 1; page < 300; page++) {
          final identity = NhentaiPageIdentity(
            galleryId: gallery,
            pageNumber: page,
          );
          expect(values.add(identity.numericPostId), isTrue);
          expect(NhentaiPageIdentity.parse(identity.sourceKey), identity);
          expect(identity.sourcePosition, page - 1);
        }
      }
      expect(NhentaiPageIdentity(galleryId: 1, pageNumber: 1).numericPostId, 1);
      expect(
        NhentaiPageIdentity(galleryId: 134217727, pageNumber: 1).numericPostId,
        lessThanOrEqualTo(9007199254740991),
      );
      expect(
        () => NhentaiPageIdentity(galleryId: 134217728, pageNumber: 1),
        throwsFormatException,
      );
      for (final key in [
        'gallery-page:1:0',
        'gallery-page:01:2',
        'gallery:1',
        'gallery-page:-1:1',
      ]) {
        expect(() => NhentaiPageIdentity.parse(key), throwsFormatException);
      }
    },
  );
}
