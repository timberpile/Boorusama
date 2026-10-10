// Dart imports:
import 'dart:collection';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/details/src/types/post_details.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_controller.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_image_preloader.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_item.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_page_scaffold.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_details_page_view_scope.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_media.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/widgets/interactive_viewer_extended.dart';

void main() {
  testWidgets('mixed preloader reads only a local window in large collections', (
    tester,
  ) async {
    for (final count in [100, 10000]) {
      final posts = _CountingPosts(count);
      final pages = PostDetailsPageViewController(
        initialPage: 50,
        totalPage: count,
        checkIfLargeScreen: () => false,
        disableAnimation: true,
        viewMode: ViewMode.horizontal,
      );
      addTearDown(pages.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
          booruConfigProvider.overrideWith(
            () => BooruConfigNotifier(initialConfigs: const []),
          ),
        ],
        child: PostDetailsPageViewScope(
          controller: pages,
          child: MixedPostDetailsImagePreloader(
            posts: posts,
            child: const SizedBox(),
          ),
        ),
      ));
      expect(posts.reads, 5);
      posts.reads = 0;
      pages.currentPage.value = 51;
      expect(posts.reads, 5);
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

    await tester.pumpWidget(_app(
      details: details,
      pages: pages,
      child: Row(
        children: [
          for (var index = 0; index < _posts.length; index++)
            Expanded(child: _item(index, details, transform, initial)),
        ],
      ),
    ));
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
    final previousInterval = VisibilityDetectorController.instance.updateInterval;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    addTearDown(() {
      VisibilityDetectorController.instance.updateInterval = previousInterval;
    });
    final details = _DetailsController();
    final oldPages = _pages();
    final newPages = _pages();
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
      await tester.pumpWidget(_app(
        details: details,
        pages: oldPages,
        brightness: brightness,
        child: scaffold,
      ));
      await tester.pumpAndSettle();
    }
    details.currentPostUpdates = 0;
    oldPages.precisePage.value = 0.9;
    expect(details.currentPostUpdates, 1);

    await tester.pumpWidget(
      _app(details: details, pages: newPages, child: scaffold),
    );
    await tester.pumpAndSettle();
    details.currentPostUpdates = 0;
    oldPages.precisePage.value = 0.8;
    expect(details.currentPostUpdates, 0);
    newPages.precisePage.value = 0.9;
    expect(details.currentPostUpdates, 1);

    await tester.pumpWidget(const SizedBox());
    details.currentPostUpdates = 0;
    oldPages.precisePage.value = 0.85;
    newPages.precisePage.value = 0.85;
    expect(details.currentPostUpdates, 0);
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
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWithValue(
      Settings.defaultSettings.copyWith(reduceAnimations: true),
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
  viewMode: ViewMode.horizontal,
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

  int currentPostUpdates = 0;

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

final _posts = List<Post>.generate(3, (id) => Post(
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
    uploaderId: null,
  ),
  booruData: const UnknownPostData(
    typeKey: 'danbooru',
    schemaVersion: 9,
    custom: {},
    reason: UnknownPostDataReason.unsupportedVersion,
  ),
));

class _CountingPosts extends ListBase<Post> {
  _CountingPosts(this._length);

  final int _length;
  int reads = 0;

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('Read-only test collection');

  @override
  Post operator [](int index) {
    RangeError.checkValidIndex(index, this);
    reads++;
    return _posts[index % _posts.length];
  }

  @override
  void operator []=(int index, Post value) =>
      throw UnsupportedError('Read-only test collection');
}
