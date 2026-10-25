// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru/posts/post_codec.dart';
import 'package:boorusama/boorus/gelbooru/posts/types.dart';
import 'package:boorusama/boorus/gelbooru/gelbooru.dart';
import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/widgets.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/queries/types.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/core/search/search/widgets.dart';
import 'package:boorusama/core/search/selected_tags/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/loggers.dart';

import '../../../support/fakes/memory_app_file_system.dart';

void main() {
  testWidgets('server favorites use native cards and open the mixed viewer', (
    tester,
  ) async {
    DetailsRouteContext? opened;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => FavoritesPageScaffold(
            favQueryBuilder: null,
            fetcher: (_) => TaskEither.right(
              PostResult(
                posts: [
                  gelbooruPostFromRecord(GelbooruPostRecord.empty(), _origin),
                ],
                total: 1,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, state) {
            opened = state.extra! as DetailsRouteContext;
            return const Scaffold(body: Text('mixed viewer'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_TestApp(router: router, globalConfig: _config));
    await tester.pumpAndSettle();

    expect(find.text('native@gelbooru.example'), findsOneWidget);
    expect(find.text('native context menu'), findsOneWidget);
    final card = tester.widget<PostGridItem>(find.byType(PostGridItem));
    expect(card.post, isA<Post>());
    expect(
      card.post.origin.profileIdHint,
      '00000000-0000-4000-8000-00000000002a',
    );

    await tester.tap(find.byType(ImageGridItem));
    await tester.pumpAndSettle();

    expect(find.text('mixed viewer'), findsOneWidget);
    expect(opened?.useMixedViewer, isTrue);
    expect(opened?.config, _config);
    expect(opened?.posts.single, isA<Post>());
  });

  testWidgets('search uses native cards and opens the mixed viewer', (
    tester,
  ) async {
    DetailsRouteContext? opened;
    final post = gelbooruPostFromRecord(GelbooruPostRecord.empty(), _origin);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => CurrentBooruConfigScope(
            config: _config,
            child: const Scaffold(
              body: DefaultSearchPage(
                params: SearchParams(query: 'cat', page: 1),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, state) {
            opened = state.extra! as DetailsRouteContext;
            return const Scaffold(body: Text('mixed viewer'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _TestApp(
        router: router,
        globalConfig: _globalConfig,
        originAwareRepository: _OriginAwareRepository(post),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('native@gelbooru.example'), findsOneWidget);
    expect(find.text('native context menu'), findsOneWidget);
    final card = tester.widget<PostGridItem>(find.byType(PostGridItem));
    expect(card.post, same(post));

    await tester.tap(find.byType(ImageGridItem));
    await tester.pumpAndSettle();

    expect(find.text('mixed viewer'), findsOneWidget);
    expect(opened?.useMixedViewer, isTrue);
    expect(opened?.config, _config);
    expect(opened?.posts.single, same(post));
  });
}

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooru,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-00000000002a',
});

final _globalConfig = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://global.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': '00000000-0000-4000-8000-00000000002b',
});

final _origin = PostOrigin.fromSource(
  booruType: BooruType.gelbooru,
  booruId: _config.booruId,
  source: _config.url,
  profileIdHint: _config.id,
);

final class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.router,
    required this.globalConfig,
    this.originAwareRepository,
  });

  final GoRouter router;
  final PostRepository<Post>? originAwareRepository;
  final BooruConfig globalConfig;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      currentReadOnlyBooruConfigProvider.overrideWithValue(globalConfig),
      currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
        globalConfig.auth,
      ),
      currentReadOnlyBooruConfigSearchProvider.overrideWithValue(
        globalConfig.search,
      ),
      currentReadOnlyBooruConfigFilterProvider.overrideWithValue(
        globalConfig.filter,
      ),
      currentReadOnlyBooruConfigGestureProvider.overrideWithValue(
        globalConfig.postGestures,
      ),
      currentReadOnlyBooruConfigDownloadProvider.overrideWithValue(
        globalConfig.download,
      ),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(
          initialConfigs: globalConfig.id == _config.id
              ? [_config]
              : [globalConfig, _config],
        ),
      ),
      settingsProvider.overrideWithValue(Settings.defaultSettings),
      settingsNotifierProvider.overrideWith(
        () => SettingsNotifier(Settings.defaultSettings),
      ),
      imageListingSettingsProvider.overrideWithValue(
        Settings.defaultSettings.listing,
      ),
      booruPostPresentationProvider.overrideWith(
        (ref, request) => const _Presentation(),
      ),
      if (originAwareRepository case final repository?)
        originAwarePostRepoProvider.overrideWith((ref, config) => repository),
      gridThumbnailUrlGeneratorProvider.overrideWith(
        (ref, config) => const _ThumbnailGenerator(),
      ),
      booruBuilderProvider.overrideWith((ref, config) => null),
      booruRepoProvider.overrideWith((ref, config) => null),
      booruEngineRegistryProvider.overrideWith((ref) {
        final components = createGelbooru();
        final booru = components.parser.parse();
        return BooruEngineRegistry()..register(
          booru.type,
          BooruEngine(
            booru: booru,
            builder: components.createBuilder(),
            repository: components.createRepository(ref),
          ),
        );
      }),
      analyticsProvider.overrideWith((ref) => null),
      downloadServiceProvider.overrideWithValue(_DownloadService()),
      httpHeadersProvider.overrideWith((ref, config) => const {}),
      loggerProvider.overrideWithValue(const _Logger()),
      blacklistTagsProvider.overrideWith((ref, config) => {}),
      blacklistTagEntriesProvider.overrideWith((ref, config) => {}),
      canFavoriteProvider.overrideWith((ref, config) => false),
      automaticMediaLoadingEnabledProvider.overrideWithValue(false),
      appFileSystemProvider.overrideWithValue(MemoryAppFileSystem()),
    ],
    child: BooruLocalization(
      child: MaterialApp.router(
        routerConfig: router,
        theme: Kurumi.themeFrom(
          KurumiThemeMode.light,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          systemDarkMode: false,
        ).withBoorusamaColors(),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
      ),
    ),
  );
}

final class _OriginAwareRepository implements PostRepository<Post> {
  const _OriginAwareRepository(this.post);

  final Post post;

  @override
  TagQueryComposer get tagComposer => EmptyTagQueryComposer();

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(PostResult(posts: [post], total: 1));

  @override
  PostsOrError<Post> getPostsFromController(
    SearchTagSet controller,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(PostResult(posts: [post], total: 1));

  @override
  PostOrError<Post> getPost(
    PostId id, {
    PostFetchOptions? options,
  }) => TaskEither.right(post);
}

final class _Presentation
    implements
        BooruPostPresentation,
        BooruPostGridPresentation,
        BooruPostGridContextMenuPresentation {
  const _Presentation();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  bool supports(BooruPostData data) => data.typeKey == 'gelbooru';

  @override
  PostDetailsUIBuilder detailsBuilder(Post post) =>
      const PostDetailsUIBuilder();

  @override
  PostGridItemAdditions buildGridItemAdditions(
    BuildContext context, {
    required WidgetRef ref,
    required Post post,
    required BooruConfigAuth config,
  }) => PostGridItemAdditions(
    quickActionButton: Text('native@${Uri.parse(config.url).host}'),
  );

  @override
  Widget buildGridContextMenu(
    BuildContext context, {
    required Post post,
    required int index,
    int? selectionIndex,
    required Widget child,
  }) => Stack(
    children: [
      child,
      const Text('native context menu'),
    ],
  );
}

final class _ThumbnailGenerator implements GridThumbnailUrlGenerator {
  const _ThumbnailGenerator();

  @override
  GridThumbnailMedia resolve(
    Post post, {
    required GridThumbnailSettings settings,
  }) => const GridThumbnailMedia(url: 'thumbnail', aspectRatio: 1);
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
  String getDebugName() => 'favorite post presentation test';

  @override
  void debug(String serviceName, String message, {String? sensitiveMessage}) {}

  @override
  void error(String serviceName, String message, {String? sensitiveMessage}) {}

  @override
  void info(String serviceName, String message, {String? sensitiveMessage}) {}

  @override
  void verbose(
    String serviceName,
    String message, {
    String? sensitiveMessage,
  }) {}

  @override
  void warn(String serviceName, String message, {String? sensitiveMessage}) {}
}
