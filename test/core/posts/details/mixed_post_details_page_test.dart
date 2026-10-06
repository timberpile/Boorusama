import 'package:boorusama/core/images/types.dart';
import 'progressive_image_test_utils.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/post/types.dart';
import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/danbooru/danbooru_builder.dart';
import 'package:boorusama/boorus/danbooru/posts/_shared/danbooru_creator_preloader.dart';
import 'package:boorusama/boorus/danbooru/posts/details/providers.dart';
import 'package:boorusama/boorus/danbooru/posts/details/widgets.dart';
import 'package:boorusama/boorus/e621/e621.dart';
import 'package:boorusama/boorus/e621/e621_builder.dart';
import 'package:boorusama/boorus/e621/posts/post_data.dart';
import 'package:boorusama/boorus/pixiv/pixiv.dart';
import 'package:boorusama/boorus/pixiv/pixiv_builder.dart';
import 'package:boorusama/boorus/pixiv/posts/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/boorus/engine/providers.dart';
import 'package:boorusama/core/boorus/engine/types.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/developer_options/blocked_media_placeholder.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/errors/error.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/images/booru_image.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/routes.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/details/src/widgets/post_viewer_transformation_scope.dart';
import 'package:boorusama/core/posts/details/src/widgets/zoom_edge_page_gesture.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/details_parts/types.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/widgets/interactive_viewer_extended.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/info/device_info.dart';

void main() {
  for (final success in [false, true]) {
    testWidgets(
      'mixed viewer retains pixels and matrix through ${success ? 'successful' : 'failed'} decoded upgrade',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        _mobileViewport(tester, size: const Size(800, 1200));
        final adapter = ControlledImageAdapter();
        final harness = _Harness(
          imageAdapter: adapter,
          imageCache: TestImageCache({'thumbnail-1': lowerPng}),
          initialThumbnailUrl: 'thumbnail-1',
        );
        addTearDown(harness.dispose);
        await tester.pumpWidget(harness.build());
        await decodePump(tester);
        final media = tester
            .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
            .firstWhere(
              (media) => media.config.url == 'https://danbooru.example',
            );
        final imageController = media.imageController!;
        expect(await paintedPixel(tester), [255, 0, 0, 255]);
        expect(
          imageController.imageInfo.value?.image.width,
          2,
          reason: 'controller must describe the visible decoded lower image',
        );
        final details = _detailsController(tester);
        final pages = _pageViewController(tester);
        final transform = tester
            .widget<PostViewerTransformationScope>(
              find.byType(PostViewerTransformationScope),
            )
            .controller
            .transformationController;
        transform.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-400, -300, 0);
        await tester.pump();
        final matrix = transform.value.storage.toList();
        final lower = find.descendant(
          of: find.byType(RawPostDetailsImage<Post>).first,
          matching: find.byType(ExtendedRawImage),
        );
        final bounds = tester.getSize(lower.first);
        final target = adapter.pending.keys.singleWhere(
          (url) => url.contains('danbooru.example/media/1'),
        );
        adapter.complete(
          target,
          success ? targetPng : Uint8List.fromList([1, 2, 3]),
        );
        await decodePump(tester);
        expect(transform.value.storage, matrix);
        expect(_detailsController(tester), same(details));
        expect(_pageViewController(tester), same(pages));
        expect(pages.page, 0);
        final currentMedia = tester
            .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
            .firstWhere(
              (media) => media.config.url == 'https://danbooru.example',
            );
        expect(currentMedia.imageController, same(imageController));
        expect(imageController.imageInfo.value!.image.width, success ? 8 : 2);
        expect(
          await paintedPixel(tester),
          success ? [0, 0, 255, 255] : [255, 0, 0, 255],
        );
        expect(tester.getSize(lower.first), bounds);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'decoded replacement cancels a held edge drag without cancelling a new drag',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: const Size(800, 1200));
      final adapter = _ReplayableImageAdapter();
      final harness = _Harness(
        imageAdapter: adapter,
        imageCache: TestImageCache({'thumbnail-1': lowerPng}),
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await decodePump(tester);
      final pages = _pageViewController(tester);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-800, -400, 0);
      await tester.pump();
      final held = await tester.startGesture(const Offset(400, 550));
      await held.moveBy(const Offset(-170, 0));
      final target = adapter.pending.keys.singleWhere(
        (url) => url.contains('danbooru.example/media/1'),
      );
      adapter.complete(target, targetPng);
      await decodePump(tester);
      await held.up();
      await tester.pumpAndSettle();
      expect(
        pages.page,
        0,
        reason:
            'completion while a finger is held must cancel that navigation drag',
      );
      await _swipeOutwardAtRightEdge(tester);
      expect(pages.page, 1);
      await tester.pumpWidget(const SizedBox());
      final pendingRequests = adapter.requests
          .where(
            (request) => !adapter.pending[request.uri.toString()]!.isCompleted,
          )
          .toList();
      expect(pendingRequests, isNotEmpty);
      expect(
        pendingRequests.every(
          (request) => request.cancelToken?.isCancelled ?? false,
        ),
        isTrue,
      );
      // Drain the cancellation callbacks after unmount, in both callback zones.
      await decodePump(tester);
    },
  );

  testWidgets(
    'duplicate post IDs keep pending decoded media within their origin page',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final adapter = ControlledImageAdapter();
      final harness = _Harness(
        thumbnailQuality: ImageQuality.low,
        imageAdapter: adapter,
        imageCache: TestImageCache({'thumbnail-1': lowerPng}),
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await decodePump(tester);
      final firstTarget = adapter.pending.keys.singleWhere(
        (url) => url.contains('danbooru.example/media/1'),
      );
      _pageViewController(tester).jumpToPage(1);
      await tester.pumpAndSettle();
      await decodePump(tester);
      final current = _detailsController(tester).currentPost.value;
      expect(current.id, 1);
      expect(current.origin.sourceHost, 'e621.example');
      final secondTarget = adapter.pending.keys.singleWhere(
        (url) => url.contains('e621.example/media/1'),
      );
      adapter.complete(firstTarget, originalPng);
      await decodePump(tester);
      final visibleMedia = tester
          .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
          .singleWhere((media) => media.post == current);
      expect(visibleMedia.imageController!.imageInfo.value!.image.width, 2);
      adapter.complete(secondTarget, targetPng);
      await decodePump(tester);
      expect(visibleMedia.imageController!.imageInfo.value!.image.width, 8);
      expect(_pageViewController(tester).page, 1);
      expect(_detailsController(tester).currentPost.value, current);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sample-to-Original with different representation ratios keeps post geometry and viewer bounds',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: const Size(800, 1200));
      final adapter = ControlledImageAdapter();
      final post = _post(
        id: 1,
        booruType: BooruType.danbooru,
        host: 'https://danbooru.example',
        data: _posts.first.booruData,
        height: 400,
      );
      final harness = _Harness(
        posts: [post],
        loadOriginalOnZoom: true,
        imageAdapter: adapter,
        imageCache: TestImageCache({'thumbnail-1': lowerPng}),
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await decodePump(tester);
      adapter.complete(
        adapter.pending.keys.singleWhere((url) => url.contains('/media/1')),
        targetPng,
      );
      await decodePump(tester);
      final bounds = tester.getSize(
        find.byType(RawPostDetailsImage<Post>).first,
      );
      final media = tester.widget<PostMedia<Post>>(
        find.byType(PostMedia<Post>).first,
      );
      final controller = media.imageController!;
      final contentSize = tester
          .widget<InteractiveViewerExtended>(
            find.byType(InteractiveViewerExtended).first,
          )
          .contentSize;
      final first = await tester.startGesture(
        const Offset(300, 550),
        pointer: 21,
      );
      final second = await tester.startGesture(
        const Offset(500, 550),
        pointer: 22,
      );
      await tester.pump();
      await first.moveTo(const Offset(180, 550));
      await second.moveTo(const Offset(620, 550));
      await tester.pump();
      await first.up();
      await second.up();
      await decodePump(tester);
      expect(
        _zoomAction('Next page'),
        findsNothing,
        reason: 'the cropped sample does not prove full-image edges',
      );
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      final matrix = transform.value.storage.toList();
      adapter.complete(
        adapter.pending.keys.singleWhere((url) => url.endsWith('/original-1')),
        portraitPng,
      );
      await decodePump(tester);
      expect(
        tester.getSize(find.byType(RawPostDetailsImage<Post>).first),
        bounds,
      );
      expect(
        tester
            .widget<InteractiveViewerExtended>(
              find.byType(InteractiveViewerExtended).first,
            )
            .contentSize,
        contentSize,
      );
      expect(
        tester
            .widget<PostMedia<Post>>(find.byType(PostMedia<Post>).first)
            .imageController,
        same(controller),
      );
      expect(transform.value.storage, matrix);
      expect(await paintedPixel(tester), [0, 255, 0, 255]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('representation metadata cannot resize known post content', (
    tester,
  ) async {
    final post = _post(
      id: 1,
      booruType: BooruType.danbooru,
      host: 'https://danbooru.example',
      data: _posts.first.booruData,
      height: 400,
    );
    final harness = _Harness(
      imageCache: TestImageCache({
        'thumbnail-1': lowerPng,
        'sample-1': targetPng,
        'original-1': portraitPng,
      }),
    );
    addTearDown(harness.dispose);
    final controller = ExtendedImageController();
    addTearDown(controller.dispose);
    Widget build(bool original) => UncontrolledProviderScope(
      container: harness.container,
      child: testApp(
        Center(
          child: PostDetailsImage<Post>(
            config: _configs.first.auth,
            post: post,
            imageController: controller,
            placeholderMediaBuilder: null,
            imageUrlBuilder: (_) => original ? 'original-1' : 'sample-1',
            mediaAspectRatioBuilder: (_) => original ? 0.25 : 1,
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(false));
    await decodePump(tester);
    final bounds = tester.getSize(find.byType(PostDetailsImage<Post>));
    expect(controller.imageInfo.value!.image.width, 8);
    await tester.pumpWidget(build(true));
    await decodePump(tester);
    expect(tester.getSize(find.byType(PostDetailsImage<Post>)), bounds);
    expect(controller.imageInfo.value!.image.height, 8);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'AutoComic keeps a cropped decoded preview visible and preserves its matrix on completion',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final adapter = ControlledImageAdapter();
      final post = _post(
        id: 1,
        booruType: BooruType.danbooru,
        host: 'https://danbooru.example',
        data: _posts.first.booruData,
        height: 600,
      );
      final harness = _Harness(
        thumbnailQuality: ImageQuality.low,
        posts: [post],
        imageAdapter: adapter,
        imageCache: TestImageCache({'thumbnail-1': lowerPng}),
      );
      addTearDown(harness.dispose);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundaryKey, child: harness.build()),
      );
      await decodePump(tester);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      final matrix = transform.value.storage.toList();
      expect(_pageViewController(tester).zoom.value, isTrue);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final screenshot = await tester.runAsync(() => boundary.toImage());
      final bytes = await tester.runAsync(
        () => screenshot!.toByteData(),
      );
      final offset = (250 * screenshot!.width + 200) * 4;
      expect(
        bytes!.buffer.asUint8List().sublist(offset, offset + 4),
        [255, 0, 0, 255],
        reason:
            'the available preview must paint inside the actual AutoComic viewport',
      );
      screenshot.dispose();
      expect(_zoomAction('Next page'), findsNothing);
      adapter.complete(
        adapter.pending.keys.singleWhere((url) => url.contains('/media/1')),
        comicPng,
      );
      await decodePump(tester);
      expect(
        transform.value.storage,
        matrix,
        reason: 'the first full-compatible frame must not reapply AutoComic',
      );
      expect(await paintedPixel(tester), [0, 0, 255, 255]);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final success in [false, true]) {
    testWidgets(
      'original-on-zoom ${success ? 'success' : 'failure'} preserves the decoded sample and matrix',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        _mobileViewport(tester, size: const Size(800, 1200));
        final adapter = ControlledImageAdapter();
        final harness = _Harness(
          loadOriginalOnZoom: true,
          imageAdapter: adapter,
          imageCache: TestImageCache({'thumbnail-1': lowerPng}),
        );
        addTearDown(harness.dispose);
        await tester.pumpWidget(harness.build());
        await decodePump(tester);
        adapter.complete(
          adapter.pending.keys.singleWhere(
            (url) => url.contains('danbooru.example/media/1'),
          ),
          targetPng,
        );
        await decodePump(tester);
        final media = tester
            .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
            .first;
        final imageController = media.imageController!;
        final transform = tester
            .widget<PostViewerTransformationScope>(
              find.byType(PostViewerTransformationScope),
            )
            .controller
            .transformationController;
        final firstFinger = await tester.startGesture(
          const Offset(300, 550),
          pointer: 21,
        );
        final secondFinger = await tester.startGesture(
          const Offset(500, 550),
          pointer: 22,
        );
        await tester.pump();
        await firstFinger.moveTo(const Offset(180, 550));
        await secondFinger.moveTo(const Offset(620, 550));
        await tester.pump();
        await firstFinger.up();
        await secondFinger.up();
        await decodePump(tester);
        transform.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-400, -400, 0);
        await decodePump(tester);
        final matrix = transform.value.storage.toList();
        expect(imageController.imageInfo.value!.image.width, 8);
        expect(await paintedPixel(tester), [0, 0, 255, 255]);
        final original = adapter.pending.keys.singleWhere(
          (url) => url.endsWith('/original-1'),
        );
        adapter.complete(
          original,
          success ? originalPng : Uint8List(0),
          status: success ? 200 : 404,
        );
        await decodePump(tester);
        expect(transform.value.storage, matrix);
        expect(_pageViewController(tester).page, 0);
        expect(imageController.imageInfo.value!.image.width, success ? 16 : 8);
        expect(
          await paintedPixel(tester),
          success ? [0, 255, 0, 255] : [0, 0, 255, 255],
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final placeholder in ['blocked', 'empty URL']) {
    testWidgets('$placeholder media cannot edge-navigate while zoomed', (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: const Size(800, 1200));
      final harness = _Harness(
        loadMedia: placeholder == 'empty URL',
        emptyFirstImage: placeholder == 'empty URL',
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();

      expect(find.byType(ZoomEdgePageGesture), findsWidgets);
      if (placeholder == 'blocked') {
        expect(find.byType(BlockedMediaPlaceholder), findsWidgets);
      } else {
        final image = tester.widget<RawPostDetailsImage<Post>>(
          find.byType(RawPostDetailsImage<Post>).first,
        );
        expect(image.imageUrlBuilder?.call(image.post), '');
      }
      await _swipeOutwardAtRightEdge(tester);
      expect(_pageViewController(tester).page, 0);
      expect(_zoomAction('Next page'), findsNothing);
    });
  }

  testWidgets('failed image media cannot edge-navigate while zoomed', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final harness = _Harness(invalidImage: true);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPlaceholder), findsWidgets);

    await _swipeOutwardAtRightEdge(tester);
    expect(_pageViewController(tester).page, 0);
    expect(_zoomAction('Next page'), findsNothing);
  });

  testWidgets('changes one post only after releasing an outward edge drag', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExtendedImage), findsWidgets);
    expect(
      tester
          .widget<PostMedia<Post>>(find.byType(PostMedia<Post>).first)
          .imageController
          ?.loadState
          .value,
      LoadState.completed,
    );

    final pageView = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-800, -400, 0);
    await tester.pump();
    expect(pageView.zoom.value, isTrue);
    expect(pageView.swipe.value, isFalse);
    expect(_comicButton('Next page'), findsNothing);
    expect(
      tester
          .widget<ZoomEdgePageGesture>(find.byType(ZoomEdgePageGesture).first)
          .enabled,
      isTrue,
    );

    final drag = await tester.startGesture(const Offset(400, 550));
    await drag.moveBy(const Offset(-170, 0));
    await tester.pump();
    expect(pageView.page, 0);
    await drag.up();
    await tester.pumpAndSettle();
    expect(pageView.page, 1);
  });

  for (final scenario in [
    (
      name: 'Next in vertical LTR mode',
      vertical: true,
      direction: TextDirection.ltr,
      source: 0,
      target: 1,
      drag: -170.0,
    ),
    (
      name: 'Previous in vertical LTR mode',
      vertical: true,
      direction: TextDirection.ltr,
      source: 1,
      target: 0,
      drag: 170.0,
    ),
    (
      name: 'Next in horizontal RTL mode',
      vertical: false,
      direction: TextDirection.rtl,
      source: 0,
      target: 1,
      drag: 170.0,
    ),
    (
      name: 'Previous in horizontal RTL mode',
      vertical: false,
      direction: TextDirection.rtl,
      source: 1,
      target: 0,
      drag: -170.0,
    ),
  ]) {
    testWidgets(
      'slides adjacent posts with the edge drag for ${scenario.name}',
      (
        tester,
      ) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        _mobileViewport(tester);
        final harness = _Harness(
          vertical: scenario.vertical,
          direction: scenario.direction,
          initialIndex: scenario.source,
          reduceAnimations: false,
        );
        addTearDown(harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        await _waitForCurrentImage(tester);

        final pageController = _pageViewController(tester);
        final transform = tester
            .widget<PostViewerTransformationScope>(
              find.byType(PostViewerTransformationScope),
            )
            .controller
            .transformationController;
        transform.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(scenario.drag < 0 ? -400 : 0, -200, 0);
        await tester.pump();
        expect(pageController.zoom.value, isTrue);

        final drag = await tester.startGesture(const Offset(200, 400));
        await drag.moveBy(Offset(scenario.drag, 0));
        await drag.up();
        await tester.pump();
        expect(pageController.page, scenario.source);

        await tester.pump(const Duration(milliseconds: 40));
        expect(pageController.page, scenario.source);
        final outgoingOffset = _edgeSlideOffset(tester);
        expect(outgoingOffset * scenario.drag, greaterThan(0));
        expect(_edgeContentIsFaded(tester), isTrue);

        await tester.pump(const Duration(milliseconds: 75));
        expect(pageController.page, scenario.target);
        await tester.pump(const Duration(milliseconds: 20));
        final incomingOffset = _edgeSlideOffset(tester);
        expect(incomingOffset * scenario.drag, lessThan(0));

        await tester.pumpAndSettle();
        expect(pageController.page, scenario.target);
        expect(_edgeContentIsFaded(tester), isFalse);
      },
    );
  }

  testWidgets(
    'a long comic opened on a later post paints the adjacent image after an edge slide',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final posts = [
        _post(
          id: 101,
          booruType: BooruType.danbooru,
          host: 'https://danbooru.example',
          data: _posts[0].booruData,
        ),
        _post(
          id: 102,
          booruType: BooruType.e621,
          host: 'https://e621.example',
          data: _posts[1].booruData,
          height: 600,
        ),
        _post(
          id: 103,
          booruType: BooruType.pixiv,
          host: 'https://pixiv.example',
          data: _posts[2].booruData,
          height: 600,
        ),
      ];
      final harness = _Harness(
        initialIndex: 1,
        reduceAnimations: false,
        posts: posts,
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);

      final pageView = _pageViewController(tester);
      final details = _detailsController(tester);

      void expectVisiblePost(int index, String host) {
        expect(pageView.page, index);
        expect(pageView.pageController.page, closeTo(index.toDouble(), 0.001));
        expect(details.currentSettledPage.value, index);
        expect(details.currentPost.value, posts[index]);
        expect(_visibleImageHost(tester), host);
      }

      Future<void> swipeEdge(double dx) async {
        final drag = await tester.startGesture(const Offset(200, 400));
        await drag.moveBy(Offset(dx, 0));
        await drag.up();
        await tester.pumpAndSettle();
        await _waitForCurrentImage(tester);
      }

      expect(pageView.zoom.value, isTrue);
      expectVisiblePost(1, 'e621.example');

      await swipeEdge(-170);
      expectVisiblePost(2, 'pixiv.example');
      expect(pageView.zoom.value, isTrue);

      await swipeEdge(170);
      expectVisiblePost(1, 'e621.example');
      expect(pageView.zoom.value, isTrue);

      await swipeEdge(170);
      expectVisiblePost(0, 'danbooru.example');

      await tester.drag(_postPageView(tester), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expectVisiblePost(1, 'e621.example');
      expect(pageView.zoom.value, isTrue);

      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'an external page change during a horizontal edge slide keeps image and metadata together',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final harness = _Harness(initialIndex: 1, reduceAnimations: false);
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);

      final pageView = _pageViewController(tester);
      final details = _detailsController(tester);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-400, -200, 0);
      await tester.pump();

      final drag = await tester.startGesture(const Offset(200, 400));
      await drag.moveBy(const Offset(-170, 0));
      await drag.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(pageView.page, 1);
      expect(_edgeContentIsFaded(tester), isTrue);

      pageView.jumpToPage(0);
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      expect(pageView.page, 0);
      expect(pageView.pageController.page, closeTo(0, 0.001));
      expect(details.currentSettledPage.value, 0);
      expect(details.currentPost.value, _posts[0]);
      expect(_visibleImageHost(tester), 'danbooru.example');
      expect(_edgeContentIsFaded(tester), isFalse);
    },
  );

  testWidgets('reduced motion changes the post without sliding', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester);
    final harness = _Harness(vertical: true);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-400, -200, 0);
    await tester.pump();

    final drag = await tester.startGesture(const Offset(200, 400));
    await drag.moveBy(const Offset(-170, 0));
    await drag.up();
    await tester.pump();
    expect(_pageViewController(tester).page, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_edgeContentIsFaded(tester), isFalse);
  });

  testWidgets('an external page change cancels an edge slide', (tester) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester);
    final harness = _Harness(vertical: true, reduceAnimations: false);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final pageController = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-400, -200, 0);
    await tester.pump();

    final drag = await tester.startGesture(const Offset(200, 400));
    await drag.moveBy(const Offset(-170, 0));
    await drag.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(_edgeSlideOffset(tester), lessThan(0));

    pageController.jumpToPage(2);
    await tester.pump();
    expect(_edgeContentIsFaded(tester), isFalse);
    await tester.pumpAndSettle();
    expect(pageController.page, 2);
  });

  testWidgets('a second edge drag cannot advance again during a slide', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester);
    final harness = _Harness(vertical: true, reduceAnimations: false);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final pageController = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-400, -200, 0);
    await tester.pump();

    final first = await tester.startGesture(const Offset(200, 400));
    await first.moveBy(const Offset(-170, 0));
    await first.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final second = await tester.startGesture(const Offset(200, 400));
    await second.moveBy(const Offset(-170, 0));
    await second.up();
    await tester.pumpAndSettle();
    expect(pageController.page, 1);
  });

  testWidgets('a transient image failure cancels a held edge drag', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final pageView = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-800, -400, 0);
    await tester.pump();
    final image = tester
        .widget<PostMedia<Post>>(find.byType(PostMedia<Post>).first)
        .imageController!;
    expect(image.loadState.value, LoadState.completed);

    final held = await tester.startGesture(const Offset(400, 550));
    await held.moveBy(const Offset(-170, 0));
    image.changeLoadState(LoadState.failed);
    image.changeLoadState(LoadState.completed);
    await held.up();
    await tester.pumpAndSettle();
    expect(pageView.page, 0);
  });

  testWidgets('a new frame of a loaded image does not cancel an edge drag', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final harness = _Harness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final pageView = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    transform.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-800, -400, 0);
    await tester.pump();
    final image = tester
        .widget<PostMedia<Post>>(find.byType(PostMedia<Post>).first)
        .imageController!;
    final currentFrame = image.imageInfo.value!;

    final held = await tester.startGesture(const Offset(400, 550));
    await held.moveBy(const Offset(-170, 0));
    image.replaceImage(
      info: ImageInfo(
        image: currentFrame.image.clone(),
        scale: currentFrame.scale,
        debugLabel: 'next frame',
      ),
    );
    await held.up();
    await tester.pumpAndSettle();
    expect(pageView.page, 1);
  });

  testWidgets(
    'pinching retains image pan and enables bounded navigation',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: const Size(800, 1200));
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);

      final pageView = _pageViewController(tester);
      final first = await tester.startGesture(
        const Offset(300, 550),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(500, 550),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(const Offset(180, 550));
      await second.moveTo(const Offset(620, 550));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();

      expect(pageView.zoom.value, isTrue);
      expect(_zoomAction('Previous page'), findsNothing);
      expect(_zoomAction('Next page'), findsOneWidget);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-400, -400, 0);
      await tester.pump();
      final pan = await tester.startGesture(const Offset(400, 550));
      await pan.moveBy(const Offset(-80, 0));
      await pan.up();
      await tester.pumpAndSettle();
      expect(pageView.page, 0);
      _invokeZoomAction(tester, 'Next page');
      await tester.pumpAndSettle();
      expect(pageView.page, 1);
    },
  );

  testWidgets('keeps vertical gesture navigation available after zoom', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester);
    final harness = _Harness(vertical: true);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final pageView = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    expect(pageView.overlay.value, isTrue);
    expect(_comicButton('Next page'), findsNothing);

    transform.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();

    expect(pageView.zoom.value, isTrue);
    expect(pageView.overlay.value, isTrue);
    expect(_zoomAction('Next page'), findsOneWidget);

    tester
        .widget<InteractiveViewerExtended>(
          find.byType(InteractiveViewerExtended).first,
        )
        .onTap
        ?.call();
    await tester.pump();
    expect(pageView.overlay.value, isFalse);
    expect(_zoomAction('Next page'), findsOneWidget);

    tester
        .widget<InteractiveViewerExtended>(
          find.byType(InteractiveViewerExtended).first,
        )
        .onTap
        ?.call();
    await tester.pump();
    expect(pageView.overlay.value, isTrue);
    expect(_zoomAction('Next page'), findsOneWidget);
  });

  testWidgets('keeps initially hidden toolbar hidden through vertical zoom', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester);
    final harness = _Harness(vertical: true, hideOverlay: true);
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);

    final pageView = _pageViewController(tester);
    final transform = tester
        .widget<PostViewerTransformationScope>(
          find.byType(PostViewerTransformationScope),
        )
        .controller
        .transformationController;
    expect(pageView.overlay.value, isFalse);

    transform.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    expect(pageView.zoom.value, isTrue);
    expect(pageView.overlay.value, isFalse);
    expect(_zoomAction('Next page'), findsOneWidget);

    tester
        .widget<InteractiveViewerExtended>(
          find.byType(InteractiveViewerExtended).first,
        )
        .onTap
        ?.call();
    await tester.pump();
    expect(pageView.overlay.value, isTrue);
    expect(_zoomAction('Next page'), findsOneWidget);
  });

  testWidgets(
    'grid details keep the same mixed viewer while Next waits for and opens appended posts',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final pending = Completer<PostResult<Post>>();
      final live = _LiveRouteHarness(loadNext: (_) => pending.future);
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      expect(_comicButton('Next page'), findsNothing);
      details.loadOriginalImage(_liveInitial[1]);
      await _waitForCurrentImage(tester);
      pageView.zoom.value = true;
      await tester.pump();

      expect(live.requestedPages, [2]);
      expect(_zoomAction('Next page'), findsNothing);
      await tester.pump();
      expect(details.currentPost.value.id, 22);

      pending.complete(PostResult(posts: [_liveNext], total: 3));
      await tester.pumpAndSettle();
      expect(pageView.totalPage, 3);
      expect(_zoomAction('Next page'), findsOneWidget);
      transform.value = Matrix4.diagonal3Values(2, 2, 1);
      _invokeZoomAction(tester, 'Next page');
      await tester.pumpAndSettle();

      expect(details.currentPost.value.id, 33);
      expect(_detailsController(tester), same(details));
      expect(_pageViewController(tester), same(pageView));
      expect(transform.value, Matrix4.identity());
      expect(details.usesOriginalImage(_liveInitial[1]), isTrue);
      _expectMedia(tester, postId: 33, host: 'pixiv.example');
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets('failed grid loading retries through an outward edge drag', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester);
    final live = _LiveRouteHarness(
      reduceAnimations: false,
      loadNext: (attempt) async {
        if (attempt == 1) throw StateError('offline');
        return PostResult(posts: [_liveNext], total: 3);
      },
    );
    addTearDown(live.dispose);
    await live.grid.refresh();
    await tester.pumpWidget(live.build());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);
    final details = _detailsController(tester);
    final pageView = _pageViewController(tester);
    pageView.zoom.value = true;
    await tester.pump();

    expect(details.currentPost.value.id, 22);
    expect(_zoomAction('Retry'), findsOneWidget);
    await _swipeOutwardAtRightEdge(
      tester,
      settle: false,
      indicatorIcon: Icons.refresh,
      indicatorLabel: 'Retry',
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(_edgeContentIsFaded(tester), isFalse);
    expect(pageView.page, 1);
    await tester.pumpAndSettle();
    expect(live.requestedPages, [2, 2]);
    expect(_zoomAction('Next page'), findsOneWidget);
    expect(_detailsController(tester), same(details));
  });

  testWidgets(
    'a fetch completing during a held edge drag requires a new drag',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final pending = Completer<PostResult<Post>>();
      final live = _LiveRouteHarness(loadNext: (_) => pending.future);
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);

      final pageView = _pageViewController(tester);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-400, -200, 0);
      await tester.pump();
      expect(_zoomAction('Next page'), findsNothing);

      final held = await tester.startGesture(const Offset(200, 400));
      await held.moveBy(const Offset(-170, 0));
      pending.complete(PostResult(posts: [_liveNext], total: 3));
      await tester.pumpAndSettle();
      expect(_zoomAction('Next page'), findsOneWidget);
      await held.up();
      await tester.pumpAndSettle();
      expect(pageView.page, 1);

      await _swipeOutwardAtRightEdge(tester);
      expect(pageView.page, 2);
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'the final grid bound hides Next without leaving the current post',
    (
      tester,
    ) async {
      _mobileViewport(tester);
      final live = _LiveRouteHarness(
        loadNext: (_) async => PostResult<Post>.empty(),
      );
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      pageView.zoom.value = true;
      await tester.pump();

      expect(live.requestedPages, [2]);
      expect(_comicButton('Next page'), findsNothing);
      expect(details.currentPost.value.id, 22);
      expect(pageView.page, 1);
    },
  );

  testWidgets(
    'grid details pass duplicate and blacklisted pages before opening the next visible post',
    (tester) async {
      _mobileViewport(tester);
      final hidden = _post(
        id: 44,
        booruType: BooruType.pixiv,
        host: 'https://pixiv.example',
        data: _liveNext.booruData,
      );
      final live = _LiveRouteHarness(
        hiddenUrls: {'original-44'},
        loadNext: (attempt) async => switch (attempt) {
          1 => PostResult(posts: [_liveInitial[1]], total: 4),
          2 => PostResult(posts: [hidden], total: 4),
          _ => PostResult(posts: [_liveNext], total: 4),
        },
      );
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);

      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      pageView.zoom.value = true;
      await tester.pumpAndSettle();

      expect(live.requestedPages, [2, 3, 4]);
      expect(pageView.totalPage, 3);
      expect(details.currentPost.value.id, 22);
      _invokeZoomAction(tester, 'Next page');
      await tester.pumpAndSettle();
      expect(details.currentPost.value.id, 33);
      expect(_detailsController(tester), same(details));
      await tester.pump(const Duration(milliseconds: 200));
    },
  );

  testWidgets(
    'empty-page budget waits for an outward edge drag before loading more',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final live = _LiveRouteHarness(
        reduceAnimations: false,
        loadNext: (attempt) async => attempt <= 3
            ? PostResult(posts: [_liveInitial[1]], total: 3)
            : PostResult(posts: [_liveNext], total: 3),
      );
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      pageView.zoom.value = true;
      await tester.pumpAndSettle();

      expect(live.requestedPages, [2, 3, 4]);
      expect(_zoomAction('Load more'), findsOneWidget);
      expect(_comicButton('Next page'), findsNothing);
      expect(pageView.totalPage, 2);
      await tester.pump(const Duration(seconds: 2));
      expect(live.requestedPages, [2, 3, 4]);

      await _swipeOutwardAtRightEdge(
        tester,
        settle: false,
        indicatorIcon: Icons.expand_more,
        indicatorLabel: 'Load more',
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_edgeContentIsFaded(tester), isFalse);
      expect(pageView.page, 1);
      await tester.pumpAndSettle();
      expect(live.requestedPages, [2, 3, 4, 5]);
      expect(_zoomAction('Next page'), findsOneWidget);
      expect(details.currentPost.value.id, 22);
    },
  );

  testWidgets(
    'an empty page followed by failure offers Retry on the same page',
    (
      tester,
    ) async {
      _mobileViewport(tester);
      final live = _LiveRouteHarness(
        loadNext: (attempt) async => switch (attempt) {
          1 => PostResult(posts: [_liveInitial[1]], total: 3),
          2 => throw StateError('offline'),
          _ => PostResult(posts: [_liveNext], total: 3),
        },
      );
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      final details = _detailsController(tester);
      _pageViewController(tester).zoom.value = true;
      await tester.pump();

      expect(live.requestedPages, [2, 3]);
      expect(_zoomAction('Retry'), findsOneWidget);
      _invokeZoomAction(tester, 'Retry');
      await tester.pumpAndSettle();
      expect(live.requestedPages, [2, 3, 3]);
      expect(_zoomAction('Next page'), findsOneWidget);
      expect(details.currentPost.value.id, 22);
    },
  );

  testWidgets('an empty page followed by the final page hides Next', (
    tester,
  ) async {
    _mobileViewport(tester);
    final live = _LiveRouteHarness(
      loadNext: (attempt) async => attempt == 1
          ? PostResult(posts: [_liveInitial[1]], total: 2)
          : PostResult<Post>.empty(),
    );
    addTearDown(live.dispose);
    await live.grid.refresh();
    await tester.pumpWidget(live.build());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final details = _detailsController(tester);
    _pageViewController(tester).zoom.value = true;
    await tester.pump();

    expect(live.requestedPages, [2, 3]);
    expect(_comicButton('Next page'), findsNothing);
    expect(_comicButton('Load more'), findsNothing);
    expect(details.currentPost.value.id, 22);
  });

  testWidgets(
    'leaving during an empty-page cooldown cancels further requests',
    (
      tester,
    ) async {
      _mobileViewport(tester);
      final pending = Completer<PostResult<Post>>();
      final live = _LiveRouteHarness(
        loadNext: (attempt) => attempt == 1
            ? pending.future
            : Future.value(PostResult(posts: [_liveNext], total: 3)),
      );
      addTearDown(live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(live.requestedPages, [2]);

      pending.complete(PostResult(posts: [_liveInitial[1]], total: 3));
      await tester.pump();
      live.router.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(live.requestedPages, [2]);
    },
  );

  testWidgets(
    'opening during an existing grid fetch continues after its duplicate-only result',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final pending = Completer<PostResult<Post>>();
      final live = _LiveRouteHarness(
        loadNext: (attempt) => attempt == 1
            ? pending.future
            : Future.value(PostResult(posts: [_liveNext], total: 3)),
      );
      addTearDown(live.dispose);
      await live.grid.refresh();
      unawaited(live.grid.fetchMore());
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(live.requestedPages, [2]);

      pending.complete(PostResult(posts: [_liveInitial[1]], total: 3));
      await tester.pumpAndSettle();

      expect(live.requestedPages, [2, 3]);
      expect(_pageViewController(tester).totalPage, 3);
      expect(_detailsController(tester).currentPost.value.id, 22);
    },
  );

  testWidgets('Danbooru uploader details use the page-scoped profile', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final post = _post(
      id: 1,
      booruType: BooruType.danbooru,
      host: 'https://danbooru.example',
      uploaderId: 101372,
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
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          home: CurrentBooruConfigScope(
            config: _configs.first,
            child: Consumer(
              builder: (context, ref, _) {
                ref.watch(danbooruUploaderQueryProvider(post));
                return const Text('Uploader details');
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Uploader details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag colors follow a page-scoped profile after a root read', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final request = (BooruConfig.empty.auth, 'artist');

    harness.container.read(chipColorsFromTagStringProvider(request));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          home: CurrentBooruConfigScope(
            config: BooruConfig.empty,
            child: Consumer(
              builder: (context, ref, _) {
                ref.watch(chipColorsFromTagStringProvider(request));
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mixed pages switch presentation profile and media without changing the global profile',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      final harness = _Harness();
      addTearDown(harness.dispose);

      harness.container.read(
        chipColorsFromTagStringProvider((_configs.first.auth, 'artist')),
      );
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
        find.text('The original site profile is no longer available.'),
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
          reason: PostPresentationFallbackReason.malformedData,
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

Finder _postPageView(WidgetTester tester) {
  final controller = _pageViewController(tester).pageController;
  return find.byWidgetPredicate(
    (widget) => widget is PageView && widget.controller == controller,
  );
}

double _edgeSlideOffset(WidgetTester tester) {
  final pageView = _postPageView(tester);
  final slide = tester.widget<Transform>(
    find.ancestor(of: pageView, matching: find.byType(Transform)).first,
  );
  return slide.transform.getTranslation().x;
}

bool _edgeContentIsFaded(WidgetTester tester) {
  final pageView = _postPageView(tester);
  return tester
      .widgetList<Opacity>(
        find.ancestor(of: pageView, matching: find.byType(Opacity)),
      )
      .any((opacity) => opacity.opacity < 1);
}

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
  _Harness({
    GoRouter? router,
    bool vertical = false,
    this.direction = TextDirection.ltr,
    this.initialIndex = 0,
    this.posts,
    bool reduceAnimations = true,
    bool hideOverlay = false,
    bool loadMedia = true,
    bool emptyFirstImage = false,
    bool invalidImage = false,
    bool loadOriginalOnZoom = false,
    HttpClientAdapter? imageAdapter,
    ImageCacheManager? imageCache,
    this.initialThumbnailUrl,
    ImageQuality thumbnailQuality = ImageQuality.automatic,
  }) : container = ProviderContainer(
         overrides: [
           if (router != null) routerProvider.overrideWithValue(router),
           settingsProvider.overrideWithValue(
             Settings.defaultSettings.copyWith(
               reduceAnimations: reduceAnimations,
               listing: Settings.defaultSettings.listing.copyWith(
                 imageQuality: thumbnailQuality,
               ),
               viewer: Settings.defaultSettings.viewer.copyWith(
                 loadOriginalOnZoom: loadOriginalOnZoom,
                 swipeMode: vertical
                     ? PostDetailsSwipeMode.vertical
                     : PostDetailsSwipeMode.horizontal,
                 postDetailsOverlayInitialState: hideOverlay
                     ? PostDetailsOverlayInitialState.hide
                     : PostDetailsOverlayInitialState.show,
               ),
             ),
           ),
           colorSchemeProvider.overrideWithValue(
             ColorScheme.fromSeed(seedColor: Colors.blue),
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
             (ref, config) => _MediaResolver(
               Uri.tryParse(config.url)?.host ?? '',
               emptyFirstImage: emptyFirstImage,
             ),
           ),
           booruRepoProvider.overrideWith((ref, config) => null),
           booruBuilderProvider.overrideWith((ref, config) => null),
           automaticMediaLoadingEnabledProvider.overrideWithValue(loadMedia),
           dioForWidgetProvider.overrideWith(
             (ref, config) =>
                 Dio(BaseOptions(baseUrl: 'https://images.example/'))
                   ..httpClientAdapter =
                       imageAdapter ?? _TestImageAdapter(invalidImage),
           ),
           defaultImageCacheManagerProvider.overrideWithValue(
             imageCache ??
                 _NoImageCache(
                   invalidImage,
                   comicIds: (posts ?? _posts)
                       .where((post) => post.height > post.width * 4)
                       .map((post) => post.id)
                       .toSet(),
                 ),
           ),
           deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
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
  final TextDirection direction;
  final int initialIndex;
  final List<Post>? posts;
  final String? initialThumbnailUrl;

  Widget build() => UncontrolledProviderScope(
    container: container,
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: Directionality(
          textDirection: direction,
          child: MixedPostDetailsPage(
            posts: posts ?? _posts,
            initialIndex: initialIndex,
            initialThumbnailUrl: initialThumbnailUrl,
            scrollController: null,
            disclaimer: null,
          ),
        ),
      ),
    ),
  );

  Widget buildRouter(GoRouter router) => UncontrolledProviderScope(
    container: container,
    child: BooruLocalization(
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
      ),
    ),
  );

  void dispose() => container.dispose();
}

Finder _comicButton(String label) => find.byWidgetPredicate(
  (widget) => widget is KurumiTooltip && widget.message == label,
);

String _visibleImageHost(WidgetTester tester) {
  final images = find.byType(RawPostDetailsImage<Post>);
  final center = tester.view.physicalSize.center(Offset.zero);
  for (var index = 0; index < images.evaluate().length; index++) {
    final current = images.at(index);
    if (tester.getRect(current).contains(center)) {
      final image = tester.widget<RawPostDetailsImage<Post>>(current);
      return Uri.parse(image.config.url).host;
    }
  }
  throw StateError('No image covers the viewer center');
}

Finder _zoomAction(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.customSemanticsActions?.keys.any(
            (action) => action.label == label,
          ) ??
          false),
);

void _invokeZoomAction(WidgetTester tester, String label) {
  final widget = tester.widget<Semantics>(_zoomAction(label));
  widget.properties.customSemanticsActions!.entries
      .singleWhere((entry) => entry.key.label == label)
      .value();
}

Future<void> _swipeOutwardAtRightEdge(
  WidgetTester tester, {
  bool settle = true,
  IconData? indicatorIcon,
  String? indicatorLabel,
}) async {
  await decodePump(tester);
  final width = tester.view.physicalSize.width;
  final transform = tester
      .widget<PostViewerTransformationScope>(
        find.byType(PostViewerTransformationScope),
      )
      .controller
      .transformationController;
  transform.value = Matrix4.diagonal3Values(2, 2, 1)
    ..setTranslationRaw(-width, -200, 0);
  await tester.pump();
  final drag = await tester.startGesture(
    Offset(width / 2, tester.view.physicalSize.height / 2),
  );
  await drag.moveBy(const Offset(-170, 0));
  if (indicatorIcon != null) {
    await tester.pump();
    expect(find.byIcon(indicatorIcon), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == indicatorLabel,
      ),
      findsOneWidget,
    );
  }
  await drag.up();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _waitForCurrentImage(WidgetTester tester) async {
  LoadState? state;
  for (var attempt = 0; attempt < 5; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final currentPost = _detailsController(tester).currentPost.value;
    final media = tester
        .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
        .firstWhere((item) => item.post == currentPost);
    state = media.imageController?.loadState.value;
    if (state == LoadState.completed) return;
  }
  expect(state, LoadState.completed);
}

void _mobileViewport(
  WidgetTester tester, {
  Size size = const Size(400, 800),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _liveInitial = <Post>[
  _post(
    id: 11,
    booruType: BooruType.danbooru,
    host: 'https://danbooru.example',
    data: _posts[0].booruData,
  ),
  _post(
    id: 22,
    booruType: BooruType.e621,
    host: 'https://e621.example',
    data: _posts[1].booruData,
  ),
];
final _liveNext = _post(
  id: 33,
  booruType: BooruType.pixiv,
  host: 'https://pixiv.example',
  data: _posts[2].booruData,
);

class _LiveRouteHarness {
  _LiveRouteHarness({
    required this.loadNext,
    this.hiddenUrls = const {},
    this.reduceAnimations = true,
  }) {
    grid = PostGridController<Post>(
      fetcher: (page) => page == 1
          ? TaskEither.right(PostResult(posts: _liveInitial, total: 2))
          : TaskEither.tryCatch(
              () {
                requestedPages.add(page);
                return loadNext(requestedPages.length);
              },
              (error, _) => UnknownError(error: error, message: 'load failed'),
            ),
      blacklistedTagsFetcher: () async => const {},
      blacklistedUrlsFetcher: () async => hiddenUrls,
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => goToPostDetailsPageFromController(
                  ref: ref,
                  initialIndex: 1,
                  controller: grid,
                  initialThumbnailUrl: null,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (context, state) => InheritedDetailsContext<Post>(
            context: state.extra! as DetailsRouteContext<Post>,
            child: const CurrentPostDetailsPage<Post>(),
          ),
        ),
      ],
    );
    harness = _Harness(
      router: router,
      vertical: true,
      reduceAnimations: reduceAnimations,
    );
  }

  final Future<PostResult<Post>> Function(int attempt) loadNext;
  final bool reduceAnimations;
  final Set<String> hiddenUrls;
  late final PostGridController<Post> grid;
  late final GoRouter router;
  late final _Harness harness;
  final requestedPages = <int>[];

  Widget build() => harness.buildRouter(router);

  void dispose() {
    harness.dispose();
    router.dispose();
    grid.dispose();
  }
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
  int? uploaderId,
  double height = 100,
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
    height: height,
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
    uploaderId: uploaderId,
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
  const _MediaResolver(this.host, {this.emptyFirstImage = false});

  final String host;
  final bool emptyFirstImage;

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      emptyFirstImage && post.id == 1 ? '' : '$host/media/${post.id}';

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) =>
      post.width / post.height;

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) =>
      '$host/video/${post.id}';

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) => 1;
}

final class _TestImageAdapter implements HttpClientAdapter {
  _TestImageAdapter(this.invalidImage);

  final bool invalidImage;
  static final _png = File('assets/images/logo.png').readAsBytesSync();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    invalidImage ? Uint8List.fromList([1, 2, 3]) : _png,
    200,
    headers: {
      Headers.contentTypeHeader: ['image/png'],
    },
  );
}

final class _NoImageCache implements ImageCacheManager {
  _NoImageCache(this.invalidImage, {this.comicIds = const {}});

  final Set<int> comicIds;

  final bool invalidImage;

  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      invalidImage
      ? Uint8List.fromList([1, 2, 3])
      : comicIds.any((id) => key.endsWith('/$id') || key.endsWith('-$id'))
      ? comicPng
      : lowerPng;

  @override
  String generateCacheKey(String url, {String? customKey}) => url;

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// A URL barrier controls payload delivery, while each actual HTTP request gets
// its own response stream. Adjacent-page preloads can request the staged URL.
class _ReplayableImageAdapter implements HttpClientAdapter {
  final pending = <String, Completer<Uint8List>>{};
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes =
        await (pending[options.uri.toString()] ??= Completer<Uint8List>())
            .future;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }

  void complete(String url, Uint8List bytes) => pending[url]!.complete(bytes);

  @override
  void close({bool force = false}) {}
}
