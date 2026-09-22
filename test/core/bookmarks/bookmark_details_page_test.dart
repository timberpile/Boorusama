// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
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
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/loggers.dart';

void main() {
  testWidgets('bookmark details toolbar renders inside bookmark post details', (
    tester,
  ) async {
    final post = Bookmark.empty.post;
    final detailsController = PostDetailsController<UnifiedPost>(
      scrollController: null,
      initialPage: 0,
      posts: [post],
      initialThumbnailUrl: null,
      reduceAnimations: true,
      dislclaimer: null,
      doubleTapSeekDuration: 5,
    );
    final pageViewController = PostDetailsPageViewController(
      initialPage: 0,
      totalPage: 1,
      checkIfLargeScreen: () => false,
    );
    addTearDown(detailsController.dispose);
    addTearDown(pageViewController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: const []),
          ),
          firstMatchingConfigBySourceUrlProvider.overrideWith(
            (ref, params) => null,
          ),
          imageViewerSettingsProvider.overrideWithValue(
            Settings.defaultSettings.viewer,
          ),
          showPremiumFeatsProvider.overrideWithValue(false),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: PostDetailsPageViewScope(
              controller: pageViewController,
              child: PostDetails(
                data: PostDetailsData(
                  posts: [post],
                  controller: detailsController,
                ),
                child: CustomScrollView(
                  slivers: [
                    InheritedPost(
                      presentationContext: PostPresentationContext.generic(
                        post,
                      ),
                      child: const BookmarkPostActionToolbar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(BookmarkPostActionToolbar), findsOneWidget);
  });

  testWidgets(
    'bookmark viewer uses native presentation then falls back without refetching',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      var fetchCount = 0;
      final posts = [_nativePost(), _fallbackPost()];
      final controller = PostGridController<UnifiedPost>(
        fetcher: (_) {
          fetchCount++;
          return TaskEither.right(
            PostResult(posts: posts, total: posts.length),
          );
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.refresh();

      await tester.pumpWidget(_BookmarkViewerHarness(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('native@gelbooru.example'), findsOneWidget);
      expect(find.byType(BookmarkPostActionToolbar), findsOneWidget);
      expect(find.byType(PostPresentationFallbackWarning), findsNothing);
      expect(fetchCount, 1);

      await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(find.text('native@gelbooru.example'), findsNothing);
      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(find.byType(BookmarkPostActionToolbar), findsOneWidget);
      expect(fetchCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bookmark context menu uses the post origin profile', (
    tester,
  ) async {
    final post = _nativePost();
    final controller = PostGridController<UnifiedPost>(
      fetcher: (_) => TaskEither.right(PostResult(posts: [post], total: 1)),
      blacklistedTagsFetcher: () async => const {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    final otherConfig = BooruConfig.fromJson({
      ...BooruConfig.defaultConfig(
        booruType: BooruType.gelbooruV2,
        url: 'https://other.example',
        customDownloadFileNameFormat: null,
      ).toJson(),
      'id': 99,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: [_config]),
          ),
          currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
            otherConfig.auth,
          ),
          booruPostPresentationProvider.overrideWith(
            (ref, request) => const _NativePresentation(),
          ),
        ],
        child: MaterialApp(
          home: PostGridContextMenu(
            controller: controller,
            index: 0,
            child: const Text('card'),
          ),
        ),
      ),
    );

    expect(find.text('menu@gelbooru.example'), findsOneWidget);
    expect(find.text('menu@other.example'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': 12,
});

UnifiedPost _nativePost() => _post(
  data: const GelbooruV2PostData(hasNotes: true),
  tags: const {'native'},
);

UnifiedPost _fallbackPost() => _post(
  data: const UnknownPostData(
    typeKey: 'gelbooru_v2',
    schemaVersion: 99,
    custom: {'broken': true},
    reason: UnknownPostDataReason.malformedData,
  ),
  tags: const {'cached_tag'},
  id: 2,
);

UnifiedPost _post({
  required BooruPostData data,
  required Set<String> tags,
  int id = 1,
}) => UnifiedPost(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: _config.booruId,
    source: _config.url,
    profileIdHint: _config.id,
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
    tags: tags,
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
  ),
  booruData: data,
);

class _BookmarkViewerHarness extends StatelessWidget {
  const _BookmarkViewerHarness({required this.controller});

  final PostGridController<UnifiedPost> controller;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      settingsProvider.overrideWithValue(
        Settings.defaultSettings.copyWith(reduceAnimations: true),
      ),
      initialSettingsBooruConfigProvider.overrideWithValue(_config),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [_config]),
      ),
      booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
      bookmarkProvider.overrideWith(_EmptyBookmarkNotifier.new),
      booruPostPresentationProvider.overrideWith(
        (ref, request) => switch (request.data) {
          GelbooruV2PostData() => const _NativePresentation(),
          _ => const GenericPostPresentation(),
        },
      ),
      mediaUrlResolverProvider.overrideWith(
        (ref, config) => const _MediaResolver(),
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
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: BookmarkDetailsPage(
          initialIndex: 0,
          initialThumbnailUrl: null,
          controller: controller,
        ),
      ),
    ),
  );
}

final class _EmptyBookmarkNotifier extends BookmarkLibraryNotifier {
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: const [],
    groups: const [],
    activeTarget: const BookmarkTarget.ungrouped(),
  );
}

final class _NativePresentation
    implements BooruPostPresentation, BooruPostGridContextMenuPresentation {
  const _NativePresentation();

  @override
  PostDetailsWrapperBuilder? get detailsWrapperBuilder => null;

  @override
  bool supports(BooruPostData data) => data is GelbooruV2PostData;

  @override
  PostDetailsUIBuilder detailsBuilder(UnifiedPost post) => PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) => const SliverToBoxAdapter(
        child: Text('native@gelbooru.example'),
      ),
    },
    full: {
      DetailsPart.toolbar: (context) => const SliverToBoxAdapter(
        child: Text('native@gelbooru.example'),
      ),
    },
  );

  @override
  Widget buildGridContextMenu(
    BuildContext context, {
    required UnifiedPost post,
    required int index,
    required Widget child,
  }) => Consumer(
    builder: (context, ref, _) => Text(
      'menu@${Uri.parse(ref.watchConfigAuth.url).host}',
    ),
  );
}

final class _MediaResolver implements MediaUrlResolver {
  const _MediaResolver();

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      post.sampleImageUrl;

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) => 1;

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) => post.videoUrl;

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) => 1;
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
  String getDebugName() => 'bookmark details test';

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
