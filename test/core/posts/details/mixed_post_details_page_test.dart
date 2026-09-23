// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/danbooru/posts/_shared/danbooru_creator_preloader.dart';
import 'package:boorusama/boorus/danbooru/posts/details/widgets.dart';
import 'package:boorusama/boorus/e621/e621.dart';
import 'package:boorusama/boorus/e621/e621_builder.dart';
import 'package:boorusama/boorus/e621/posts/post_data.dart';
import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/posts/post_data.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/foundation/loggers.dart';

void main() {
  testWidgets(
    'mixed pages switch presentation profile and media without changing the global profile',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final harness = _Harness();
      addTearDown(harness.dispose);

      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      final globalBefore = harness.container.read(currentBooruConfigProvider);
      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      final slideshow = pageView.slideshowController;

      expect(find.byType(DanbooruInformationSection), findsWidgets);
      expect(
        find.byType(DanbooruCreatorPreloader, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(CurrentPostDetailsNotes), findsOneWidget);
      expect(find.byType(MixedPostDetailsImagePreloader), findsOneWidget);
      expect(
        tester
            .widget<CurrentPostDetailsNotes>(
              find.byType(CurrentPostDetailsNotes),
            )
            .enabled,
        isTrue,
      );
      _expectMedia(tester, postId: 1, host: 'danbooru.example');

      details.loadOriginalImage(_posts[0]);
      await _nextPage(tester);
      expect(find.byType(DanbooruInformationSection), findsNothing);
      expect(
        find.byType(DefaultInheritedInformationSection<Post>),
        findsWidgets,
      );
      _expectMedia(tester, postId: 1, host: 'e621.example');

      final expand = pageView.expandToSnapPoint();
      await tester.pumpAndSettle();
      await expand;
      pageView.zoom.value = true;

      await pageView.nextPage(duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(
        find.byType(DefaultInheritedPostActionToolbar<Post>),
        findsWidgets,
      );
      _expectMedia(tester, postId: 1, host: 'pixiv.example');
      expect(_detailsController(tester), same(details));
      expect(_pageViewController(tester), same(pageView));
      expect(_pageViewController(tester).slideshowController, same(slideshow));
      expect(details.usesOriginalImage(_posts[0]), isTrue);
      expect(details.usesOriginalImage(_posts[1]), isFalse);
      expect(pageView.sheetState.value, SheetState.expanded);
      expect(pageView.zoom.value, isTrue);

      await pageView.nextPage(duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(
        find.text('Some site-specific features are unavailable for this post.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CurrentPostDetailsNotes>(
              find.byType(CurrentPostDetailsNotes),
            )
            .enabled,
        isFalse,
      );
      expect(find.text('Tags'), findsOneWidget);
      expect(find.textContaining('unknown@'), findsNothing);
      _expectMedia(tester, postId: 1, host: '');

      expect(details.currentPage.value, 3);
      expect(details.currentPost.value, _posts[3]);
      expect(pageView.currentPage.value, 3);
      expect(harness.container.read(currentBooruConfigProvider), globalBefore);
    },
  );

  final fallbackCases =
      <
        ({
          String name,
          List<BooruConfig> configs,
          Post post,
          BooruPostPresentation presentation,
          PostPresentationFallbackReason reason,
          String effectiveUrl,
        })
      >[
        (
          name: 'missing profile',
          configs: <BooruConfig>[],
          post: _posts.first,
          presentation: const _Presentation('danbooru'),
          reason: PostPresentationFallbackReason.missingProfile,
          effectiveUrl: '',
        ),
        (
          name: 'ambiguous profile',
          configs: [_configs.first, _configs.first],
          post: _posts.first,
          presentation: const _Presentation('danbooru'),
          reason: PostPresentationFallbackReason.ambiguousProfile,
          effectiveUrl: '',
        ),
        (
          name: 'engine mismatch',
          configs: [_configs.first],
          post: _posts.first,
          presentation: const GenericPostPresentation(),
          reason: PostPresentationFallbackReason.incompatiblePresentation,
          effectiveUrl: 'https://danbooru.example',
        ),
        (
          name: 'unknown payload',
          configs: [_configs.first],
          post: _post(
            id: 5,
            booruType: BooruType.danbooru,
            host: 'https://danbooru.example',
            data: const UnknownPostData(
              typeKey: 'danbooru',
              schemaVersion: 9,
              custom: {},
              reason: UnknownPostDataReason.malformedData,
            ),
          ),
          presentation: const GenericPostPresentation(),
          reason: PostPresentationFallbackReason.incompatiblePresentation,
          effectiveUrl: 'https://danbooru.example',
        ),
      ];

  for (final fallbackCase in fallbackCases) {
    testWidgets('${fallbackCase.name} uses a safe generic page scope', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(
                initialConfigs: fallbackCase.configs,
              ),
            ),
            booruPostPresentationProvider.overrideWith(
              (ref, request) => fallbackCase.presentation,
            ),
          ],
          child: MaterialApp(
            home: PostPagePresentationScope(
              post: fallbackCase.post,
              builder: (context, ref, presentation) => Text(
                '${presentation.fallbackReason}|'
                '${ref.watchConfig.url}|'
                '${presentation.context.presentation.runtimeType}',
              ),
            ),
          ),
        ),
      );

      expect(
        find.text(
          '${fallbackCase.reason}|'
          '${fallbackCase.effectiveUrl}|'
          'GenericPostPresentation',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

PostDetailsController<Post> _detailsController(WidgetTester tester) {
  final details = tester.widget<PostDetails>(find.byType(PostDetails));
  return (details.data as PostDetailsData<Post>).controller;
}

PostDetailsPageViewController _pageViewController(WidgetTester tester) => tester
    .widget<PostDetailsPageViewScope>(find.byType(PostDetailsPageViewScope))
    .controller;

void _expectMedia(
  WidgetTester tester, {
  required int postId,
  required String host,
}) {
  final media = tester
      .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
      .firstWhere(
        (media) => (Uri.tryParse(media.config.url)?.host ?? '') == host,
      );
  expect(Uri.tryParse(media.config.url)?.host ?? '', host);
  expect(media.imageUrlBuilder?.call(media.post), '$host/media/$postId');
}

Future<void> _nextPage(WidgetTester tester) async {
  await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness()
    : container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWithValue(
            Settings.defaultSettings.copyWith(reduceAnimations: true),
          ),
          initialSettingsBooruConfigProvider.overrideWithValue(_globalConfig),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: _configs),
          ),
          booruEngineRegistryProvider.overrideWith(_createEngineRegistry),
          booruPostPresentationProvider.overrideWith((ref, request) {
            return switch (request.data) {
              DanbooruPostData() => DanbooruBuilder().postPresentation,
              E621PostData() => E621Builder().postPresentation,
              PixivPostData() => PixivBuilder().postPresentation,
              _ => const GenericPostPresentation(),
            };
          }),
          mediaUrlResolverProvider.overrideWith(
            (ref, config) =>
                _MediaResolver(Uri.tryParse(config.url)?.host ?? ''),
          ),
          booruRepoProvider.overrideWith((ref, config) => null),
          booruBuilderProvider.overrideWith((ref, config) => null),
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          hasPremiumLayoutProvider.overrideWithValue(false),
          showPremiumFeatsProvider.overrideWithValue(false),
          downloadServiceProvider.overrideWithValue(_DownloadService()),
          httpHeadersProvider.overrideWith((ref, config) => const {}),
          loggerProvider.overrideWithValue(const _Logger()),
          favoriteRepoProvider.overrideWith(
            (ref, config) => EmptyFavoriteRepository(),
          ),
        ],
      );

  final ProviderContainer container;

  Widget build() => UncontrolledProviderScope(
    container: container,
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: MixedPostDetailsPage(
          posts: _posts,
          initialIndex: 0,
          initialThumbnailUrl: null,
          scrollController: null,
          disclaimer: null,
        ),
      ),
    ),
  );

  void dispose() => container.dispose();
}

BooruEngineRegistry _createEngineRegistry(Ref ref) {
  final registry = BooruEngineRegistry();
  for (final components in [createDanbooru(), createE621(), createPixiv()]) {
    final booru = components.parser.parse();
    registry.register(
      booru.type,
      BooruEngine(
        booru: booru,
        builder: components.createBuilder(),
        repository: components.createRepository(ref),
      ),
    );
  }
  return registry;
}

final class _DownloadService implements DownloadService {
  @override
  Future<DownloadResult> download(DownloadOptions options) async =>
      DownloadEnqueued(DownloadTaskInfo(path: '', id: options.url));

  @override
  Future<bool> cancelAll(String group) async => true;

  @override
  Future<void> pauseAll(String group) async {}

  @override
  Future<void> resumeAll(String group) async {}
}

final class _Logger implements Logger {
  const _Logger();

  @override
  String getDebugName() => 'mixed post details test';

  @override
  void debug(String serviceName, String message) {}

  @override
  void error(String serviceName, String message) {}

  @override
  void info(String serviceName, String message) {}

  @override
  void verbose(String serviceName, String message) {}

  @override
  void warn(String serviceName, String message) {}
}

final _globalConfig = BooruConfig.defaultConfig(
  booruType: BooruType.gelbooru,
  url: 'https://global.example',
  customDownloadFileNameFormat: null,
);

final _configs = [
  BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://danbooru.example',
    customDownloadFileNameFormat: null,
  ),
  BooruConfig.defaultConfig(
    booruType: BooruType.e621,
    url: 'https://e621.example',
    customDownloadFileNameFormat: null,
  ),
  BooruConfig.defaultConfig(
    booruType: BooruType.pixiv,
    url: 'https://pixiv.example',
    customDownloadFileNameFormat: null,
  ),
];

final _posts = <Post>[
  _post(
    id: 1,
    booruType: BooruType.danbooru,
    host: 'https://danbooru.example',
    data: const DanbooruPostData(
      lastCommentAt: null,
      upScore: 1,
      downScore: 0,
      favCount: 2,
      approverId: null,
      generalTags: {},
      metaTags: {},
      hasChildren: false,
      hasLarge: true,
      pixelHash: '',
    ),
  ),
  _post(
    id: 1,
    booruType: BooruType.e621,
    host: 'https://e621.example',
    data: const E621PostData(
      generalTags: {},
      metaTags: {},
      speciesTags: {},
      invalidTags: {},
      loreTags: {},
      upScore: 1,
      downScore: 0,
      favCount: 2,
      isFavorited: false,
      sources: [],
      description: '',
      videoVariants: [],
    ),
  ),
  _post(
    id: 1,
    booruType: BooruType.pixiv,
    host: 'https://pixiv.example',
    data: const PixivPostData(
      illustId: 3,
      pageIndex: 0,
      pageCount: 1,
      userId: 1,
      userName: 'user',
      userAccount: 'account',
      illustType: PixivIllustType.illust,
      totalBookmarks: 1,
      totalView: 2,
      aiType: 0,
      seriesTitle: null,
      isUgoira: false,
      isRestricted: false,
    ),
  ),
  _post(
    id: 1,
    booruType: BooruType.unknown,
    host: 'https://missing.example',
    data: const UnknownPostData(
      typeKey: 'unknown',
      schemaVersion: 9,
      custom: {},
      reason: UnknownPostDataReason.unsupportedVersion,
    ),
  ),
];

Post _post({
  required int id,
  required BooruType booruType,
  required String host,
  required BooruPostData data,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: booruType,
    booruId: booruType.id,
    source: host,
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'thumbnail-$id',
    sampleImageUrl: 'sample-$id',
    originalImageUrl: 'original-$id',
    videoUrl: '',
    videoThumbnailUrl: '',
    width: 100,
    height: 100,
    format: 'jpg',
    md5: 'md5-$id',
    fileSize: 1,
    duration: 0,
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: data,
);

final class _Presentation implements BooruPostPresentation {
  const _Presentation(this.name);

  final String name;

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  bool supports(BooruPostData data) => data.typeKey == name;

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) => PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) => _PresentationProbe(name: name),
    },
    full: {
      DetailsPart.toolbar: (context) => _PresentationProbe(name: name),
    },
  );
}

class _PresentationProbe extends ConsumerWidget {
  const _PresentationProbe({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SliverToBoxAdapter(
    child: Text('$name@${ref.watchConfig.url.replaceFirst('https://', '')}'),
  );
}

final class _MediaResolver implements MediaUrlResolver {
  const _MediaResolver(this.host);

  final String host;

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      '$host/media/${post.id}';

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) => 1;

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) =>
      '$host/video/${post.id}';

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) => 1;
}
