import 'package:boorusama/boorus/danbooru/posts/listing/src/grid_thumbnail_url.dart';
import 'package:boorusama/core/bookmarks/src/providers/pool_bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_cover.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_pool_card.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

import '../../support/fakes/test_post.dart';
import 'pool_bookmark_test_utils.dart';

void main() {
  final cover = PoolBookmarkCover(
    thumbnail: 'https://media.example/thumb.jpg',
    sample: 'https://media.example/sample.jpg',
    original: 'https://media.example/original.png',
    variants: {
      '180x180': 'https://media.example/180.jpg',
      '360x360': 'https://media.example/360.jpg',
      '720x720': 'https://media.example/720.jpg',
      'sample': 'https://media.example/sample-variant.jpg',
      'original': 'https://media.example/original-variant.png',
    },
  );

  test(
    'default static cover selection matches the former static Post matrix',
    () {
      const resolver = DefaultGridThumbnailUrlGenerator();
      final post = TestPost(
        id: 0,
        format: 'jpg',
        thumbnailImageUrl: cover.thumbnail,
        sampleImageUrl: cover.sample,
        originalImageUrl: cover.original,
      );

      for (final quality in ImageQuality.values) {
        for (final size in GridSize.values) {
          final settings = _settings(quality, size);
          expect(
            resolver.resolveStaticCover(cover, settings: settings).url,
            _defaultExpected(quality, size, cover),
            reason: '${quality.name} / ${size.name}',
          );
          expect(
            resolver.resolveStaticCover(cover, settings: settings).url,
            resolver.resolve(post, settings: settings).url,
            reason: 'Post selection changed for ${quality.name} / ${size.name}',
          );
        }
      }
    },
  );

  test(
    'Danbooru static covers select saved variants across quality and size',
    () {
      const resolver = DanbooruGridThumbnailUrlGenerator();
      for (final quality in ImageQuality.values) {
        for (final size in GridSize.values) {
          expect(
            resolver
                .resolveStaticCover(cover, settings: _settings(quality, size))
                .url,
            _danbooruExpected(quality, size),
            reason: '${quality.name} / ${size.name}',
          );
        }
      }
    },
  );

  test(
    'Danbooru missing static variants fall back to matching cover fields',
    () {
      const resolver = DanbooruGridThumbnailUrlGenerator();
      final partial = PoolBookmarkCover(
        thumbnail: cover.thumbnail,
        sample: cover.sample,
        original: cover.original,
        variants: const {'180x180': 'https://media.example/180.jpg'},
      );

      expect(
        resolver
            .resolveStaticCover(
              partial,
              settings: _settings(ImageQuality.high, GridSize.large),
            )
            .url,
        partial.thumbnail,
      );
      expect(
        resolver
            .resolveStaticCover(
              partial,
              settings: _settings(ImageQuality.highest, GridSize.large),
            )
            .url,
        partial.sample,
      );
      expect(
        resolver
            .resolveStaticCover(
              partial,
              settings: _settings(ImageQuality.original, GridSize.normal),
            )
            .url,
        partial.original,
      );
    },
  );

  test('thumbnail-only generator keeps covers at thumbnail quality', () {
    const resolver = DefaultGridThumbnailUrlGenerator.thumbnailOnly();
    for (final quality in ImageQuality.values) {
      for (final size in GridSize.values) {
        expect(
          resolver
              .resolveStaticCover(cover, settings: _settings(quality, size))
              .url,
          cover.thumbnail,
        );
      }
    }
  });

  testWidgets('a changed cover policy continues to hide the saved cover', (
    tester,
  ) async {
    final config = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.danbooru,
        url: 'https://danbooru.donmai.us',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': poolProfile,
    });
    final pool = PoolBookmark.fromJson({
      ...testPool().toJson(),
      'coverUrl': cover.thumbnail,
      'coverPolicy': 'old-policy',
      'cover': cover.toJson(),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [config]),
          ),
          poolCoverPolicyProvider.overrideWith(
            (ref, config) => const AsyncData('current-policy'),
          ),
          imageListingSettingsProvider.overrideWithValue(
            Settings.defaultSettings.listing,
          ),
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()])
              .withBoorusamaColors(),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(
              Theme.of(context).withBoorusamaColors(),
            ),
            child: child!,
          ),
          home: Scaffold(body: BookmarkPoolCoverImage(pool: pool)),
        ),
      ),
    );

    expect(find.byType(BooruImage), findsNothing);
  });
}

GridThumbnailSettings _settings(ImageQuality quality, GridSize size) =>
    GridThumbnailSettings(
      imageQuality: quality,
      animatedPostsDefaultState: AnimatedPostsDefaultState.static,
      gridSize: size,
    );

String _defaultExpected(
  ImageQuality quality,
  GridSize size,
  PoolBookmarkCover cover,
) {
  final resolved = quality == ImageQuality.automatic
      ? switch (size) {
          GridSize.large => ImageQuality.highest,
          GridSize.normal || GridSize.small => ImageQuality.high,
          GridSize.tiny || GridSize.micro => ImageQuality.low,
        }
      : quality;
  return switch (resolved) {
    ImageQuality.automatic || ImageQuality.low => cover.thumbnail,
    ImageQuality.high || ImageQuality.highest =>
      size == GridSize.micro || size == GridSize.tiny
          ? cover.thumbnail
          : cover.sample,
    ImageQuality.original => cover.original,
  };
}

String _danbooruExpected(ImageQuality quality, GridSize size) {
  final resolved = quality == ImageQuality.automatic
      ? switch (size) {
          GridSize.large => ImageQuality.highest,
          GridSize.normal || GridSize.small => ImageQuality.high,
          GridSize.tiny || GridSize.micro => ImageQuality.low,
        }
      : quality;
  final variant = switch (resolved) {
    ImageQuality.automatic => switch (size) {
      GridSize.micro => '180x180',
      GridSize.tiny => '360x360',
      _ => '720x720',
    },
    ImageQuality.low =>
      size == GridSize.micro || size == GridSize.tiny ? '180x180' : '360x360',
    ImageQuality.high => switch (size) {
      GridSize.micro => '180x180',
      GridSize.tiny => '360x360',
      _ => '720x720',
    },
    ImageQuality.highest => switch (size) {
      GridSize.micro => '360x360',
      GridSize.tiny => '720x720',
      _ => 'sample',
    },
    ImageQuality.original => 'original',
  };
  return switch (variant) {
    '180x180' => 'https://media.example/180.jpg',
    '360x360' => 'https://media.example/360.jpg',
    '720x720' => 'https://media.example/720.jpg',
    'sample' => 'https://media.example/sample-variant.jpg',
    'original' => 'https://media.example/original-variant.png',
    _ => throw StateError('Unexpected Danbooru cover variant: $variant'),
  };
}
