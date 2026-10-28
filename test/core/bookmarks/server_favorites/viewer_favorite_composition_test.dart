import 'dart:async';
import 'dart:typed_data';

import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/danbooru/posts/details/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/details/widgets.dart';
import 'package:boorusama/boorus/danbooru/posts/favorites/src/data/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/votes/providers.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/gesture/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/votes/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/src/colors.dart';
import 'package:boorusama/core/widgets/interactive_viewer_extended.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'test_support.dart';

void main() {
  for (final mixed in [true, false]) {
    for (final scenario in [
      (expanded: false, gesture: false),
      (expanded: true, gesture: false),
      (expanded: false, gesture: true),
    ]) {
      final expanded = scenario.expanded;
      final gesture = scenario.gesture;
      testWidgets(
        'actual ${mixed ? 'mixed' : 'native'} viewer updates favorite controls (expanded: $expanded, gesture: $gesture)',
        (tester) async {
          tester.view.physicalSize = const Size(500, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final previousInterval =
              VisibilityDetectorController.instance.updateInterval;
          VisibilityDetectorController.instance.updateInterval = Duration.zero;
          addTearDown(
            () => VisibilityDetectorController.instance.updateInterval =
                previousInterval,
          );
          final h = FavoriteHarness();
          // Native-I/O completion signals must run outside the test's fake clock.
          final server = (await tester.runAsync(() async => _Server()))!;
          await tester.runAsync(
            () => h.open(
              extraOverrides: (initialProfile) {
                final profile = BooruConfig.fromJson({
                  ...initialProfile.toJson(),
                  'postGestures': const PostGestureConfig.undefined()
                      .withFulviewDoubleTap(kToggleFavoriteAction)
                      .toJson(),
                });
                h.profile = profile;
                h.profiles.profiles = [profile];
                return [
                  danbooruClientProvider(profile.auth).overrideWithValue(
                    DanbooruClient(
                      baseUrl: profile.url,
                      dio: Dio(BaseOptions(baseUrl: profile.url))
                        ..httpClientAdapter = server,
                    ),
                  ),
                  favoriteRepoProvider(profile.auth).overrideWith(
                    (ref) => createConfirmedFavoriteRepository(
                      ref,
                      profile.auth,
                      ref.watch(danbooruFavoriteRepoProvider(profile.auth)),
                    ),
                  ),
                  initialSettingsBooruConfigProvider.overrideWithValue(profile),
                  booruEngineRegistryProvider.overrideWith(_registry),
                  booruPostPresentationProvider.overrideWith(
                    (ref, request) => const _Presentation(),
                  ),
                  booruBuilderProvider.overrideWith(
                    (ref, config) => _ToolbarBuilder(),
                  ),
                  automaticMediaLoadingEnabledProvider.overrideWithValue(false),
                  defaultImageCacheManagerProvider.overrideWithValue(
                    _ImageCache(),
                  ),
                  mediaUrlResolverProvider.overrideWith(
                    (ref, auth) => const SampleMediaUrlResolver(),
                  ),
                  danbooruMediaUrlResolverProvider.overrideWith(
                    (ref, auth) => const SampleMediaUrlResolver(),
                  ),
                  dioForWidgetProvider.overrideWith(
                    (ref, config) => Dio()..httpClientAdapter = server,
                  ),
                  httpHeadersProvider.overrideWith((ref, config) => const {}),
                  deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
                  appPlatformProvider.overrideWithValue(AppPlatform.android),
                  hasPremiumLayoutProvider.overrideWithValue(false),
                  showPremiumFeatsProvider.overrideWithValue(false),
                  colorSchemeProvider.overrideWithValue(
                    ColorScheme.fromSeed(seedColor: Colors.blue),
                  ),
                  loggerProvider.overrideWithValue(const _Logger()),
                  downloadServiceProvider.overrideWithValue(_DownloadService()),
                ];
              },
            ),
          );
          addTearDown(h.close);
          final container = h.container;
          final group = await tester.runAsync(() async {
            final group = await container
                .read(bookmarkProvider.notifier)
                .createGroup('Favorites');
            await container
                .read(serverFavoriteSettingsProvider.notifier)
                .setGlobal(group.id);
            return group;
          });
          await tester.runAsync(() async {
            container.read(favoritesProvider(h.profile.auth));
            container.read(
              profileFavoriteRepoProvider((h.profile.auth, h.profile.id)),
            );
            container.read(serverFavoriteFetchProvider.notifier);
          });
          final post = h.post(1);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: BooruLocalization(
                child: MaterialApp(
                  theme: ThemeData(
                    extensions: const [KurumiExtendedColorScheme()],
                  ).withBoorusamaColors(),
                  builder: (context, child) => MaterialUiCompatibilityBridge(
                    child: KurumiTheme(
                      data: KurumiThemeData.fromMaterial(Theme.of(context)),
                      child: child!,
                    ),
                  ),
                  home: mixed
                      ? MixedPostDetailsPage(
                          posts: [post],
                          initialIndex: 0,
                          initialThumbnailUrl: null,
                          scrollController: null,
                          disclaimer: null,
                        )
                      : CurrentBooruConfigScope(
                          config: h.profile,
                          child: PostDetailsScope<Post>(
                            posts: [post],
                            initialIndex: 0,
                            initialThumbnailUrl: null,
                            scrollController: null,
                            dislclaimer: null,
                            child: const DanbooruPostDetailsPage(),
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final page = tester.element(
            find.byType(PostDetailsPageScaffold<Post>),
          );
          final pageController = PostDetailsPageViewScope.of(page);
          if (expanded) {
            unawaited(pageController.expandToSnapPoint());
            await tester.pumpAndSettle();
          }
          final favorite = find.byType(FavoritePostButton).hitTestable();
          expect(favorite, findsOneWidget);
          final toolbar = find.ancestor(
            of: favorite,
            matching: find.byType(DanbooruPostActionToolbar),
          );
          final scoped = ProviderScope.containerOf(tester.element(toolbar));
          expect(
            scoped.read(favoritesProvider(h.profile.auth).notifier),
            same(container.read(favoritesProvider(h.profile.auth).notifier)),
          );
          expect(
            scoped.read(bookmarkProvider.notifier),
            same(container.read(bookmarkProvider.notifier)),
          );
          expect(
            scoped.read(serverFavoriteSettingsProvider.notifier),
            same(container.read(serverFavoriteSettingsProvider.notifier)),
          );
          expect(
            scoped.read(serverFavoriteFetchProvider.notifier),
            same(container.read(serverFavoriteFetchProvider.notifier)),
          );
          final initialViewer = tester.state(
            find.byType(PostDetailsPageScaffold<Post>),
          );
          final image = find.byType(InteractiveViewerExtended).hitTestable();
          if (gesture) {
            expect(image, findsOneWidget);
            expect(
              tester.widget<InteractiveViewerExtended>(image).onDoubleTap,
              isNotNull,
            );
            await tester.tap(image);
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.runAsync(() async {
            await tester.tap(gesture ? image : favorite);
            await server.postStarted.future.timeout(
              const Duration(seconds: 15),
            );
          });
          await tester.pumpAndSettle();
          expect(
            container.read(favoriteProvider((h.profile.auth, 1))),
            isTrue,
            reason: 'optimistic state changes before the held HTTP response',
          );
          expect(
            tester.widget<FavoritePostButton>(favorite).isFaved,
            isTrue,
            reason: 'the actual viewer subscribes to optimism',
          );
          await tester.runAsync(() async {
            final projected = Completer<void>();
            final subscription = container.listen(bookmarkProvider, (_, value) {
              final containsPost =
                  value.valueOrNull
                      ?.membershipsFor(
                        bookmarkIdentityForPost(
                          post,
                          h.profile.booruIdHint,
                        ),
                      )
                      .contains(group!.id) ??
                  false;
              if (containsPost && !projected.isCompleted) {
                projected.complete();
              }
            });
            server.releasePost.complete();
            // Await publication of the durable favorite projection.
            try {
              await projected.future.timeout(const Duration(seconds: 15));
            } finally {
              subscription.close();
            }
          });
          await tester.pumpAndSettle();
          expect(
            tester.state(find.byType(PostDetailsPageScaffold<Post>)),
            same(initialViewer),
          );
          final identity = bookmarkIdentityForPost(post, h.profile.booruIdHint);
          expect(
            container
                .read(bookmarkProvider)
                .requireValue
                .membershipsFor(identity),
            {group!.id},
          );
          expect(
            container
                .read(danbooruPostVoteProvider((h.profile.auth, 1)))
                ?.voteState,
            VoteState.upvoted,
          );
          for (final symbol in [Symbols.favorite, Symbols.bookmark]) {
            expect(
              tester.widget<Icon>(find.byIcon(symbol).hitTestable()).fill,
              symbol == Symbols.bookmark ? 0 : 1,
            );
          }
          expect(
            tester
                .widget<Icon>(find.byIcon(Symbols.arrow_upward).hitTestable())
                .color,
            isNotNull,
          );
          expect(
            server.requests.where(
              (request) => request == 'POST /favorites.json',
            ),
            hasLength(1),
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

// Keep actual viewer scopes, controls, and gesture handlers; omit unrelated
// metadata services while preserving a scrollable expanded detail body.
final _toolbar = PostDetailsUIBuilder(
  preview: {
    DetailsPart.toolbar: (_) => const DanbooruInheritedPostActionToolbar(),
  },
  full: {
    DetailsPart.toolbar: (_) => const DanbooruInheritedPostActionToolbar(),
    DetailsPart.tags: (_) =>
        const SliverToBoxAdapter(child: SizedBox(height: 600)),
  },
);

class _ToolbarBuilder extends DanbooruBuilder {
  @override
  PostDetailsUIBuilder get postDetailsUIBuilder => _toolbar;
}

class _Presentation implements BooruPostPresentation {
  const _Presentation();
  @override
  bool supports(BooruPostData data) => true;
  @override
  PostDetailsUIBuilder detailsBuilder(Post post) => _toolbar;
  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;
}

BooruEngineRegistry _registry(Ref ref) {
  final components = createDanbooru();
  final booru = components.parser.parse();
  return BooruEngineRegistry()..register(
    booru.type,
    BooruEngine(
      booru: booru,
      builder: components.createBuilder(),
      repository: components.createRepository(ref),
    ),
  );
}

class _Server implements HttpClientAdapter {
  final requests = <String>[];
  final postStarted = Completer<void>();
  final releasePost = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    if (options.method == 'POST' && options.path == '/favorites.json') {
      postStarted.complete();
      await releasePost.future;
      return ResponseBody.fromString(
        '{}',
        201,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    throw StateError('Unexpected request: ${options.method} ${options.path}');
  }

  @override
  void close({bool force = false}) {}
}

class _DownloadService implements DownloadService {
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

class _Logger implements Logger {
  const _Logger();
  @override
  String getDebugName() => 'viewer favorite composition';
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

class _ImageCache implements ImageCacheManager {
  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;
  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      null;
  @override
  String generateCacheKey(String url, {String? customKey}) => url;
  @override
  Future<void> saveFile(String key, Uint8List bytes) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
