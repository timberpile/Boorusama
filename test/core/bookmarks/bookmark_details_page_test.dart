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
import 'package:boorusama/boorus/gelbooru_v2/posts/post_codec.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/pages/bookmark_details_page.dart';
import 'package:boorusama/core/bookmarks/types.dart';
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
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/widgets/booru_menu_button_row.dart';
import 'package:boorusama/foundation/loggers.dart';

void main() {
  testWidgets(
    'bookmark viewer renders only the active booru toolbar',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      var fetchCount = 0;
      final posts = [_nativePost(), _fallbackPost()];
      final controller = PostGridController<Post>(
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
      expect(find.byType(BooruMenuButtonRow), findsOneWidget);
      expect(find.byType(PostPresentationFallbackWarning), findsNothing);
      expect(fetchCount, 1);

      await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(find.text('native@gelbooru.example'), findsNothing);
      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(find.byType(BooruMenuButtonRow), findsOneWidget);
      expect(fetchCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bookmark viewer keeps its opened posts after the grid changes', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    final post = _nativePost();
    final controller = PostGridController<Post>(
      fetcher: (_) => TaskEither.right(PostResult(posts: [post], total: 1)),
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

    controller.remove([post.id], (candidate) => candidate.id);
    await tester.pumpAndSettle();

    expect(find.text('native@gelbooru.example'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmark context menu uses the post origin profile', (
    tester,
  ) async {
    final post = _nativePost();
    final controller = PostGridController<Post>(
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

  testWidgets(
    'retry refreshes one legacy bookmark and preserves viewer order, identity, and groups',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final legacy = _legacyBookmark();
      final group = BookmarkGroup(
        id: 'kept',
        name: 'Kept',
        bookmarkIds: {legacy.id},
      );
      final notifier = _RecoveryBookmarkNotifier(legacy, group);
      final repositoryConfigs = <BooruConfig>[];
      final controller = _controller([
        _nativePost(id: 90),
        legacy.post,
        _nativePost(id: 92),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          initialIndex: 1,
          bookmarkNotifier: notifier,
          recoveryRepository: _RecoveryPostRepository(
            result: TaskEither.right(_nativePost(id: 91)),
          ),
          repositoryConfigs: repositoryConfigs,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('post:91'), findsOneWidget);
      expect(find.byType(PostPresentationFallbackWarning), findsNothing);
      expect(repositoryConfigs, [_config]);
      final persisted = notifier.state.requireValue.items.single;
      expect(persisted.id, legacy.id);
      expect(persisted.createdAt, legacy.createdAt);
      expect(persisted.post.id, 91);
      expect(
        notifier.state.requireValue.groups.single.bookmarkIds,
        {legacy.id},
      );
      expect(persisted.snapshot.toJson().toString(), isNot(contains('secret')));

      await tester.drag(find.byType(PageView).first, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.text('post:92'), findsOneWidget);

      await tester.drag(find.byType(PageView).first, const Offset(700, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView).first, const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(find.text('post:90'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing refreshed bookmark stays generic with a removed warning',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final legacy = _legacyBookmark();
      final notifier = _RecoveryBookmarkNotifier(
        legacy,
        BookmarkGroup(id: 'kept', name: 'Kept', bookmarkIds: {legacy.id}),
      );
      final controller = _controller([legacy.post]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          bookmarkNotifier: notifier,
          recoveryRepository: _RecoveryPostRepository(
            result: TaskEither.right(null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(
        find.text('The post is no longer available on its original site.'),
        findsOneWidget,
      );
      expect(notifier.upgrades, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy bookmark without an upstream post ID does not offer retry',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final legacy = _legacyBookmark(postId: null);
      final notifier = _RecoveryBookmarkNotifier(
        legacy,
        BookmarkGroup(id: 'kept', name: 'Kept', bookmarkIds: {legacy.id}),
      );
      final controller = _controller([legacy.post]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _BookmarkViewerHarness(
          controller: controller,
          bookmarkNotifier: notifier,
          recoveryRepository: _RecoveryPostRepository(
            result: TaskEither.right(_nativePost(id: 91)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PostPresentationFallbackWarning), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(notifier.upgrades, 0);
    },
  );
}

final _config = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: 'https://gelbooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': 12,
});

Post _nativePost({int id = 1}) => _post(
  data: const GelbooruV2PostData(hasNotes: true),
  tags: const {'native'},
  id: id,
);

Post _fallbackPost() => _post(
  data: const UnknownPostData(
    typeKey: 'gelbooru_v2',
    schemaVersion: 99,
    custom: {'broken': true},
    reason: UnknownPostDataReason.malformedData,
  ),
  tags: const {'cached_tag'},
  id: 2,
);

Post _post({
  required BooruPostData data,
  required Set<String> tags,
  int id = 1,
}) => Post(
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
  const _BookmarkViewerHarness({
    required this.controller,
    this.initialIndex = 0,
    this.bookmarkNotifier,
    this.recoveryRepository,
    this.repositoryConfigs,
  });

  final PostGridController<Post> controller;
  final int initialIndex;
  final BookmarkLibraryNotifier? bookmarkNotifier;
  final PostRepository<Post>? recoveryRepository;
  final List<BooruConfig>? repositoryConfigs;

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
      bookmarkProvider.overrideWith(
        () => bookmarkNotifier ?? _EmptyBookmarkNotifier(),
      ),
      booruPostPresentationProvider.overrideWith(
        (ref, request) => switch (request.data) {
          GelbooruV2PostData() => const _NativePresentation(),
          _ => const GenericPostPresentation(),
        },
      ),
      mediaUrlResolverProvider.overrideWith(
        (ref, config) => const _MediaResolver(),
      ),
      booruRepoProvider.overrideWith(
        (ref, config) =>
            recoveryRepository == null ? null : _AvailableBooruRepository(),
      ),
      originAwarePostRepoProvider.overrideWith((ref, config) {
        repositoryConfigs?.add(config);
        return recoveryRepository ?? EmptyPostRepository();
      }),
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
          initialIndex: initialIndex,
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
  PostDetailsUIBuilder detailsBuilder(Post post) => PostDetailsUIBuilder(
    preview: {
      DetailsPart.toolbar: (context) => SliverToBoxAdapter(
        child: Column(
          children: [
            const Text('native@gelbooru.example'),
            Text('post:${post.id}'),
            const BooruMenuButtonRow(buttons: []),
          ],
        ),
      ),
    },
    full: {
      DetailsPart.toolbar: (context) => SliverToBoxAdapter(
        child: Column(
          children: [
            const Text('native@gelbooru.example'),
            Text('post:${post.id}'),
            const BooruMenuButtonRow(buttons: []),
          ],
        ),
      ),
    },
  );

  @override
  Widget buildGridContextMenu(
    BuildContext context, {
    required Post post,
    required int index,
    required Widget child,
  }) => Consumer(
    builder: (context, ref, _) => Text(
      'menu@${Uri.parse(ref.watchConfigAuth.url).host}',
    ),
  );
}

PostGridController<Post> _controller(List<Post> posts) {
  final controller = PostGridController<Post>(
    fetcher: (_) => TaskEither.right(
      PostResult(posts: posts, total: posts.length),
    ),
    blacklistedTagsFetcher: () async => const {},
    mountedChecker: () => true,
    duplicateTracker: PostDuplicateTracker(),
    onError: (_) {},
    debounceDuration: Duration.zero,
  );
  controller.refresh();
  return controller;
}

Bookmark _legacyBookmark({int? postId = 91}) => Bookmark(
  id: 501,
  booruId: BooruType.gelbooruV2.id,
  createdAt: DateTime.utc(2025),
  updatedAt: DateTime.utc(2025, 1, 2),
  thumbnailUrl: 'thumbnail-91',
  sampleUrl: 'sample-91',
  originalUrl: 'original-91',
  sourceUrl: '${_config.url}/posts/91',
  width: 100,
  height: 100,
  md5: 'legacy-91',
  tags: const {'cached'},
  realSourceUrl: null,
  format: 'jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  postId: postId,
  metadata: const {},
);

final class _RecoveryBookmarkNotifier extends BookmarkLibraryNotifier {
  _RecoveryBookmarkNotifier(this.bookmark, this.group);

  final Bookmark bookmark;
  final BookmarkGroup group;
  var upgrades = 0;

  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: [bookmark],
    groups: [group],
    activeTarget: const BookmarkTarget.ungrouped(),
  );

  @override
  Future<void> upgradeBookmarkSnapshot(Bookmark bookmark, Post post) async {
    upgrades++;
    final snapshot = const StoredPostCodec().encode(
      post,
      dataCodec: const GelbooruV2PostCodec(),
    );
    final upgraded = Bookmark.fromSnapshot(
      id: bookmark.id,
      createdAt: bookmark.createdAt,
      updatedAt: DateTime.utc(2026),
      snapshot: snapshot,
      post: post,
      postId: post.id,
      sourceUrl: bookmark.sourceUrl,
    );
    state = AsyncValue.data(
      BookmarkLibraryState(
        bookmarks: [upgraded],
        groups: [group],
        activeTarget: const BookmarkTarget.ungrouped(),
      ),
    );
  }
}

final class _RecoveryPostRepository extends PostRepository<Post> {
  _RecoveryPostRepository({required this.result});

  final PostOrError<Post> result;

  @override
  PostOrError<Post> getPost(PostId id, {PostFetchOptions? options}) => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AvailableBooruRepository implements BooruRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
