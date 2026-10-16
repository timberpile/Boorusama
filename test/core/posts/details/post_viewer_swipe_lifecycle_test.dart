// Dart imports:
import 'dart:collection';

// Flutter imports:
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/performance.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:dio/dio.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_image_preloader.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_item.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_page_scaffold.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_media.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/media_preload/providers.dart';
import 'package:boorusama/core/posts/media_preload/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/widgets/interactive_viewer_extended.dart';

void main() {
  testWidgets(
    'mixed preloader dispatches the same bounded window at both sizes',
    (tester) async {
      final counts = <List<int>>[];
      addTearDown(performanceRecorder.clear);
      for (final count in [100, 10000]) {
        performanceRecorder.start();
        final posts = _CountingPosts(count, postAt: _mixedPost);
        final pages = PostDetailsPageViewController(
          initialPage: 50,
          totalPage: count,
          checkIfLargeScreen: () => false,
          disableAnimation: true,
        );
        addTearDown(pages.dispose);
        final requests = <String>[];
        final reads = <int>[];
        await tester.pumpWidget(
          _preloadApp(pages: pages, posts: posts, requests: requests),
        );
        reads.add(posts.reads);
        expect(
          requests,
          unorderedEquals([
            '${_otherConfig.url}:thumb-49',
            '${_otherConfig.url}:thumb-51',
          ]),
        );
        for (final page in [51, 52, 51, 50, 80, 50]) {
          posts.reads = 0;
          pages.currentPage.value = page;
          await tester.pump();
          reads.add(posts.reads);
        }
        expect(requests, contains('${_config.url}:sample-52'));
        expect(requests, isNot(contains('${_config.url}:original-52')));
        expect(reads.every((count) => count <= 6), isTrue);
        final summary = performanceRecorder.snapshot()['summary']! as Map;
        final counters = summary['counters'] as Map;
        expect(counters['mixedCollectionSize']['max'], count);
        expect(counters['mixedResolvedPosts']['samples'], reads.length);
        expect(counters['mixedResolvedPosts']['max'], lessThanOrEqualTo(6));
        expect(
          counters['mixedResolvedPosts']['total'],
          reads.reduce((a, b) => a + b),
        );
        performanceRecorder.stop();
        counts.add(reads);
        await tester.pumpWidget(const SizedBox());
      }
      expect(counts[0], counts[1]);
    },
  );

  for (final mixed in [false, true]) {
    testWidgets(
      'preloader rebinds replacement controller and disposes: mixed $mixed',
      (tester) async {
        final posts = _CountingPosts(100, postAt: _mixedPost);
        final oldPages = _pages();
        final newPages = _pages();
        addTearDown(oldPages.dispose);
        addTearDown(newPages.dispose);
        final requests = <String>[];
        Widget build(PostDetailsPageViewController pages) => _preloadApp(
          pages: pages,
          posts: posts,
          requests: requests,
          mixed: mixed,
        );
        await tester.pumpWidget(build(oldPages));
        await tester.pumpWidget(build(newPages));
        posts.reads = 0;
        oldPages.currentPage.value = 1;
        expect(posts.reads, 0);
        newPages.currentPage.value = 1;
        expect(posts.reads, greaterThan(0));
        await tester.pumpWidget(const SizedBox());
        posts.reads = 0;
        newPages.currentPage.value = 2;
        expect(posts.reads, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mixed preloader keeps video and original-quality prefetch to thumbnails',
    (tester) async {
      final pages = _pages();
      addTearDown(pages.dispose);
      final requests = <String>[];
      final posts = [_post(0), _post(1, format: 'mp4'), _post(2)];
      await tester.pumpWidget(
        _preloadApp(
          pages: pages,
          posts: posts,
          requests: requests,
          resolver: const _OriginalResolver(),
        ),
      );
      expect(requests, ['${_config.url}:video-thumb-1']);
      pages.currentPage.value = 1;
      await tester.pump();
      expect(
        requests,
        unorderedEquals([
          '${_config.url}:video-thumb-1',
          '${_config.url}:thumb-0',
          '${_config.url}:thumb-2',
        ]),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('missing and ambiguous profiles dispatch no preloads', (
    tester,
  ) async {
    final pages = _pages();
    addTearDown(pages.dispose);
    final requests = <String>[];
    for (final configs in <List<BooruConfig>>[
      [],
      [_config, _config.copyWith(login: 'ambiguous')],
    ]) {
      await tester.pumpWidget(
        _preloadApp(
          pages: pages,
          posts: _posts,
          requests: requests,
          configs: configs,
        ),
      );
      expect(requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('settlement only rebuilds items whose active state changes', (
    tester,
  ) async {
    final details = _DetailsController()..currentSettledPage.value = 0;
    final pages = _pages();
    final transform = TransformationController();
    final initial = ValueNotifier(false);
    addTearDown(details.dispose);
    addTearDown(pages.dispose);
    addTearDown(transform.dispose);
    addTearDown(initial.dispose);

    await tester.pumpWidget(
      _app(
        details: details,
        pages: pages,
        child: Row(
          children: [
            for (var index = 0; index < _posts.length; index++)
              Expanded(child: _item(index, details, transform, initial)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    List<PostMedia<Post>> media() => tester
        .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
        .toList();
    List<bool> panConstraints() => tester
        .widgetList<InteractiveViewerExtended>(
          find.byType(InteractiveViewerExtended),
        )
        .map((viewer) => viewer.constrainPanToContent)
        .toList();

    final before = media();
    details.currentSettledPage.value = 1;
    await tester.pump();
    final after = media();
    expect(after[2], same(before[2]));
    expect(after.map((item) => item.isPageSettled), [false, true, false]);
    expect(panConstraints(), [false, true, false]);

    details.currentSettledPage.value = 2;
    await tester.pump();
    expect(media()[0], same(after[0]));
    expect(panConstraints(), [false, false, true]);

    details.currentSettledPage.value = null;
    await tester.pump();
    expect(media().map((item) => item.isPageSettled), [false, false, false]);
    expect(panConstraints(), [false, false, false]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reused item follows its new index and controller', (
    tester,
  ) async {
    final oldDetails = _DetailsController()..currentSettledPage.value = 0;
    final newDetails = _DetailsController()..currentSettledPage.value = 1;
    final pages = _pages();
    final transform = TransformationController();
    final initial = ValueNotifier(false);
    addTearDown(oldDetails.dispose);
    addTearDown(newDetails.dispose);
    addTearDown(pages.dispose);
    addTearDown(transform.dispose);
    addTearDown(initial.dispose);

    Widget build(int index, _DetailsController details) => _app(
      details: details,
      pages: pages,
      child: _item(index, details, transform, initial),
    );
    PostMedia<Post> media() =>
        tester.widget<PostMedia<Post>>(find.byType(PostMedia<Post>));

    await tester.pumpWidget(build(0, oldDetails));
    await tester.pumpAndSettle();
    expect(media().isPageSettled, isTrue);
    await tester.pumpWidget(build(1, oldDetails));
    expect(media().isPageSettled, isFalse);
    await tester.pumpWidget(build(1, newDetails));
    expect(media().isPageSettled, isTrue);
    final before = media();

    oldDetails.currentSettledPage.value = 1;
    await tester.pump();
    expect(media(), same(before));
    newDetails.currentSettledPage.value = 2;
    await tester.pump();
    expect(media().isPageSettled, isFalse);
    expect(
      tester
          .widget<InteractiveViewerExtended>(
            find.byType(InteractiveViewerExtended),
          )
          .constrainPanToContent,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dependency changes and replacement keep one scroll callback', (
    tester,
  ) async {
    final previousInterval =
        VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = previousInterval;
    });
    final details = _DetailsController();
    final oldPages = _NavigationPages();
    final newPages = _NavigationPages();
    final transform = TransformationController();
    final initial = ValueNotifier(false);
    addTearDown(details.dispose);
    addTearDown(oldPages.dispose);
    addTearDown(newPages.dispose);
    addTearDown(transform.dispose);
    addTearDown(initial.dispose);

    final scaffold = PostDetailsPageScaffold<Post>(
      posts: _posts,
      controller: details,
      gestureConfig: null,
      layoutConfig: null,
      itemBuilder: (_, _) => const SizedBox.expand(),
      transformController: transform,
      isInitPage: initial,
      actions: const [],
      postGestureHandlerBuilder: null,
      uiBuilder: null,
      enableViewerTransformations: false,
    );
    for (final brightness in [
      Brightness.light,
      Brightness.dark,
      Brightness.light,
    ]) {
      await tester.pumpWidget(
        _app(
          details: details,
          pages: oldPages,
          brightness: brightness,
          volumeNavigation: true,
          child: scaffold,
        ),
      );
      await tester.pumpAndSettle();
    }
    details.currentPostUpdates = 0;
    oldPages.precisePage.value = 0.9;
    expect(details.currentPostUpdates, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    expect(oldPages.nextCalls, 1);

    await tester.pumpWidget(
      _app(
        details: details,
        pages: newPages,
        child: scaffold,
        volumeNavigation: true,
      ),
    );
    await tester.pumpAndSettle();
    details.currentPostUpdates = 0;
    oldPages.precisePage.value = 0.8;
    expect(details.currentPostUpdates, 0);
    newPages.precisePage.value = 0.9;
    expect(details.currentPostUpdates, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    expect(oldPages.nextCalls, 1);
    expect(newPages.nextCalls, 1);

    await tester.pumpWidget(const SizedBox());
    details.currentPostUpdates = 0;
    oldPages.precisePage.value = 0.85;
    newPages.precisePage.value = 0.85;
    expect(details.currentPostUpdates, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    expect(oldPages.nextCalls, 1);
    expect(newPages.nextCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

PostDetailsItem<Post> _item(
  int index,
  PostDetailsController<Post> details,
  TransformationController transform,
  ValueNotifier<bool> initial,
) => PostDetailsItem<Post>(
  index: index,
  posts: _posts,
  transformController: transform,
  isInitPageListenable: initial,
  imageCacheManager: null,
  detailsController: details,
  authConfig: _config.auth,
  viewerConfig: _config.viewer,
  gestureConfig: null,
  imageUrlBuilder: (post) => post.sampleImageUrl,
  mediaAspectRatioBuilder: (_) => 1,
  videoAspectRatioBuilder: (_) => 1,
);

Widget _app({
  required PostDetailsController<Post> details,
  required PostDetailsPageViewController pages,
  required Widget child,
  Brightness brightness = Brightness.light,
  bool volumeNavigation = false,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWithValue(
      Settings.defaultSettings.copyWith(
        reduceAnimations: true,
        volumeKeyViewerNavigation: volumeNavigation,
      ),
    ),
    initialSettingsBooruConfigProvider.overrideWithValue(_config),
    booruConfigProvider.overrideWith(
      () => BooruConfigNotifier(initialConfigs: [_config]),
    ),
    automaticMediaLoadingEnabledProvider.overrideWithValue(false),
    booruRepoProvider.overrideWith((ref, config) => null),
    hasPremiumLayoutProvider.overrideWithValue(false),
    showPremiumFeatsProvider.overrideWithValue(false),
    colorSchemeProvider.overrideWithValue(
      ColorScheme.fromSeed(seedColor: Colors.blue),
    ),
  ],
  child: MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      extensions: const [KurumiExtendedColorScheme()],
    ),
    builder: (context, child) => KurumiTheme(
      data: KurumiThemeData.fromMaterial(Theme.of(context)),
      child: TranslationProvider(child: child!),
    ),
    home: PostDetails(
      data: PostDetailsData<Post>(posts: _posts, controller: details),
      child: PostDetailsPageViewScope(controller: pages, child: child),
    ),
  ),
);

PostDetailsPageViewController _pages() => PostDetailsPageViewController(
  initialPage: 0,
  totalPage: _posts.length,
  checkIfLargeScreen: () => false,
  disableAnimation: true,
);

class _DetailsController extends PostDetailsController<Post> {
  _DetailsController()
    : super(
        scrollController: null,
        initialPage: 0,
        posts: _posts,
        initialThumbnailUrl: null,
        reduceAnimations: true,
        dislclaimer: null,
        doubleTapSeekDuration: 10,
      );

  var currentPostUpdates = 0;

  @override
  void updateCurrentPost(int page) {
    currentPostUpdates++;
    super.updateCurrentPost(page);
  }
}

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://danbooru.example',
  customDownloadFileNameFormat: null,
);

final _posts = List<Post>.generate(3, _post);

Post _post(int id, {String format = 'jpg'}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: 'https://danbooru.example',
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: 'thumb-$id',
    sampleImageUrl: 'sample-$id',
    originalImageUrl: 'original-$id',
    videoUrl: '',
    videoThumbnailUrl: 'video-thumb-$id',
    width: 100,
    height: 100,
    format: format,
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
  booruData: const UnknownPostData(
    typeKey: 'danbooru',
    schemaVersion: 9,
    custom: {},
    reason: UnknownPostDataReason.unsupportedVersion,
  ),
);

class _CountingPosts extends ListBase<Post> {
  _CountingPosts(this._length, {Post Function(int)? postAt})
    : _postAt = postAt ?? ((index) => _posts[index % _posts.length]);

  final Post Function(int) _postAt;

  final int _length;
  var reads = 0;

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('Read-only test collection');

  @override
  Post operator [](int index) {
    RangeError.checkValidIndex(index, this);
    reads++;
    return _postAt(index);
  }

  @override
  void operator []=(int index, Post value) =>
      throw UnsupportedError('Read-only test collection');
}

final _otherConfig = _config.copyWith(
  url: 'https://other.example',
  login: 'other',
);

Post _mixedPost(int index) => _post(index).copyWith(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: index.isEven ? _config.url : _otherConfig.url,
  ),
);

Widget _preloadApp({
  required PostDetailsPageViewController pages,
  required List<Post> posts,
  required List<String> requests,
  bool mixed = true,
  List<BooruConfig>? configs,
  MediaUrlResolver resolver = const SampleMediaUrlResolver(),
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWithValue(Settings.defaultSettings),
    initialSettingsBooruConfigProvider.overrideWithValue(_config),
    automaticMediaLoadingEnabledProvider.overrideWithValue(true),
    booruConfigProvider.overrideWith(
      () => BooruConfigNotifier(
        initialConfigs: configs ?? [_config, _otherConfig],
      ),
    ),
    booruRepoProvider.overrideWith((ref, config) => null),
    gridThumbnailSettingsProvider.overrideWith(
      (ref, auth) => const GridThumbnailSettings(
        imageQuality: ImageQuality.low,
        animatedPostsDefaultState: AnimatedPostsDefaultState.static,
        gridSize: GridSize.normal,
      ),
    ),
    mediaUrlResolverProvider.overrideWith(
      (ref, auth) => resolver,
    ),
    dioForWidgetProvider.overrideWith((ref, auth) => Dio()),
    preloadManagerProvider.overrideWith((ref, params) {
      final manager = PreloadManager(
        preloader: (url, token) async {
          requests.add('${params.authConfig.url}:$url');
        },
      );
      ref.onDispose(manager.dispose);
      return manager;
    }),
  ],
  child: PostDetailsPageViewScope(
    controller: pages,
    child: mixed
        ? MixedPostDetailsImagePreloader(posts: posts, child: const SizedBox())
        : PostDetailsImagePreloader<Post>(
            posts: posts,
            authConfig: _config.auth,
            imageUrlBuilder: (post) => post.sampleImageUrl,
            child: const SizedBox(),
          ),
  ),
);

class _OriginalResolver extends SampleMediaUrlResolver {
  const _OriginalResolver();

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      post.originalImageUrl;
}

class _NavigationPages extends PostDetailsPageViewController {
  _NavigationPages()
    : super(
        initialPage: 0,
        totalPage: _posts.length,
        checkIfLargeScreen: () => false,
        disableAnimation: true,
      );

  var nextCalls = 0;

  @override
  Future<void> nextPage({Duration? duration, Curve? curve}) async {
    nextCalls++;
  }
}
