// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/favorites/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/listing/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/types.dart';

void main() {
  const sources = ['search', 'favorites', 'bookmarks', 'feed'];

  for (final source in sources) {
    testWidgets('$source keeps every shared post-card semantic', (
      tester,
    ) async {
      final post = _post();

      await tester.pumpWidget(
        _TestApp(
          child: Stack(
            children: [
              PostGridItem(
                post: post,
                index: 0,
                useHero: false,
                multiSelectEnabled: false,
                config: _config.auth,
                onTap: (_) {},
                presentation: const GenericPostPresentation(),
                quickActionButton: const SizedBox(
                  key: Key('quick-action'),
                ),
                leadingIcons: const [Icon(Icons.star, key: Key('leading'))],
                imageBuilder: (media) => Text(
                  '${media.url}:${media.aspectRatio}',
                  textDirection: TextDirection.ltr,
                ),
              ),
              Text(source, textDirection: TextDirection.ltr),
            ],
          ),
        ),
      );

      expect(find.text('quality-url:1.5'), findsOneWidget);
      expect(find.text(source), findsOneWidget);
      expect(find.byType(ExplicitContentBlockOverlay), findsOneWidget);
      expect(find.byType(DefaultTagListPrevewTooltip), findsOneWidget);
      expect(find.byKey(const Key('quick-action')), findsOneWidget);
      expect(find.byKey(const Key('leading')), findsOneWidget);

      final item = tester.widget<ImageGridItem>(find.byType(ImageGridItem));
      expect(item.isAnimated, isTrue);
      expect(item.isGif, isFalse);
      expect(item.isTranslated, isTrue);
      expect(item.hasComments, isTrue);
      expect(item.hasParentOrChildren, isTrue);
      expect(item.isAI, isTrue);
      expect(item.hasSound, isTrue);
      expect(item.duration, 12);
      expect(item.scoreWidget, isA<ImageScoreWidget>());
    });
  }

  testWidgets(
    'compatible Danbooru data adds native actions and moderation overlay',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: Stack(
            children: [
              PostGridItem(
                post: _post(data: _danbooruData, status: 'banned'),
                index: 0,
                useHero: false,
                multiSelectEnabled: false,
                config: _config.auth,
                onTap: (_) {},
                presentation: const DanbooruPostGridPresentation(),
                imageBuilder: (_) => const SizedBox.expand(),
              ),
              const Text('NEW', textDirection: TextDirection.ltr),
              const Text('group', textDirection: TextDirection.ltr),
            ],
          ),
        ),
      );

      expect(find.byType(DanbooruQuickFavoriteButton), findsOneWidget);
      expect(find.text('artist tag'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('group'), findsOneWidget);
    },
  );

  testWidgets('incompatible data never receives Danbooru additions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: PostGridItem(
          post: _post(
            data: const EmptyPostData(typeKey: 'other'),
            status: 'banned',
          ),
          index: 0,
          useHero: false,
          multiSelectEnabled: false,
          config: _config.auth,
          onTap: (_) {},
          presentation: const DanbooruPostGridPresentation(),
          imageBuilder: (_) => const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(DanbooruQuickFavoriteButton), findsNothing);
    expect(find.text('artist tag'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.example',
  customDownloadFileNameFormat: null,
);

Post _post({
  BooruPostData data = const EmptyPostData(typeKey: 'test'),
  String? status,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: _config.url,
  ),
  core: PostCoreData(
    id: 42,
    thumbnailImageUrl: 'thumb',
    sampleImageUrl: 'sample',
    originalImageUrl: 'original',
    videoUrl: 'video',
    videoThumbnailUrl: 'video-thumb',
    width: 300,
    height: 200,
    format: 'webm',
    md5: 'hash',
    fileSize: 1024,
    duration: 12,
    hasSound: true,
    tags: const {'ai-generated'},
    rating: Rating.general,
    hasComment: true,
    isTranslated: true,
    hasParentOrChildren: true,
    source: PostSource.none(),
    score: 17,
    artistTags: const {'artist_tag'},
    status: status,
  ),
  booruData: data,
);

const _danbooruData = DanbooruPostData(
  lastCommentAt: null,
  upScore: 10,
  downScore: -2,
  favCount: 3,
  approverId: null,
  generalTags: {},
  metaTags: {},
  hasChildren: false,
  hasLarge: true,
  pixelHash: 'pixel',
);

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        currentReadOnlyBooruConfigProvider.overrideWithValue(_config),
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(_config.auth),
        imageListingSettingsProvider.overrideWithValue(
          Settings.defaultSettings.listing.copyWith(showScoresInGrid: true),
        ),
        gridThumbnailUrlGeneratorProvider.overrideWith(
          (ref, config) => const _ProbeGenerator(),
        ),
        currentReadOnlyBooruConfigGestureProvider.overrideWithValue(null),
        booruRepoProvider.overrideWith((ref, config) => null),
        booruBuilderProvider.overrideWith((ref, config) => null),
        canFavoriteProvider.overrideWith((ref, config) => false),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
      ],
      child: SelectionMode(
        child: MaterialApp(
          theme: Kurumi.themeFrom(
            KurumiThemeMode.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            systemDarkMode: false,
          ).withBoorusamaColors(),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}

final class _ProbeGenerator implements GridThumbnailUrlGenerator {
  const _ProbeGenerator();

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) => const GridThumbnailMedia(url: 'quality-url', aspectRatio: 1.5);
}
