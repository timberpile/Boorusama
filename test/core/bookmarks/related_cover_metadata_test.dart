import 'package:boorusama/core/boorus/booru/types.dart';

import 'dart:convert';

import 'package:boorusama/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_presentation_covers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes/test_post.dart';
import '../../support/fakes/memory_repositories.dart';

void main() {
  final post = _MediaPost(
    TestPost(
      id: 7,
      thumbnailImageUrl: 'https://fixture.test/thumb.jpg',
      sampleImageUrl: 'https://fixture.test/sample.jpg',
      originalImageUrl: 'https://fixture.test/original.jpg',
    ),
  );
  final cover = PoolBookmarkCover.fromPost(post);

  test('selection captures distinct media ratios and preserves them in JSON and order copies', () {
    expect(
      cover.aspectRatios,
      GroupCoverAspectRatios(thumbnail: .5, sample: 1, original: 2),
    );
    final restored = PoolBookmarkCover.fromJson(
      jsonDecode(jsonEncode(cover.toJson())) as Map<String, dynamic>,
    );
    expect(restored, cover);
    expect(restored.withMemberOrder('a' * 64).aspectRatios, cover.aspectRatios);
    final old = PoolBookmarkCover.fromJson(
      {...cover.toJson()}..remove('aspectRatios'),
    );
    expect(old.aspectRatios, isNull);
  });

  test(
    'optional ratios survive the native summary codec without a schema change',
    () {
      final reference = const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse('https://danbooru.donmai.us'),
        kind: ContentKind.group,
        sourceKey: 'related:7',
      );
      final summary = ContentGroupSummary(
        reference: reference,
        cover: GroupCover(
          thumbnail: Uri.parse(cover.thumbnail),
          sample: Uri.parse(cover.sample),
          original: Uri.parse(cover.original),
          aspectRatios: cover.aspectRatios,
        ),
      );
      final codec = GroupMetadataCodec(dataCodecFor: (_) => null);
      expect(codec.decodeSummary(codec.encodeSummary(summary)), summary);
      final old = codec.encodeSummary(summary);
      (old['cover']! as Map).remove('aspectRatios');
      expect(codec.decodeSummary(old).cover!.aspectRatios, isNull);
    },
  );

  test('invalid ratios are unknown without discarding a selected cover', () {
    final ratios = GroupCoverAspectRatios(
      thumbnail: double.nan,
      sample: -1,
      original: double.infinity,
    );
    expect(ratios.toJson(), isEmpty);
    expect(
      GroupCoverAspectRatios.fromJson(const {
        'thumbnail': 'invalid',
        'original': 2,
      }).original,
      2,
    );
  });

  test('animated media fallback records the retained thumbnail ratio', () {
    final animated = PoolBookmarkCover.fromPost(
      _MediaPost(
        TestPost(
          id: 7,
          thumbnailImageUrl: post.thumbnailImageUrl,
          sampleImageUrl: 'https://fixture.test/sample.gif',
          originalImageUrl: 'https://fixture.test/original.webm',
        ),
      ),
    );
    expect(animated.sample, animated.thumbnail);
    expect(animated.original, animated.thumbnail);
    expect(
      animated.aspectRatios,
      GroupCoverAspectRatios(thumbnail: .5, sample: .5, original: .5),
    );
  });

  test('receiver-local sticky choice persists its own media ratios', () async {
    final store = MemoryPersistentCacheStore();
    final choices = BookmarkPresentationCovers(store);
    await choices.remember('received', cover, current: () => true);
    await choices.remember(
      'received',
      PoolBookmarkCover.fromPost(TestPost(id: 99)),
      current: () => true,
    );
    expect(BookmarkPresentationCovers(store).selected('received'), cover);
  });

  for (final resolver in <GridThumbnailUrlGenerator>[
    const DefaultGridThumbnailUrlGenerator(),
    const DefaultGridThumbnailUrlGenerator.thumbnailOnly(),
    const DanbooruGridThumbnailUrlGenerator(),
  ]) {
    for (final variants in [false, true]) {
      test(
        '$resolver selects actual media ratios (variants=$variants) across quality and grid size',
        () {
          final selected = PoolBookmarkCover.fromJson({
            ...cover.toJson(),
            if (variants)
              'variants': {
                '180x180': 'https://fixture.test/180.jpg',
                '360x360': 'https://fixture.test/360.jpg',
                '720x720': 'https://fixture.test/720.jpg',
                'sample': 'https://fixture.test/sample-variant.jpg',
                'original': 'https://fixture.test/original-variant.jpg',
              },
          });
          for (final quality in ImageQuality.values) {
            for (final size in GridSize.values) {
              final result = resolver.resolveStaticCover(
                selected,
                settings: GridThumbnailSettings(
                  imageQuality: quality,
                  gridSize: size,
                  animatedPostsDefaultState: AnimatedPostsDefaultState.static,
                ),
              );
              final expected = result.url.contains('original')
                  ? 2
                  : result.url.contains('sample')
                  ? 1
                  : .5;
              expect(
                result.aspectRatio,
                expected,
                reason: '$quality / $size / ${result.url}',
              );
              expect(result.placeholderAspectRatio, .5);
            }
          }
        },
      );
    }
  }

  test(
    'missing Danbooru variants use the ratio of the URL that actually survives',
    () {
      final selected = PoolBookmarkCover.fromJson({
        ...cover.toJson(),
        'variants': const {'180x180': 'https://fixture.test/180.jpg'},
      });
      final result = const DanbooruGridThumbnailUrlGenerator()
          .resolveStaticCover(
            selected,
            settings: const GridThumbnailSettings(
              imageQuality: ImageQuality.high,
              gridSize: GridSize.large,
              animatedPostsDefaultState: AnimatedPostsDefaultState.static,
            ),
          );
      expect(result.url, selected.thumbnail);
      expect(result.aspectRatio, .5);
    },
  );
}

final class _MediaPost extends Post {
  _MediaPost(Post post)
    : super(origin: post.origin, core: post.core, booruData: post.booruData);
  @override
  double? get thumbnailAspectRatio => .5;
  @override
  double? get sampleAspectRatio => 1;
  @override
  double? get originalAspectRatio => 2;
}
