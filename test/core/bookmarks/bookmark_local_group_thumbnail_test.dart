import 'package:boorusama/boorus/gelbooru_v2/posts/grid_thumbnail_url.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/images/booru_image_candidates.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  const thumbnail =
      'https://realbooru.com/thumbnails/ab/cd/thumbnail_0123456789abcdef0123456789abcdef.jpg';
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://realbooru.com',
    customDownloadFileNameFormat: null,
  );
  for (final quality in [ImageQuality.low, ImageQuality.high]) {
    for (final sample in [
      '',
      'https://realbooru.com/index.php?page=post&s=view&id=123',
    ]) {
      testWidgets(
        'Realbooru group uses timeline policy at $quality with sample $sample',
        (tester) async {
          final bookmark = PostBookmark(
            id: 1,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            width: 100,
            height: 100,
            md5: '',
            tags: const {},
            realSourceUrl: null,
            postId: 123,
            metadata: const {},
            imageUrlResolver: const DefaultImageUrlResolver(),
            booruId: BooruType.gelbooruV2.id,
            sourceUrl: config.url,
            thumbnailUrl: thumbnail,
            sampleUrl: sample,
            originalUrl: sample,
            format: 'jpg',
          );
          final listing = Settings.defaultSettings.listing.copyWith(
            imageQuality: quality,
            gridSize: GridSize.large,
          );
          await tester.pumpWidget(
            _app(bookmark, config, listing),
          );
          final fallback = tester.widget<BooruImage>(find.byType(BooruImage));
          expect(fallback.imageUrl, thumbnail);
          expect(fallback.config, config.auth);
          if (quality == ImageQuality.high) {
            final candidates = tester.widget<BooruImageCandidates>(
              find.byType(BooruImageCandidates),
            );
            expect(candidates.urls, [
              for (final suffix in ['jpg', 'jpeg', 'png', 'webp', 'avif'])
                'https://realbooru.com/images/ab/cd/0123456789abcdef0123456789abcdef.$suffix',
            ]);
          } else {
            expect(find.byType(BooruImageCandidates), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('group cover skips media without a matching origin profile', (
    tester,
  ) async {
    final bookmark = _preview(config).copyWith(
      sourceUrl: 'https://unconfigured.example',
      thumbnailUrl: thumbnail,
      format: () => 'jpg',
    );
    await tester.pumpWidget(
      _app(bookmark, config, Settings.defaultSettings.listing),
    );
    expect(find.byType(BooruImage), findsNothing);
    expect(find.byType(BooruImageCandidates), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final format in ['GIF', 'jpg']) {
    for (final staticPoster in [false, true]) {
      testWidgets(
        'disabled group autoplay recognizes $format with static poster $staticPoster',
        (tester) async {
          final bookmark = _preview(config).copyWith(
            format: () => format,
            thumbnailUrl: staticPoster
                ? 'https://media.test/thumb.PNG'
                : 'https://media.test/thumb.gif',
            sampleUrl: 'https://media.test/sample.gif',
            originalUrl: 'https://media.test/original.gif',
          );
          await tester.pumpWidget(
            _app(
              bookmark,
              config,
              Settings.defaultSettings.listing.copyWith(
                animatedPostsDefaultState: AnimatedPostsDefaultState.static,
              ),
            ),
          );
          expect(find.byType(BooruImageCandidates), findsNothing);
          if (staticPoster) {
            expect(
              tester.widget<BooruImage>(find.byType(BooruImage)).imageUrl,
              bookmark.thumbnailUrl,
            );
          } else {
            expect(find.byType(BooruImage), findsNothing);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

PostBookmark _preview(BooruConfig config) => PostBookmark(
  id: 1,
  booruId: config.booruId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  thumbnailUrl: '',
  sampleUrl: '',
  originalUrl: '',
  sourceUrl: config.url,
  width: 100,
  height: 100,
  md5: '',
  tags: const {},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: 123,
  metadata: const {},
);

Widget _app(
  PostBookmark bookmark,
  BooruConfig config,
  ImageListingSettings listing,
) => ProviderScope(
  overrides: [
    booruConfigProvider.overrideWith(
      () => BooruConfigNotifier(initialConfigs: [config]),
    ),
    settingsProvider.overrideWithValue(Settings.defaultSettings),
    imageListingSettingsProvider.overrideWithValue(listing),
    automaticMediaLoadingEnabledProvider.overrideWithValue(false),
    gridThumbnailUrlGeneratorProvider.overrideWith((ref, auth) {
      expect(auth, config.auth);
      return const DefaultGridThumbnailUrlGenerator(
        mediaMapper: gelbooruV2ThumbnailOnlyGridThumbnailMedia,
      );
    }),
  ],
  child: BooruLocalization(
    child: MaterialApp(
      theme: ThemeData(
        extensions: const [KurumiExtendedColorScheme()],
      ).withBoorusamaColors(),
      builder: (context, child) => KurumiTheme(
        data: KurumiThemeData.fromMaterial(Theme.of(context)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 200,
            child: BookmarkLocalGroupCard(
              title: 'Saved group',
              previews: [bookmark],
              group: null,
              onTap: () {},
              onRename: null,
              onDuplicate: null,
              onDelete: null,
            ),
          ),
        ),
      ),
    ),
  ),
);
