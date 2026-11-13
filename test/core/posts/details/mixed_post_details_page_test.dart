import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/artists/types.dart';
import 'package:boorusama/core/posts/details/src/providers/media_group_provider.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, DiagnosticPropertiesBuilder, FlutterError;
import 'package:boorusama/boorus/pixiv/works/work_mapper.dart';
import 'package:boorusama/boorus/pixiv/works/work_source.dart';
import 'package:boorusama/boorus/pixiv/works/work_presentation.dart';
import 'package:boorusama/boorus/pixiv/works/bookmark_actions.dart';
import 'package:boorusama/core/posts/details/src/widgets/media_group_page.dart';
import 'package:boorusama/core/posts/details/src/widgets/media_group_page_indicator.dart';

import '../../../boorus/pixiv/works/work_test_fixtures.dart' as works;

import 'package:flutter/gestures.dart'
    show kDoubleTapMinTime, kDoubleTapTimeout;
import 'package:boorusama/core/posts/details/src/widgets/video_controls.dart';
import 'package:boorusama/core/videos/player/types.dart';
import 'package:boorusama/core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import 'package:boorusama/core/posts/details/src/routes/post_details_live_source.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/boorus/defaults/types.dart';
import 'package:boorusama/core/images/types.dart';
import 'package:boorusama/core/cache/providers.dart';
import 'package:boorusama/core/blacklists/providers.dart';
import 'package:boorusama/core/blacklists/src/types/blacklisted_tag.dart';
import 'package:boorusama/core/content/capabilities.dart';
import 'package:boorusama/core/content/providers.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/details/src/widgets/group_viewer_scope.dart';

import 'progressive_image_test_utils.dart';

import 'package:extended_image/src/image/raw_image.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show FontLoader, rootBundle, MethodCall, SystemChannels;

// Flutter imports:
import 'package:material_ui/material_ui.dart';

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
import 'package:boorusama/core/videos/engines/types.dart';
import 'package:boorusama/core/videos/player/widgets.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/info/device_info.dart';
import 'package:boorusama/foundation/platform.dart';
import 'package:boorusama/foundation/url_launcher.dart';

import '../../../support/fakes/test_platform_services.dart';
import '../../../support/fakes/memory_repositories.dart'
    show MemoryMiscDataStore;

const _viewerCaptureDirectory = String.fromEnvironment('VIEWER_CAPTURE_DIR');

void main() {
  for (final (size, scale) in [
    (const Size(400, 800), 1.0),
    (const Size(320, 800), 2.0),
    (const Size(844, 390), 1.0),
  ]) {
    for (final work in [false, true]) {
      for (final details in [false, true]) {
        for (final backwards in [false, true]) {
          testWidgets(
            'short swipes change entries equally over media and commentary '
            '(Work=$work, Details=$details, backwards=$backwards, $size, scale=$scale)',
            (tester) async {
              _mobileViewport(tester, size: size);
              String? copiedText;
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                SystemChannels.platform,
                (call) async {
                  if (call.method == 'Clipboard.setData') {
                    copiedText = (call.arguments as Map)['text'] as String;
                  }
                  if (call.method == 'Clipboard.hasStrings') {
                    return {'value': false};
                  }
                  return null;
                },
              );
              addTearDown(
                () => tester.binding.defaultBinaryMessenger
                    .setMockMethodCallHandler(SystemChannels.platform, null),
              );
              final access = ContentAccessContext.profile(
                config: _configs[2],
                authEpoch: 1,
                policyEpoch: 1,
              );
              final initial = backwards ? 1 : 0;
              final harness = _Harness(
                initialIndex: initial,
                posts: work
                    ? const []
                    : [
                        for (var id = 1; id <= 2; id++)
                          _post(
                            id: id,
                            booruType: BooruType.danbooru,
                            host: 'https://danbooru.example',
                            data: _posts.first.booruData,
                          ),
                      ],
                entries: work
                    ? [
                        for (final id in [120, 121])
                          GroupViewerEntry(
                            summary: pixivWorkSummary(
                              works.work(id: id, pageCount: 1),
                              access,
                            ),
                            occurrenceId: id,
                            source: ViewerSourceBinding(_configs[2]),
                          ),
                      ]
                    : null,
                loadMedia: false,
                hideOverlay: true,
                postPresentation: work
                    ? null
                    : const _Presentation('danbooru', commentary: true),
                mediaCapability: work
                    ? BooruGroupCapability(
                        engine: BooruType.pixiv,
                        keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
                        presentation: const PixivWorkPresentation(),
                        createSource: (_, actor) => PixivWorkSource(
                          access: actor,
                          fetchWork: (id) async =>
                              works.work(id: id, pageCount: 1),
                        ),
                      )
                    : null,
              );
              _disposeAfterUnmount(tester, harness.dispose);
              await tester.pumpWidget(harness.build(textScale: scale));
              await tester.pumpAndSettle();
              final pager = _pageViewController(tester);
              if (details) {
                await pager.expandToSnapPoint();
                await tester.pumpAndSettle();
              }
              final origin = details
                  ? tester.getCenter(
                      find
                          .text(
                            work
                                ? 'Work ${120 + initial}'
                                : 'Post ${initial + 1}',
                          )
                          .hitTestable()
                          .first,
                    )
                  : tester.getCenter(
                      find.byKey(ValueKey(('viewer-media', initial))),
                    );
              await tester.flingFrom(
                origin,
                Offset(backwards ? 80 : -80, 0),
                1200,
              );
              await tester.pumpAndSettle();
              expect(pager.page, backwards ? 0 : 1);
              expect(pager.isExpanded, details);
              if (details) {
                final selected = backwards ? 0 : 1;
                final title = find
                    .text(
                      work ? 'Work ${120 + selected}' : 'Post ${selected + 1}',
                    )
                    .hitTestable()
                    .first;
                final paragraph = tester.renderObject<RenderParagraph>(
                  find
                      .descendant(of: title, matching: find.byType(RichText))
                      .first,
                );
                final word = paragraph
                    .getBoxesForSelection(
                      const TextSelection(baseOffset: 0, extentOffset: 4),
                    )
                    .first
                    .toRect();
                await tester.longPressAt(
                  paragraph.localToGlobal(word.center),
                );
                await tester.pumpAndSettle();
                final copy = find.text('Copy').hitTestable();
                expect(copy, findsOneWidget);
                await tester.tap(copy);
                await tester.pumpAndSettle();
                expect(copiedText, contains(work ? 'Work' : 'Post'));
                expect(
                  pager.page,
                  selected,
                  reason:
                      'holding text must select it instead of changing entries',
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  if (_viewerCaptureDirectory.isNotEmpty) {
    testWidgets('capture approved shared Viewer modes', _captureViewerModes);
    testWidgets(
      'capture Pixiv Work shared Viewer modes',
      _capturePixivWorkModes,
    );
  }
  for (final size in [
    const Size(400, 800),
    const Size(844, 390),
    const Size(1200, 800),
  ]) {
    testWidgets(
      'Details retains playback controls for the same video actor at $size',
      (tester) async {
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        _mobileViewport(tester, size: size);
        final post = _post(
          id: 1,
          booruType: BooruType.danbooru,
          host: 'https://danbooru.example',
          data: _posts.first.booruData,
          format: 'mp4',
          videoUrl: 'https://danbooru.example/video/1',
          duration: 90,
        );
        final harness = _Harness(posts: [post], loadMedia: false);
        _disposeAfterUnmount(tester, harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        final controller = _detailsController(tester);
        final player = _PlaybackProbe();
        controller.onBooruVideoPlayerCreated(player, post);
        await controller.playVideo(post);
        await tester.pumpAndSettle();
        final plays = player.plays;
        final pager = _pageViewController(tester);
        await pager.expandToSnapPoint();
        await tester.pumpAndSettle();
        expect(find.byType(PlayPauseButton), findsOneWidget);
        expect(find.byType(VideoProgressBar), findsOneWidget);
        expect(find.byType(MoreOptionsControlButton), findsOneWidget);
        await tester.tap(find.byType(PlayPauseButton));
        await tester.pumpAndSettle();
        expect(player.playing, isFalse);
        expect(
          player.plays,
          plays,
          reason: 'changing layout must not restart the player',
        );
        expect(pager.isExpanded, isTrue);
        expect(controller.currentPost.value, post);
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'first Pixiv Work opens without an unavailable-profile fallback',
    (tester) async {
      _mobileViewport(tester);
      final access = ContentAccessContext.profile(
        config: _configs[2],
        authEpoch: 1,
        policyEpoch: 1,
      );
      final adapter = _PageImageAdapter();
      final firstWorkReady = Completer<void>();
      final harness = _Harness(
        posts: const [],
        initialIndex: 0,
        entries: [
          for (final id in [120, 121])
            GroupViewerEntry(
              summary: pixivWorkSummary(
                works.work(id: id, pageCount: 1),
                access,
              ),
              occurrenceId: id,
              source: ViewerSourceBinding(_configs[2]),
            ),
        ],
        imageAdapter: adapter,
        imageCache: TestImageCache({}),
        mediaCapability: BooruGroupCapability(
          engine: BooruType.pixiv,
          keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
          presentation: const PixivWorkPresentation(),
          createSource: (_, actor) => PixivWorkSource(
            access: actor,
            fetchWork: (id) async {
              if (id == 120) await firstWorkReady.future;
              return works.work(id: id, pageCount: 1);
            },
          ),
        ),
      );
      try {
        await tester.pumpWidget(harness.build());
        final viewerConfig = find.ancestor(
          of: find.byType(PostDetailsPageScaffold<Post>),
          matching: find.byType(CurrentBooruConfigScope),
        );
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () =>
                viewerConfig.evaluate().isNotEmpty &&
                tester
                        .widget<CurrentBooruConfigScope>(viewerConfig)
                        .config
                        .auth ==
                    _configs[2].auth,
            reason: 'captured profile resolves before first Work metadata',
          ),
        );
        firstWorkReady.complete();
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => tester
                .widgetList<PostMedia<Post>>(
                  find.byType(PostMedia<Post>, skipOffstage: false),
                )
                .any(
                  (media) =>
                      media.post.id == 120000 &&
                      media.imageController?.imageInfo.value != null,
                ),
            reason: 'first Pixiv Work image decoded',
          ),
        );
        expect(_pageViewController(tester).page, 0);
        expect(find.byType(MediaGroupPage), findsWidgets);
        expect(find.byType(PostPresentationFallbackWarning), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        if (!firstWorkReady.isCompleted) firstWorkReady.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Pixiv Work Details show listing metadata before its manifest loads',
    (tester) async {
      _mobileViewport(tester);
      final access = ContentAccessContext.profile(
        config: _configs[2],
        authEpoch: 1,
        policyEpoch: 1,
      );
      final manifestReady = Completer<void>();
      final harness = _Harness(
        posts: const [],
        entries: [
          GroupViewerEntry(
            summary: pixivWorkSummary(
              works.work(id: 120, pageCount: 2),
              access,
            ),
            occurrenceId: 'summary-first',
            source: ViewerSourceBinding(_configs[2]),
          ),
        ],
        loadMedia: false,
        mediaCapability: BooruGroupCapability(
          engine: BooruType.pixiv,
          keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
          presentation: const PixivWorkPresentation(),
          createSource: (_, actor) => PixivWorkSource(
            access: actor,
            fetchWork: (_) async {
              await manifestReady.future;
              return works.work(id: 120, pageCount: 2);
            },
          ),
        ),
      );
      try {
        await tester.pumpWidget(harness.build());
        await _pageViewController(tester).expandToSnapPoint();
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => tester
                .widgetList<ArtistSection>(
                  find.byType(ArtistSection, skipOffstage: false),
                )
                .any(
                  (section) => section.commentary.originalTitle == 'Work 120',
                ),
            reason: 'listing Work title is visible before detail metadata',
          ),
        );
        expect(manifestReady.isCompleted, isFalse);
        expect(
          find.byType(RawTagsTile, skipOffstage: false),
          findsWidgets,
          reason: 'known listing tags are available in Details immediately',
        );
        expect(
          find.byType(DefaultPostActionToolbar<Post>).hitTestable(),
          findsNothing,
          reason: 'unresolved Pages cannot expose Post actions',
        );
        manifestReady.complete();
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<ArtistSection>(
                find.byType(ArtistSection, skipOffstage: false),
              )
              .any(
                (section) =>
                    section.commentary.originalTitle == 'Work 120' &&
                    section.commentary.originalDescription ==
                        '<p>Work caption</p>',
              ),
          isTrue,
          reason: 'detail fields enrich the existing Work information',
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!manifestReady.isCompleted) manifestReady.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'unresolved neighboring Pixiv Work shows Summary without Post-only Details',
    (tester) async {
      _mobileViewport(tester);
      final access = ContentAccessContext.profile(
        config: _configs[2],
        authEpoch: 1,
        policyEpoch: 1,
      );
      final nextWorkReady = Completer<void>();
      final harness = _Harness(
        posts: const [],
        loadMedia: false,
        entries: [
          for (final id in [120, 121])
            GroupViewerEntry(
              summary: pixivWorkSummary(
                works.work(id: id, pageCount: 2),
                access,
              ),
              occurrenceId: id,
              source: ViewerSourceBinding(_configs[2]),
            ),
        ],
        mediaCapability: BooruGroupCapability(
          engine: BooruType.pixiv,
          keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
          presentation: const PixivWorkPresentation(),
          createSource: (_, actor) => PixivWorkSource(
            access: actor,
            fetchWork: (id) async {
              if (id == 121) await nextWorkReady.future;
              return works.work(id: id, pageCount: 2);
            },
          ),
        ),
      );
      try {
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        final pager = _pageViewController(tester);
        await pager.expandToSnapPoint();
        await tester.pumpAndSettle();
        await pager.nextPage(duration: Duration.zero);
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => pager.page == 1,
            reason:
                'outer entry settles while the Work manifest remains pending',
          ),
        );
        expect(pager.page, 1);
        final nextDetails = find.byKey(
          const ValueKey(('viewer-details-scroll', 1)),
          skipOffstage: false,
        );
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => tester
                .widgetList<ArtistSection>(
                  find.descendant(
                    of: nextDetails,
                    matching: find.byType(
                      ArtistSection,
                      skipOffstage: false,
                    ),
                  ),
                )
                .any(
                  (section) => section.commentary.originalTitle == 'Work 121',
                ),
            reason: 'neighbor Work displays its listing summary while loading',
          ),
        );
        expect(
          find.descendant(
            of: nextDetails,
            matching: find.byType(
              SimplePostStatsTile,
              skipOffstage: false,
            ),
          ),
          findsNothing,
          reason: 'a Work without a Post cannot build Post statistics',
        );
        expect(tester.takeException(), isNull);
        nextWorkReady.complete();
        await tester.pumpAndSettle();
        final pageToolbar = find.descendant(
          of: nextDetails,
          matching: find.byType(
            DefaultPostActionToolbar<Post>,
            skipOffstage: false,
          ),
        );
        expect(pageToolbar, findsWidgets);
        expect(
          tester
              .widget<DefaultPostActionToolbar<Post>>(pageToolbar.first)
              .post
              .id,
          121000,
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!nextWorkReady.isCompleted) nextWorkReady.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      }
    },
  );

  for (final mode in ['high', 'original', 'failed']) {
    testWidgets(
      'initial Pixiv cover hands off to a decoded Page or error ($mode)',
      (tester) async {
        _mobileViewport(tester);
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        const coverUrl = 'https://i.pximg.net/large/120_p0.jpg';
        const pagePreviewUrl = 'https://i.pximg.net/large/120_first_page.jpg';
        final work = works.work(
          id: 120,
          pageCount: 3,
          // Detail metadata can replace the listing's cover URL. Page zero
          // resolves from the top-level image_urls, not meta_pages.
          sample: pagePreviewUrl,
          pages: [
            {
              'image_urls': {
                'large': pagePreviewUrl,
                'square_medium': 'https://i.pximg.net/thumb/120_p0.jpg',
                'original': 'https://i.pximg.net/original/120_p0.jpg',
              },
            },
            works.page(120, 1),
            works.page(120, 2),
          ],
        );
        final adapter = _ReplayableImageAdapter();
        final manifestReady = Completer<void>();
        final harness = _Harness(
          posts: const [],
          entries: [
            GroupViewerEntry(
              summary: pixivWorkSummary(works.work(id: 120), access),
              occurrenceId: 'first-cover',
              source: ViewerSourceBinding(_configs[2]),
            ),
          ],
          imageAdapter: adapter,
          imageCache: TestImageCache({}),
          postQuality: mode == 'original'
              ? PostQuality.original
              : PostQuality.high,
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (_) async {
                await manifestReady.future;
                return work;
              },
            ),
          ),
        );
        Finder coverPixels() => find.descendant(
          of: find.byType(BooruImage, skipOffstage: false),
          matching: find.byType(ExtendedRawImage, skipOffstage: false),
        );
        try {
          await tester.pumpWidget(harness.build());
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () => adapter.pending.keys.any(
                (url) => url.contains('/large/120_p0.jpg'),
              ),
              reason: 'the timeline cover begins loading',
            ),
          );
          adapter.complete(
            adapter.pending.keys.firstWhere(
              (url) => url.contains('/large/120_p0.jpg'),
            ),
            lowerPng,
          );
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () => tester
                  .widgetList<ExtendedRawImage>(coverPixels())
                  .any((image) => image.image != null),
              reason: 'the first Work cover decodes',
            ),
          );
          final coverElement = coverPixels().evaluate().first;
          manifestReady.complete();
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () => tester
                  .widgetList<MediaGroupPage>(
                    find.byType(MediaGroupPage, skipOffstage: false),
                  )
                  .any((page) => page.checkpoint.pages != null),
              reason: 'the first Work PageView is mounted',
            ),
          );
          expect(
            coverPixels().evaluate(),
            contains(coverElement),
            reason: 'manifest handoff must retain the decoded cover element',
          );
          expect(
            tester
                .widget<ExtendedRawImage>(
                  find.byElementPredicate((element) => element == coverElement),
                )
                .image,
            isNotNull,
            reason: 'the cover still has image pixels while Page media loads',
          );
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () => adapter.pending.keys.any(
                (url) => url.contains('/large/120_first_page.jpg'),
              ),
              reason: 'the first Page starts decoding its own preview',
            ),
          );
          adapter.complete(
            adapter.pending.keys.firstWhere(
              (url) => url.contains('/large/120_first_page.jpg'),
            ),
            mode == 'failed' ? Uint8List.fromList([1, 2, 3]) : targetPng,
          );
          if (mode == 'failed') {
            // Both the preview and the target must fail before the image
            // pipeline declares terminal failure. A pending target is not
            // proof that the display has no recoverable image.
            await tester.runAsync(
              () => pumpUntil(
                tester,
                () => adapter.pending.keys.any(
                  (url) => url.contains('media/120000'),
                ),
                reason: 'the failed Page target is requested',
              ),
            );
            for (final url in adapter.pending.keys.toList()) {
              if (url.contains('media/120000')) {
                adapter.complete(url, Uint8List.fromList([1, 2, 3]));
              }
            }
          }
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () =>
                  coverPixels().evaluate().isEmpty &&
                  (mode == 'failed'
                      ? find
                            .byType(ErrorPlaceholder, skipOffstage: false)
                            .evaluate()
                            .isNotEmpty
                      : tester
                            .widgetList<PostMedia<Post>>(
                              find.byType(PostMedia<Post>, skipOffstage: false),
                            )
                            .any(
                              (media) =>
                                  media.post.id == 120000 &&
                                  media.imageController?.imageInfo.value !=
                                      null,
                            )),
              reason: 'the Page replaces its still-mounted cover',
            ),
          );
          if (mode == 'original') {
            await tester.runAsync(
              () => pumpUntil(
                tester,
                () => adapter.pending.keys.any(
                  (url) => url.contains('/original/120_p0.jpg'),
                ),
                reason:
                    'original download is still pending after preview handoff',
              ),
            );
            final page = tester
                .widgetList<PostMedia<Post>>(
                  find.byType(PostMedia<Post>, skipOffstage: false),
                )
                .firstWhere((media) => media.post.id == 120000);
            expect(page.imageController?.imageInfo.value?.image.width, 8);
            expect(
              adapter.pending.entries
                  .where((entry) => entry.key.contains('/original/120_p0.jpg'))
                  .single
                  .value
                  .isCompleted,
              isFalse,
            );
          }
          expect(find.byType(MediaGroupPageIndicator), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          if (!manifestReady.isCompleted) manifestReady.complete();
          for (final pending in adapter.pending.values) {
            if (!pending.isCompleted) pending.complete(targetPng);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
          await tester.pump();
        }
      },
    );
  }

  testWidgets('Pixiv cover does not obscure manually blocked media', (
    tester,
  ) async {
    _mobileViewport(tester);
    final access = ContentAccessContext.profile(
      config: _configs[2],
      authEpoch: 1,
      policyEpoch: 1,
    );
    final adapter = _ReplayableImageAdapter();
    final harness = _Harness(
      posts: const [],
      entries: [
        GroupViewerEntry(
          summary: pixivWorkSummary(works.work(id: 120, pageCount: 1), access),
          occurrenceId: 'manual-media',
          source: ViewerSourceBinding(_configs[2]),
        ),
      ],
      loadMedia: false,
      imageAdapter: adapter,
      imageCache: TestImageCache({}),
      mediaCapability: BooruGroupCapability(
        engine: BooruType.pixiv,
        keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
        presentation: const PixivWorkPresentation(),
        createSource: (_, actor) => PixivWorkSource(
          access: actor,
          fetchWork: (id) async => works.work(id: id, pageCount: 1),
        ),
      ),
    );
    try {
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      expect(find.byType(BooruImage, skipOffstage: false), findsNothing);
      expect(
        find.byType(BlockedMediaPlaceholder, skipOffstage: false),
        findsWidgets,
      );
      expect(adapter.requests, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    }
  });

  for (final quality in [PostQuality.high, PostQuality.original]) {
    testWidgets(
      'adjacent Work images paint before crossing half the outer swipe ($quality)',
      (tester) async {
        _mobileViewport(tester);
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        final adapter = _PageImageAdapter();
        final harness = _Harness(
          posts: const [],
          initialIndex: 1,
          entries: [
            for (final id in [120, 121, 122])
              GroupViewerEntry(
                summary: pixivWorkSummary(
                  works.work(id: id, pageCount: 1),
                  access,
                ),
                occurrenceId: id,
                source: ViewerSourceBinding(_configs[2]),
              ),
          ],
          imageAdapter: adapter,
          postQuality: quality,
          imageCache: TestImageCache({}),
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (id) async => works.work(id: id, pageCount: 1),
            ),
          ),
        );
        final captureKey = GlobalKey();
        try {
          await tester.pumpWidget(
            RepaintBoundary(key: captureKey, child: harness.build()),
          );
          await tester.pumpAndSettle();
          PostMedia<Post>? neighbor(int id) => tester
              .widgetList<PostMedia<Post>>(
                find.byType(PostMedia<Post>, skipOffstage: false),
              )
              .where((media) => media.post.id == id)
              .firstOrNull;
          expect(
            neighbor(120000),
            isNotNull,
            reason: 'previous Work prepares its real image before selection',
          );
          expect(
            neighbor(122000),
            isNotNull,
            reason: 'next Work prepares its real image before selection',
          );
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () =>
                  neighbor(120000)?.imageController?.loadState.value ==
                      LoadState.completed &&
                  neighbor(122000)?.imageController?.loadState.value ==
                      LoadState.completed,
              reason: 'both adjacent Work images decoded',
            ),
          );
          final pager = _pageViewController(tester);
          for (final direction in [-1.0, 1.0]) {
            final drag = await tester.startGesture(
              Offset(direction < 0 ? 330 : 70, 700),
            );
            await drag.moveBy(Offset(direction * 24, 0));
            await drag.moveBy(Offset(direction * 76, 0));
            await tester.pump();
            expect(
              pager.page,
              1,
              reason: 'the selected Work has not changed below half way',
            );
            final media = neighbor(direction < 0 ? 122000 : 120000)!;
            final raw = find.descendant(
              // Rebuilding the neighbor replaces its PostMedia widget object
              // even when the decoded image remains mounted. Find by identity
              // of the Page rather than the previous widget instance.
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is PostMedia<Post> &&
                    widget.post.id == media.post.id,
                skipOffstage: false,
              ),
              matching: find.byType(
                ExtendedRawImage,
                skipOffstage: false,
              ),
            );
            expect(
              tester
                  .getRect(raw.first)
                  .overlaps(const Rect.fromLTWH(0, 0, 400, 800)),
              isTrue,
            );
            await drag.moveBy(Offset(direction * 135, 0));
            await tester.pump();
            expect(
              (pager.precisePage.value! - 1).abs(),
              greaterThan(0.5),
              reason: 'the held outer swipe crossed the halfway threshold',
            );
            expect(
              pager.page,
              1,
              reason: 'a held swipe must not commit the new Work at halfway',
            );
            expect(
              raw,
              findsWidgets,
              reason: 'the decoded neighbor remains mounted during the swipe',
            );
            await drag.cancel();
            await tester.pumpAndSettle();
            pager.pageController.jumpToPage(1);
            await tester.pumpAndSettle();
          }
          final viewerScaffold = tester.state(
            find.byType(PostDetailsPageScaffold<Post>),
          );
          final destinationWork = find.byWidgetPredicate(
            (widget) =>
                widget is MediaGroupPage && widget.entry.occurrenceId == 122,
            skipOffstage: false,
          );
          final destinationPage = tester.state(destinationWork);
          final settleGesture = await tester.startGesture(
            const Offset(200, 700),
          );
          await settleGesture.moveBy(const Offset(-24, 0));
          await settleGesture.moveBy(const Offset(-266, 0));
          await tester.pump();
          await settleGesture.up();
          var paintedFrames = 0;
          var settled = false;
          for (var frame = 0; frame < 120; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final selectedImage = neighbor(122000);
            expect(
              selectedImage?.imageController?.loadState.value,
              LoadState.completed,
              reason:
                  'the target image remains decoded in settlement frame $frame',
            );
            final targetRaw = find.descendant(
              of: find.byWidget(selectedImage!),
              matching: find.byType(ExtendedRawImage),
            );
            expect(
              targetRaw,
              findsWidgets,
              reason: 'the decoded target remains mounted in frame $frame',
            );
            expect(
              tester
                  .widgetList<ExtendedRawImage>(targetRaw)
                  .any(
                    (image) => image.image != null,
                  ),
              isTrue,
              reason: 'the decoded target has pixels in frame $frame',
            );
            if (pager.page == 2) {
              paintedFrames++;
              final pixelsVisible = await tester.runAsync(() async {
                final boundary =
                    captureKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage();
                try {
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.rawRgba,
                  );
                  if (data == null) return false;
                  final bytes = data.buffer.asUint8List();
                  final center =
                      tester.getRect(targetRaw.first).center -
                      tester.getTopLeft(find.byKey(captureKey));
                  final x = center.dx.round().clamp(0, image.width - 1).toInt();
                  final y = center.dy
                      .round()
                      .clamp(0, image.height - 1)
                      .toInt();
                  final pixelIndex = (y * image.width + x) * 4;
                  return bytes[pixelIndex] == 0 &&
                      bytes[pixelIndex + 1] == 0 &&
                      bytes[pixelIndex + 2] == 255 &&
                      bytes[pixelIndex + 3] == 255;
                } finally {
                  image.dispose();
                }
              });
              expect(
                pixelsVisible,
                isTrue,
                reason:
                    'the selected Work must render blue pixels in settlement frame $frame',
              );
            }
            if (paintedFrames >= 4 &&
                !pager.pageController.position.isScrollingNotifier.value) {
              settled = true;
              break;
            }
          }
          expect(
            settled,
            isTrue,
            reason: 'the pager must settle within the bounded frame guard',
          );
          expect(paintedFrames, greaterThanOrEqualTo(4));
          await tester.pumpAndSettle();
          expect(pager.page, 2);
          expect(
            tester.state(destinationWork),
            same(destinationPage),
            reason: 'the selected Work must keep its media state',
          );
          expect(
            tester.state(find.byType(PostDetailsPageScaffold<Post>)),
            same(viewerScaffold),
            reason: 'settlement must not remount decoded neighboring media',
          );
          expect(
            neighbor(122000)?.imageController?.loadState.value,
            LoadState.completed,
          );
          expect(
            adapter.requests.where(
              (url) =>
                  url.contains('/original/') &&
                  !url.contains('/121_p0') &&
                  !url.contains('/122_p0'),
            ),
            isEmpty,
            reason: 'inactive neighboring Works must never fetch originals',
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  for (final size in [const Size(400, 800), const Size(844, 390)]) {
    testWidgets('tapping Details letterboxing returns to Immersive at $size', (
      tester,
    ) async {
      _mobileViewport(tester, size: size);
      final post = _post(
        id: 1,
        booruType: BooruType.danbooru,
        host: 'https://danbooru.example',
        data: _posts.first.booruData,
        width: 400,
        height: 1600,
      );
      final harness = _Harness(
        posts: [post],
        hideOverlay: true,
        reduceAnimations: false,
        imageAdapter: _TestImageAdapter(false, bytes: portraitPng),
        imageCache: TestImageCache({}),
      );
      try {
        await tester.pumpWidget(harness.build());
        await _waitForCurrentImage(tester);
        final pager = _pageViewController(tester);
        final shared = tester.state(find.byType(PostDetailsPageView));
        await pager.expandToSnapPoint();
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const ValueKey(('viewer-media', 0))),
        );
        final point = Offset(rect.left + 8, rect.top + rect.height * .5);
        // This point is in the media frame, outside the transformed Post widget.
        expect(
          tester.getRect(find.byType(PostDetailsItem<Post>)).contains(point),
          isFalse,
        );
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(pager.isExpanded, isFalse);
        expect(pager.overlay.value, isFalse);
        expect(tester.state(find.byType(PostDetailsPageView)), same(shared));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      }
    });
  }

  for (final fromDetails in [false, true]) {
    testWidgets(
      'actual media retains visible snap frames near endpoint, Details=$fromDetails',
      (tester) async {
        _mobileViewport(tester);
        final post = _post(
          id: 1,
          booruType: BooruType.danbooru,
          host: 'https://danbooru.example',
          data: _posts.first.booruData,
          width: 800,
          height: 800,
        );
        final harness = _Harness(posts: [post], reduceAnimations: false);
        _disposeAfterUnmount(tester, harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        await _waitForCurrentImage(tester);
        final pager = _pageViewController(tester);
        if (fromDetails) {
          await pager.expandToSnapPoint();
          await tester.pumpAndSettle();
        }
        double progress() => tester
            .widgetList<ViewerPresentationTransition>(
              find.byType(ViewerPresentationTransition),
            )
            .first
            .progress;
        final gesture = await tester.startGesture(
          Offset(200, fromDetails ? 200 : 500),
        );
        await gesture.moveBy(Offset(0, fromDetails ? 360 : -360));
        await tester.pump();
        final held = progress();
        expect(held, inExclusiveRange(0, 1));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        expect(progress(), inExclusiveRange(0, 1));
        expect(progress(), fromDetails ? lessThan(held) : greaterThan(held));
        await tester.pumpAndSettle();
        expect(progress(), fromDetails ? 0 : 1);
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      },
    );
  }

  for (final size in [const Size(400, 800), const Size(844, 390)]) {
    testWidgets('video quick actions have an opaque surface at $size', (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: size);
      final post = _post(
        id: 1,
        booruType: BooruType.danbooru,
        host: 'https://danbooru.example',
        data: _posts.first.booruData,
        format: 'mp4',
        videoUrl: 'https://danbooru.example/video/1',
        duration: 90,
      );
      final harness = _Harness(posts: [post], loadMedia: false);
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final preview = find.byWidgetPredicate(
        (widget) => widget is CustomScrollView && widget.shrinkWrap,
      );
      expect(preview, findsOneWidget);
      final surfaces = tester.widgetList<DecoratedSliver>(
        find.descendant(of: preview, matching: find.byType(DecoratedSliver)),
      );
      expect(surfaces.length, greaterThanOrEqualTo(2));
      for (final surface in surfaces) {
        expect((surface.decoration as BoxDecoration).color?.a, 1);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    });
  }

  testWidgets('repeated video controls activate only the settled occurrence', (
    tester,
  ) async {
    _mobileViewport(tester);
    final post = _post(
      id: 1,
      booruType: BooruType.danbooru,
      host: 'https://danbooru.example',
      data: _posts.first.booruData,
      format: 'mp4',
      videoUrl: 'https://danbooru.example/video/1',
      duration: 90,
    );
    final harness = _Harness(posts: [post, post], loadMedia: false);
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final controller = _detailsController(tester);
    final pager = _pageViewController(tester);
    await pager.expandToSnapPoint();
    await tester.pumpAndSettle();

    Finder controls(int index) => find.byWidgetPredicate(
      (widget) =>
          widget is PostDetailsVideoControlsMobile && widget.pageIndex == index,
      skipOffstage: false,
    );
    PlayPauseButton play(int index) => tester.widget<PlayPauseButton>(
      find.descendant(
        of: controls(index),
        matching: find.byType(PlayPauseButton, skipOffstage: false),
      ),
    );
    for (final active in [0, 1]) {
      pager.jumpToPage(active);
      await tester.pumpAndSettle();
      controller.videoProgress.value = const VideoProgress(
        Duration(seconds: 90),
        Duration(seconds: 17),
      );
      controller.isVideoPlaying.value = true;
      await tester.pump();
      expect(play(active).isPlaying, same(controller.isVideoPlaying));
      expect(play(1 - active).isPlaying.value, isFalse);
      final activeTimes = tester.widgetList<VideoTimeText>(
        find.descendant(
          of: controls(active),
          matching: find.byType(VideoTimeText, skipOffstage: false),
        ),
      );
      final inactiveTimes = tester.widgetList<VideoTimeText>(
        find.descendant(
          of: controls(1 - active),
          matching: find.byType(VideoTimeText, skipOffstage: false),
        ),
      );
      expect(
        activeTimes.map((time) => time.duration),
        contains(const Duration(seconds: 17)),
      );
      expect(
        inactiveTimes.map((time) => time.duration),
        orderedEquals([Duration.zero, const Duration(seconds: 90)]),
      );
      expect(
        find.ancestor(
          of: find.descendant(
            of: controls(1 - active),
            matching: find.byType(PlayPauseButton, skipOffstage: false),
          ),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer && widget.ignoring,
            skipOffstage: false,
          ),
        ),
        findsWidgets,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
    await tester.pump();
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'Details preserves Classic Comic return position, reduced=$reduced',
      (tester) async {
        _mobileViewport(tester);
        final comic = _post(
          id: 1,
          booruType: BooruType.danbooru,
          host: 'https://danbooru.example',
          data: _posts.first.booruData,
          height: 600,
        );
        final harness = _Harness(posts: [comic], reduceAnimations: reduced);
        _disposeAfterUnmount(tester, harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        await _waitForCurrentImage(tester);
        final immersive = tester
            .widget<PostViewerTransformationScope>(
              find.byType(PostViewerTransformationScope),
            )
            .controller
            .transformationController;
        final reading = immersive.value.clone()
          ..setTranslationRaw(-400, -500, 0);
        immersive.value = reading;
        await tester.pumpAndSettle();
        final usableReading = immersive.value.clone();
        Future<void> classicTap() async {
          final detector = tester.widget<GestureDetector>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is GestureDetector &&
                  widget.onDoubleTapDown != null &&
                  widget.onDoubleTap != null,
            ),
          );
          detector.onDoubleTapDown!(
            TapDownDetails(localPosition: const Offset(200, 400)),
          );
          detector.onDoubleTap!();
          await tester.pumpAndSettle();
        }

        await classicTap();
        expect(
          immersive.value.getMaxScaleOnAxis(),
          greaterThan(usableReading.getMaxScaleOnAxis()),
        );
        final detailZoom = immersive.value.clone();
        final pager = _pageViewController(tester);
        await pager.expandToSnapPoint();
        await tester.pumpAndSettle();
        await pager.resetSheet();
        await tester.pumpAndSettle();
        expect(immersive.value, detailZoom);
        await classicTap();
        expect(immersive.value.storage, orderedEquals(usableReading.storage));
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'Back closes a child popup first and then exits the Details viewer',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final live = _LiveRouteHarness(
        loadNext: (_) async => PostResult<Post>.empty(),
      );
      _disposeAfterUnmount(tester, live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final pager = _pageViewController(tester);
      await pager.expandToSnapPoint();
      await tester.pumpAndSettle();
      final popup = showDialog<void>(
        context: tester.element(find.byType(PostDetailsPageView)),
        builder: (context) =>
            const KurumiDialog(child: Text('Viewer child popup')),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await popup;
      expect(find.text('Viewer child popup'), findsNothing);
      expect(find.byType(PostDetailsPageView), findsOneWidget);
      expect(pager.isExpanded, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailsPageView), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      live.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'Details interpolates zoom and pan on the same loaded media in both directions',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final harness = _Harness(posts: [_posts.first], reduceAnimations: false);
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      final pager = _pageViewController(tester);
      final immersive = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      immersive.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-80, -300, 0);
      await tester.pumpAndSettle();
      final saved = immersive.value.clone();
      final imageController = tester
          .widget<PostMedia<Post>>(find.byType(PostMedia<Post>))
          .imageController;
      final display = tester
          .widget<InteractiveViewerExtended>(
            find.byType(InteractiveViewerExtended),
          )
          .controller!;

      await pager.expandToSnapPoint();
      await tester.pump();
      expect(
        display.value,
        saved,
        reason: 'the first frame must not snap zoom to identity',
      );
      await tester.pump(const Duration(milliseconds: 70));
      expect(display.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(
        display.value.getMaxScaleOnAxis(),
        lessThan(saved.getMaxScaleOnAxis()),
      );
      expect(immersive.value, saved);
      await tester.pumpAndSettle();
      expect(display.value, Matrix4.identity());
      expect(
        tester
            .widget<PostMedia<Post>>(find.byType(PostMedia<Post>))
            .imageController,
        same(imageController),
      );

      await pager.resetSheet();
      await tester.pump();
      expect(
        display.value,
        Matrix4.identity(),
        reason: 'return must start at the Details transform',
      );
      await tester.pump(const Duration(milliseconds: 70));
      expect(display.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(
        display.value.getMaxScaleOnAxis(),
        lessThan(saved.getMaxScaleOnAxis()),
      );
      await tester.pumpAndSettle();
      expect(display.value, saved);
      expect(
        tester
            .widget<InteractiveViewerExtended>(
              find.byType(InteractiveViewerExtended),
            )
            .controller,
        same(display),
      );
      expect(
        tester
            .widget<PostMedia<Post>>(find.byType(PostMedia<Post>))
            .imageController,
        same(imageController),
      );
      await pager.expandToSnapPoint();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await pager.resetSheet();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await pager.expandToSnapPoint();
      await tester.pumpAndSettle();
      expect(pager.isExpanded, isTrue);
      expect(display.value, Matrix4.identity());
      expect(immersive.value, saved);
      await pager.resetSheet();
      await tester.pumpAndSettle();
      expect(display.value, saved);
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    },
  );

  for (final initialHide in [false, true]) {
    testWidgets(
      'zoomed single tap keeps UI visible and fit resumes paging, initialHide=$initialHide',
      (tester) async {
        _mobileViewport(tester);
        final harness = _Harness(
          posts: [_posts.first],
          hideOverlay: initialHide,
        );
        _disposeAfterUnmount(tester, harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        await _waitForCurrentImage(tester);
        final pager = _pageViewController(tester);
        pager.hideAllUI();
        final transform = tester
            .widget<PostViewerTransformationScope>(
              find.byType(PostViewerTransformationScope),
            )
            .controller
            .transformationController;
        transform.value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-200, -400, 0);
        await tester.pumpAndSettle();
        expect(pager.zoom.value, isTrue);
        await tester.tapAt(const Offset(200, 400));
        await tester.pump(kDoubleTapTimeout);
        await tester.pumpAndSettle();
        expect(pager.overlay.value, isTrue);
        transform.value = Matrix4.diagonal3Values(2.1, 2.1, 1)
          ..setTranslationRaw(-210, -420, 0);
        await tester.pumpAndSettle();
        expect(pager.overlay.value, isTrue);
        pager.hideAllUI();
        transform.value = Matrix4.diagonal3Values(1.000001, 1.000001, 1)
          ..setTranslationRaw(0.25, -0.125, 0);
        await tester.pumpAndSettle();
        expect(pager.zoom.value, isFalse);
        expect(pager.swipe.value, isTrue);
        expect(pager.overlay.value, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      },
    );
  }

  for (final visible in [false, true]) {
    testWidgets(
      'double-tap zoom preserves overlay and system bars, visible=$visible',
      (tester) async {
        _mobileViewport(tester);
        final harness = _Harness(posts: [_posts.first], hideOverlay: !visible);
        _disposeAfterUnmount(tester, harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        await _waitForCurrentImage(tester);
        final pager = _pageViewController(tester);
        final systemCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
              systemCalls.add(call);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        for (final zoomed in [true, false]) {
          await tester.tapAt(const Offset(200, 400));
          await tester.pump(kDoubleTapMinTime);
          await tester.tapAt(const Offset(200, 400));
          await tester.pumpAndSettle();
          expect(pager.zoom.value, zoomed);
          expect(pager.overlay.value, visible);
          expect(pager.bottomSheet.value, visible);
          expect(systemCalls, isEmpty);
          await tester.pump(kDoubleTapTimeout);
        }
      },
    );
  }

  testWidgets('a pending media tap is discarded when the Viewer unmounts', (
    tester,
  ) async {
    _mobileViewport(tester);
    final harness = _Harness(posts: [_posts.first]);
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);
    await tester.tap(find.byKey(const ValueKey(('viewer-media', 0))));
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
    await tester.pump(kDoubleTapMinTime);
    expect(tester.takeException(), isNull);
  });

  testWidgets('distant navigation evicts ordinary Post zoom checkpoints', (
    tester,
  ) async {
    _mobileViewport(tester);
    final posts = [
      for (var id = 10; id < 22; id++)
        _post(
          id: id,
          booruType: BooruType.danbooru,
          host: 'https://danbooru.example',
          data: _posts.first.booruData,
        ),
    ];
    final harness = _Harness(posts: posts);
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);
    final pager = _pageViewController(tester);
    final firstScope = find.ancestor(
      of: find.byKey(const ValueKey(('viewer-media', 0))),
      matching: find.byType(PostViewerTransformationScope),
    );
    final first = tester
        .widget<PostViewerTransformationScope>(firstScope)
        .controller
        .transformationController;
    first.value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-100, -400, 0);
    await tester.pumpAndSettle();
    pager.jumpToPage(8);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(('viewer-media', 0))), findsNothing);
    expect(
      find.byType(PostViewerOccurrence).evaluate().length,
      lessThanOrEqualTo(3),
    );
    final distantScope = find.ancestor(
      of: find.byKey(const ValueKey(('viewer-media', 8))),
      matching: find.byType(PostViewerTransformationScope),
    );
    expect(
      tester
          .widget<PostViewerTransformationScope>(distantScope)
          .controller
          .transformationController
          .value
          .isIdentity(),
      isTrue,
    );
    pager.jumpToPage(0);
    await tester.pumpAndSettle();
    final restored = tester
        .widget<PostViewerTransformationScope>(firstScope)
        .controller
        .transformationController;
    expect(restored, isNot(same(first)));
    expect(restored.value.isIdentity(), isTrue);
    expect(
      find.byType(PostViewerOccurrence).evaluate().length,
      lessThanOrEqualTo(3),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
    await tester.pump();
  });

  testWidgets('24 repeated Works bound checkpoints and controller lifetime', (
    tester,
  ) async {
    _mobileViewport(tester);
    final access = ContentAccessContext.profile(
      config: _configs[2],
      authEpoch: 1,
      policyEpoch: 1,
    );
    final entries = <ViewerEntry>[
      for (var i = 0; i < 24; i++)
        GroupViewerEntry(
          summary: pixivWorkSummary(works.work(), access),
          occurrenceId: ('repeat', i),
          initialMemberKey: i == 0 ? 'work-page:120:1' : null,
          source: ViewerSourceBinding(_configs[2]),
        ),
    ];
    var requests = 0;
    final harness = _Harness(
      posts: const [],
      entries: entries,
      mediaCapability: BooruGroupCapability(
        engine: BooruType.pixiv,
        keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
        presentation: const PixivWorkPresentation(),
        createSource: (_, actor) => PixivWorkSource(
          access: actor,
          fetchWork: (_) async {
            requests++;
            return works.work();
          },
        ),
      ),
    );
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final pager = _pageViewController(tester);
    final controllers = <PostDetailsController<Post>>{};
    MediaGroupPage workAt(int index) => tester
        .widgetList<MediaGroupPage>(
          find.byType(MediaGroupPage),
        )
        .singleWhere((work) => work.index == index);
    TransformationController transformAt(int index, int page) => tester
        .widget<PostViewerTransformationScope>(
          find.ancestor(
            of: find.descendant(
              of: find.byWidgetPredicate(
                (widget) => widget is MediaGroupPage && widget.index == index,
              ),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is PostDetailsItem<Post> &&
                    (widget.post!.booruData as PixivPostData).pageIndex == page,
              ),
            ),
            matching: find.byType(PostViewerTransformationScope),
          ),
        )
        .controller
        .transformationController;
    Matrix4? nearbyZoom;
    for (var i = 0; i < 24; i++) {
      pager.jumpToPage(i);
      await tester.pumpAndSettle();
      workAt(i).checkpoint.pages!.jumpToPage(2);
      await tester.pumpAndSettle();
      if (i == 0) {
        transformAt(0, 2).value = Matrix4.diagonal3Values(2, 2, 1)
          ..setTranslationRaw(-100, -400, 0);
        await tester.pumpAndSettle();
        nearbyZoom = transformAt(0, 2).value.clone();
      }
      controllers.addAll(
        tester
            .widgetList<PostDetailsItem<Post>>(
              find.byType(PostDetailsItem<Post>, skipOffstage: false),
            )
            .map((item) => item.detailsController),
      );
      final diagnostics = _viewerDiagnostics(tester);
      expect(diagnostics['mediaCheckpoints'], lessThanOrEqualTo(5));
      expect(diagnostics['selectedMediaControllers'], lessThanOrEqualTo(5));
      expect(
        diagnostics['mediaControllers'],
        lessThanOrEqualTo(
          diagnostics['mountedMediaControllers']! + 5,
        ),
      );
      expect(
        controllers.where(_controllerAlive).length,
        lessThanOrEqualTo(diagnostics['mediaControllers']!),
      );
      // One/two-entry reversals preserve the selection for each occurrence.
      if (i >= 2) {
        pager.jumpToPage(i - 2);
        await tester.pumpAndSettle();
        expect(workAt(i - 2).checkpoint.memberKey, 'work-page:120:2');
        if (i == 2) expect(transformAt(0, 2).value, nearbyZoom);
        pager.jumpToPage(i);
        await tester.pumpAndSettle();
        expect(workAt(i).checkpoint.memberKey, 'work-page:120:2');
      }
      expect(tester.takeException(), isNull);
    }
    pager.jumpToPage(3);
    await tester.pumpAndSettle();
    expect(workAt(3).checkpoint.memberKey, isNull);
    expect(workAt(3).checkpoint.pages!.page, 0);
    expect(workAt(3).checkpoint.transforms, isEmpty);
    expect(transformAt(3, 0).value.isIdentity(), isTrue);
    pager.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(workAt(0).checkpoint.memberKey, 'work-page:120:1');
    expect(workAt(0).checkpoint.pages!.page, 1);
    expect(
      requests,
      1,
      reason: 'evicting reading state keeps the shared envelope',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(controllers.where(_controllerAlive), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('24 Posts retain nearby scroll and zoom and evict distant state', (
    tester,
  ) async {
    _mobileViewport(tester);
    final posts = [
      for (var i = 0; i < 24; i++)
        _post(
          id: 10 + i,
          booruType: BooruType.danbooru,
          host: 'https://danbooru.example',
          data: _posts.first.booruData,
        ),
    ];
    final harness = _Harness(
      posts: posts,
      postPresentation: const _Presentation('danbooru', detailsHeight: 1800),
    );
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final pager = _pageViewController(tester);
    TransformationController transformAt(int index) => tester
        .widget<PostViewerTransformationScope>(
          find.ancestor(
            of: find.byKey(ValueKey(('viewer-media', index))),
            matching: find.byType(PostViewerTransformationScope),
          ),
        )
        .controller
        .transformationController;
    ScrollController scrollAt(int index) => tester
        .widget<CustomScrollView>(
          find.byKey(ValueKey(('viewer-details-scroll', index))),
        )
        .controller!;
    await _waitForCurrentImage(tester);
    transformAt(0).value = Matrix4.diagonal3Values(2, 2, 1)
      ..setTranslationRaw(-100, -400, 0);
    await tester.pumpAndSettle();
    final saved = transformAt(0).value.clone();
    await pager.expandToSnapPoint();
    await tester.pumpAndSettle();
    final offset = scrollAt(0).position.maxScrollExtent.clamp(0.0, 80.0);
    expect(offset, greaterThan(0));
    scrollAt(0).jumpTo(offset);
    await tester.pumpAndSettle();
    for (final index in [1, 2, 0]) {
      pager.jumpToPage(index);
      await tester.pumpAndSettle();
    }
    expect(scrollAt(0).offset, offset);
    // Details uses contain-fit; returning to Immersive restores its saved zoom.
    await pager.resetSheet();
    await tester.pumpAndSettle();
    expect(transformAt(0).value, saved);
    await pager.expandToSnapPoint();
    await tester.pumpAndSettle();
    for (var i = 1; i < 24; i++) {
      pager.jumpToPage(i);
      await tester.pumpAndSettle();
      scrollAt(i).jumpTo(scrollAt(i).position.maxScrollExtent.clamp(0.0, 50.0));
      await tester.pump();
      expect(
        _diagnosticCount(
          tester.state(find.byType(PostDetailsPageView)),
          'scrollOffsets',
        ),
        lessThanOrEqualTo(5),
      );
      expect(
        _diagnosticCount(
          tester.state(find.byType(PostDetailsPageScaffold<Post>)),
          'transformCheckpoints',
        ),
        lessThanOrEqualTo(5),
      );
    }
    pager.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(scrollAt(0).offset, 0);
    await pager.resetSheet();
    await tester.pumpAndSettle();
    expect(transformAt(0).value.isIdentity(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'same-actor Page hydration updates media, toolbar and fallback popup',
    (
      tester,
    ) async {
      _mobileViewport(tester);
      final access = ContentAccessContext.profile(
        config: _configs[2],
        authEpoch: 1,
        policyEpoch: 1,
      );
      MediaGroupState snapshot({required bool updated}) {
        final dto = works.work(
          pages: [
            works.page(120, 0),
            works.page(
              120,
              1,
              original: updated ? 'https://i.pximg.net/new/120_p1.jpg' : null,
            ),
            works.page(120, 2),
          ],
          tags: [
            {'name': updated ? 'updated-tag' : 'old-tag'},
          ],
        );
        final posts = pixivWorkPagePosts(dto, access);
        return MediaGroupState(
          access: access,
          details: pixivWorkDetails(dto, access),
          members: GroupMembersState(
            members: [
              for (var i = 0; i < posts.length; i++)
                GroupMember(
                  reference: pixivPageReference(access, 120, i),
                  memberKey: 'work-page:120:$i',
                  sourcePosition: i,
                  availability: MemberAvailability.available,
                ),
            ],
            resolved: {
              for (var i = 0; i < posts.length; i++)
                pixivPageReference(access, 120, i).identity: PostContentEntry(
                  reference: pixivPageReference(access, 120, i),
                  post: posts[i],
                ),
            },
            firstPageLoaded: true,
            generation: 1,
          ),
        );
      }

      final initial = snapshot(updated: false);
      final state = StateProvider((ref) => initial);
      final harness = _Harness(
        posts: const [],
        entries: [
          GroupViewerEntry(
            summary: initial.details!.summary,
            occurrenceId: 'refreshing-work',
            initialMemberKey: 'work-page:120:1',
            source: ViewerSourceBinding(_configs[2]),
          ),
        ],
        mediaState: state,
        postQuality: PostQuality.original,
        imageAdapter: _PageImageAdapter(),
        imageCache: TestImageCache({}),
      );
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(
        harness.build(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        ),
      );
      await tester.pumpAndSettle();
      final work = tester.widget<MediaGroupPage>(find.byType(MediaGroupPage));
      final checkpoint = work.checkpoint;
      final details = tester
          .widgetList<PostDetailsItem<Post>>(
            find.byType(PostDetailsItem<Post>),
          )
          .singleWhere(
            (item) => (item.post!.booruData as PixivPostData).pageIndex == 1,
          )
          .detailsController;
      final pager = _pageViewController(tester);
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.ancestor(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is PostDetailsItem<Post> &&
                    identical(widget.detailsController, details),
              ),
              matching: find.byType(PostViewerTransformationScope),
            ),
          )
          .controller
          .transformationController;
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-100, -400, 0);
      await tester.pumpAndSettle();
      final matrix = transform.value.clone();
      const popupKey = ValueKey('snapshot-fallback');
      final popup = OverlayEntry(
        builder: (context) => UncontrolledProviderScope(
          container: harness.container,
          child: ProviderScope(
            overrides: [hasPremiumLayoutProvider.overrideWithValue(true)],
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: PostDetailsPageViewScope(
                controller: pager,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: DefaultFallbackBackupMoreButton<Post>(
                    key: popupKey,
                    controller: details,
                    layoutConfig: const LayoutConfigs(
                      home: null,
                      details: null,
                      previewDetails: [],
                    ),
                    authConfig: _configs[2].auth,
                    viewerConfig: _configs[2].viewer,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Overlay.of(tester.element(find.byType(PostDetailsPageView)))
          .insert(popup);
      await tester.pumpAndSettle();
      final updated = snapshot(updated: true);
      harness.container.read(state.notifier).state = updated;
      await tester.pumpAndSettle();
      final post = updated.postAt(1)!;
      expect(details.currentPost.value, same(post));
      expect(details.posts.single, same(post));
      expect(
        tester
            .widget<CommonPostPopupMenu>(
              find.descendant(
                of: find.byKey(popupKey),
                matching: find.byType(CommonPostPopupMenu),
              ),
            )
            .post,
        same(post),
      );
      expect(
        tester
            .widgetList<DefaultPostActionToolbar<Post>>(
              find.byType(DefaultPostActionToolbar<Post>),
            )
            .any((toolbar) => identical(toolbar.post, post)),
        isTrue,
      );
      final item = tester
          .widgetList<PostDetailsItem<Post>>(
            find.byType(PostDetailsItem<Post>),
          )
          .singleWhere((item) => identical(item.post, post));
      expect(item.detailsController, same(details));
      expect(item.imageUrlBuilder(post), post.originalImageUrl);
      expect(
        tester.widget<MediaGroupPage>(find.byType(MediaGroupPage)).checkpoint,
        same(checkpoint),
      );
      expect(checkpoint.memberKey, 'work-page:120:1');
      expect(transform.value, matrix);
      popup.remove();
      popup.dispose();
      await tester.pumpAndSettle();
      // Optional Details failure currently remains fail-closed, even with members.
      // This is the documented capability limit, not a Pixiv-only rewrite.
      for (final failed in [false, true]) {
        harness.container.read(state.notifier).state = MediaGroupState(
          access: access,
          members: updated.members,
          failed: failed,
        );
        // Pending optional metadata deliberately keeps its loading animation.
        await tester.pump();
        await tester.pump();
        expect(
          find.byType(DefaultPostActionToolbar<Post>).hitTestable(),
          findsNothing,
        );
        expect(_viewerDiagnostics(tester)['selectedMediaControllers'], 0);
      }
      harness.container.read(state.notifier).state = updated;
      await tester.pumpAndSettle();
      final held = await tester.startGesture(const Offset(200, 400));
      await held.moveBy(const Offset(0, 60));
      await tester.pump();
      harness.container.read(state.notifier).state = const MediaGroupState(
        failed: true,
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await held.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, scale) in [
    (const Size(400, 800), 1.0),
    (const Size(320, 844), 2.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets(
      'Work Pages reuse shared modes, retain holes and independent checkpoints ($size, $scale)',
      (tester) async {
        _mobileViewport(tester);
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        final entries = <ViewerEntry>[
          for (final occurrence in ['first', 'repeat'])
            GroupViewerEntry(
              summary: pixivWorkSummary(works.work(), access),
              occurrenceId: occurrence,
              source: ViewerSourceBinding(_configs[2]),
            ),
          PostViewerEntry(
            post: _posts[2],
            occurrenceId: 'ordinary-post',
            source: ViewerSourceBinding(_configs[2]),
          ),
        ];
        var requests = 0;
        final harness = _Harness(
          posts: const [],
          entries: entries,
          hideOverlay: true,
          reduceAnimations: false,
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (_) async {
                requests++;
                return works.work(
                  pages: [works.page(120, 0), null, works.page(120, 2)],
                );
              },
            ),
          ),
        );
        _disposeAfterUnmount(tester, harness.dispose);
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        final pager = _pageViewController(tester);
        final shared = tester.state(find.byType(PostDetailsPageView));
        expect(requests, 1);
        expect(pager.overlay.value, isFalse);
        final media = find.descendant(
          of: find.byType(MediaGroupPage).first,
          matching: find.byType(PageView),
        );
        await tester.drag(media, Offset(-size.width * .8, 0));
        await tester.pumpAndSettle();
        expect(pager.page, 0);
        expect(find.text('Page unavailable'), findsWidgets);
        expect(
          tester
              .widget<MediaGroupPage>(find.byType(MediaGroupPage).first)
              .checkpoint
              .memberKey,
          'work-page:120:1',
        );
        // A missing original slot exposes no neighboring Page as an action target.
        expect(
          find.byType(DefaultPostActionToolbar<Post>).hitTestable(),
          findsNothing,
        );
        await tester.drag(media, Offset(-size.width * .8, 0));
        await tester.pumpAndSettle();
        expect(pager.page, 0);
        if (size.width == 400 && scale == 1) {
          double progress() => tester
              .widgetList<ViewerPresentationTransition>(
                find.byType(ViewerPresentationTransition),
              )
              .first
              .progress;
          final drag = await tester.startGesture(const Offset(200, 500));
          await drag.moveBy(const Offset(0, -200));
          await tester.pump();
          final held = progress();
          expect(held, inExclusiveRange(0, 1));
          await drag.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 35));
          expect(progress(), inExclusiveRange(held, 1));
        } else {
          await pager.expandToSnapPoint();
        }
        await tester.pumpAndSettle();
        expect(pager.isExpanded, isTrue);
        expect(
          find.byType(DefaultInheritedPostActionToolbar<Post>),
          findsWidgets,
        );
        final normalToolbar = find
            .byType(DefaultPostActionToolbar<Post>)
            .hitTestable()
            .first;
        final toolbarContext = tester.element(normalToolbar);
        expect(
          find.descendant(
            of: normalToolbar,
            matching: find.byType(PixivWorkBookmarkButton),
          ),
          findsOneWidget,
          reason: 'the shared toolbar must target the whole Work by default',
        );
        final toolbarPost = tester
            .widget<DefaultPostActionToolbar<Post>>(normalToolbar)
            .post;
        final pageDetails = PostDetails.of<Post>(toolbarContext);
        final item = tester
            .widgetList<PostDetailsItem<Post>>(
              find.byType(PostDetailsItem<Post>),
            )
            .singleWhere((item) => item.post == toolbarPost);
        expect(pageDetails.controller, same(item.detailsController));
        expect((toolbarPost.booruData as PixivPostData).pageIndex, 2);
        final toolbarScope = ProviderScope.containerOf(
          toolbarContext,
          listen: false,
        );
        expect(toolbarScope.read(contentAccessRequiredProvider), isTrue);
        expect(
          toolbarScope.read(currentContentAccessKeyProvider)?.profileId,
          _configs[2].id,
        );
        final configuration = PostDetailsPageConfiguration.maybeOf(
          toolbarContext,
        )!;
        expect(
          configuration.uiBuilder!.full.keys,
          containsAll([
            DetailsPart.toolbar,
            DetailsPart.tags,
            DetailsPart.fileDetails,
          ]),
        );
        if (size.width == 400 && scale == 1) {
          final work = tester
              .widgetList<MediaGroupPage>(
                find.byType(MediaGroupPage, skipOffstage: false),
              )
              .singleWhere((page) => page.entry.occurrenceId == 'first');
          final selectedPage = work.checkpoint.memberKey;
          expect(selectedPage, 'work-page:120:2');
          await tester.drag(
            find.text('File Details').hitTestable().first,
            Offset(-size.width * .8, 0),
          );
          expect(
            work.checkpoint.memberKey,
            selectedPage,
            reason: 'a swipe over Details must switch Works, not Work Pages',
          );
        } else {
          pager.jumpToPage(1);
        }
        await tester.pumpAndSettle();
        expect(pager.page, 1);
        expect(tester.state(find.byType(PostDetailsPageView)), same(shared));
        expect(pager.isExpanded, isTrue);
        expect(requests, 1);
        expect(find.text('1 / 3'), findsWidgets);
        pager.jumpToPage(2);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(PostDetailsPageView)), same(shared));
        expect(pager.isExpanded, isTrue);
        final ordinaryItem = tester
            .widgetList<PostDetailsItem<Post>>(
              find.byType(PostDetailsItem<Post>),
            )
            .singleWhere((item) => item.post == _posts[2]);
        expect(
          ordinaryItem.detailsController.currentPost.value,
          same(_posts[2]),
        );
        expect(ordinaryItem.detailsController.postAtPage(2), same(_posts[2]));
        expect(ordinaryItem.detailsController.currentPage.value, 2);
        expect(ordinaryItem.detailsController.currentSettledPage.value, 2);
        pager.jumpToPage(0);
        await tester.pumpAndSettle();
        expect(find.text('3 / 3'), findsWidgets);
        // Reading hints are independent from the normal immersive overlay.
        if (size.width == 400 && scale == 1) {
          final drag = await tester.startGesture(const Offset(200, 200));
          await drag.moveBy(const Offset(0, 200));
          await tester.pump();
          expect(
            tester
                .widgetList<ViewerPresentationTransition>(
                  find.byType(ViewerPresentationTransition),
                )
                .first
                .progress,
            inExclusiveRange(0, 1),
          );
          await drag.up();
        } else {
          await pager.resetSheet();
        }
        await tester.pumpAndSettle();
        expect(pager.overlay.value, isFalse);
        final hint = find.descendant(
          of: find.byType(MediaGroupPageIndicator),
          matching: find.byType(AnimatedOpacity),
        );
        expect(tester.widget<AnimatedOpacity>(hint).opacity, 1);
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(hint).opacity, 0);
        expect(pager.overlay.value, isFalse);
        await tester.drag(media, Offset(size.width * .8, 0));
        await tester.pumpAndSettle();
        expect(find.text('2 / 3'), findsOneWidget);
        expect(tester.widget<AnimatedOpacity>(hint).opacity, 1);
        expect(pager.overlay.value, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Details on the next regular Post are ready on the first swipe',
    (tester) async {
      _mobileViewport(tester);
      final harness = _Harness(posts: _posts.take(3).toList());
      try {
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        final pager = _pageViewController(tester);
        await pager.expandToSnapPoint();
        await tester.pumpAndSettle();
        await tester.flingFrom(
          const Offset(200, 650),
          const Offset(-275, 0),
          5000,
        );
        await tester.pumpAndSettle();
        expect(pager.page, 1);
        expect(pager.isExpanded, isTrue);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey(('viewer-details-scroll', 1))),
            matching: find.byType(DefaultInheritedInformationSection<Post>),
          ),
          findsWidgets,
          reason: 'Details must render on first arrival, not after revisiting',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'a new Pixiv Work shows its Details before being revisited',
    (tester) async {
      _mobileViewport(tester);
      final access = ContentAccessContext.profile(
        config: _configs[2],
        authEpoch: 1,
        policyEpoch: 1,
      );
      final harness = _Harness(
        posts: const [],
        entries: [
          for (final id in [120, 121])
            GroupViewerEntry(
              summary: pixivWorkSummary(
                works.work(id: id, pageCount: 2),
                access,
              ),
              occurrenceId: id,
              source: ViewerSourceBinding(_configs[2]),
            ),
        ],
        reduceAnimations: false,
        mediaCapability: BooruGroupCapability(
          engine: BooruType.pixiv,
          keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
          presentation: const PixivWorkPresentation(),
          createSource: (_, actor) => PixivWorkSource(
            access: actor,
            fetchWork: (id) async => works.work(id: id, pageCount: 2),
          ),
        ),
      );
      try {
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();
        final pager = _pageViewController(tester);
        await pager.expandToSnapPoint();
        await tester.pumpAndSettle();
        // Swipe the Details gutter, outside selectable commentary text.
        await tester.flingFrom(
          Offset(
            4,
            tester.getCenter(find.text('Work 120').hitTestable().first).dy,
          ),
          const Offset(-275, 0),
          5000,
        );
        await tester.pumpAndSettle();
        expect(pager.page, 1);
        expect(pager.isExpanded, isTrue);
        final targetDetails = find.descendant(
          of: find.byKey(
            const ValueKey(('viewer-details-scroll', 1)),
            skipOffstage: false,
          ),
          matching: find.byType(
            DefaultPostActionToolbar<Post>,
            skipOffstage: false,
          ),
        );
        expect(
          targetDetails,
          findsWidgets,
          reason: 'the target Work must build Details on its first visit',
        );
        expect(
          tester
              .widget<DefaultPostActionToolbar<Post>>(targetDetails.first)
              .post
              .id,
          121000,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pump();
      }
    },
  );

  for (final backwards in [false, true]) {
    testWidgets(
      'fast flings cannot skip a Work whose Page manifest is still loading, backwards=$backwards',
      (tester) async {
        _mobileViewport(tester);
        final ready = Completer<void>();
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        final entry = GroupViewerEntry(
          summary: pixivWorkSummary(works.work(), access),
          occurrenceId: 'loading-work',
          source: ViewerSourceBinding(_configs[2]),
          initialMemberKey: backwards ? 'work-page:120:2' : null,
        );
        final harness = _Harness(
          posts: const [],
          initialIndex: backwards ? 2 : 0,
          hideOverlay: true,
          reduceAnimations: false,
          loadMedia: false,
          entries: [
            PostViewerEntry(
              post: _posts[2],
              occurrenceId: 'before',
              source: ViewerSourceBinding(_configs[2]),
            ),
            entry,
            PostViewerEntry(
              post: _posts[2],
              occurrenceId: 'after',
              source: ViewerSourceBinding(_configs[2]),
            ),
          ],
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (_) async {
                await ready.future;
                return works.work();
              },
            ),
          ),
        );
        try {
          await tester.pumpWidget(harness.build());
          await tester.pump();
          final pager = _pageViewController(tester);
          final offset = Offset(backwards ? 260 : -260, 0);
          Future<void> fastSwipe() async {
            await tester.flingFrom(const Offset(200, 40), offset, 5000);
            // Wait for outer settlement without waiting for the pending manifest's spinner.
            for (
              var frame = 0;
              frame < 80 &&
                  pager.pageController.position.isScrollingNotifier.value;
              frame++
            ) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            await tester.pump();
            expect(
              pager.pageController.position.isScrollingNotifier.value,
              isFalse,
            );
          }

          await fastSwipe();
          expect(pager.page, 1, reason: 'the first fling enters the Work');
          expect(ready.isCompleted, isFalse);
          await fastSwipe();
          expect(
            pager.page,
            1,
            reason: 'loading is not a proven first/last Page boundary',
          );
          ready.complete();
          await tester.pumpAndSettle();
          final media = tester
              .widgetList<MediaGroupPage>(find.byType(MediaGroupPage))
              .singleWhere(
                (widget) => widget.entry.occurrenceId == 'loading-work',
              );
          expect(media.checkpoint.pages!.page, backwards ? 2 : 0);
          await tester.flingFrom(const Offset(200, 40), offset, 5000);
          for (
            var frame = 0;
            frame < 80 && media.checkpoint.memberKey != 'work-page:120:1';
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(pager.page, 1);
          expect(media.checkpoint.memberKey, 'work-page:120:1');
          expect(
            media.checkpoint.pages!.position.isScrollingNotifier.value,
            isTrue,
          );
          // Start the next fast fling before the preceding Page has settled.
          await tester.flingFrom(const Offset(200, 40), offset, 5000);
          await tester.pumpAndSettle();
          expect(pager.page, 1);
          expect(
            media.checkpoint.memberKey,
            backwards ? 'work-page:120:0' : 'work-page:120:2',
          );
          await fastSwipe();
          await tester.pumpAndSettle();
          expect(
            pager.page,
            backwards ? 0 : 2,
            reason: 'a real Page boundary still reaches its neighboring entry',
          );
          expect(tester.takeException(), isNull);
        } finally {
          if (!ready.isCompleted) ready.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
          await tester.pump();
        }
      },
    );
  }

  testWidgets('a Work with a failed Page manifest remains escapable', (
    tester,
  ) async {
    _mobileViewport(tester);
    final access = ContentAccessContext.profile(
      config: _configs[2],
      authEpoch: 1,
      policyEpoch: 1,
    );
    final entry = GroupViewerEntry(
      summary: pixivWorkSummary(works.work(), access),
      occurrenceId: 'failed-work',
      source: ViewerSourceBinding(_configs[2]),
    );
    final harness = _Harness(
      posts: const [],
      initialIndex: 1,
      hideOverlay: true,
      loadMedia: false,
      entries: [
        PostViewerEntry(
          post: _posts[2],
          occurrenceId: 'before',
          source: ViewerSourceBinding(_configs[2]),
        ),
        entry,
        PostViewerEntry(
          post: _posts[2],
          occurrenceId: 'after',
          source: ViewerSourceBinding(_configs[2]),
        ),
      ],
      mediaCapability: BooruGroupCapability(
        engine: BooruType.pixiv,
        keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
        presentation: const PixivWorkPresentation(),
        createSource: (_, actor) => PixivWorkSource(
          access: actor,
          fetchWork: (_) async =>
              throw StateError('fixture manifest unavailable'),
        ),
      ),
    );
    try {
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final pager = _pageViewController(tester);
      expect(find.text('Page unavailable'), findsWidgets);
      await tester.flingFrom(
        const Offset(200, 40),
        const Offset(-260, 0),
        5000,
      );
      await tester.pumpAndSettle();
      expect(pager.page, 2);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    }
  });

  for (final size in [
    const Size(400, 800),
    const Size(320, 640),
    const Size(844, 390),
  ]) {
    testWidgets(
      'each Work Page fills its own Details frame and travels full width at $size',
      (tester) async {
        _mobileViewport(tester, size: size);
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        final adapter = _PageImageAdapter();
        final harness = _Harness(
          posts: const [],
          entries: [
            GroupViewerEntry(
              summary: pixivWorkSummary(works.work(), access),
              occurrenceId: 'geometry',
              source: ViewerSourceBinding(_configs[2]),
            ),
          ],
          imageAdapter: adapter,
          imageCache: TestImageCache({}),
          reduceAnimations: false,
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (_) async => works.work(),
            ),
          ),
        );
        try {
          await tester.pumpWidget(harness.build());
          await tester.pumpAndSettle();
          final pager = _pageViewController(tester);
          await pager.expandToSnapPoint();
          await tester.pumpAndSettle();
          Future<void> decoded(int page, Size expected) => tester.runAsync(
            () => pumpUntil(
              tester,
              () => tester
                  .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
                  .any(
                    (media) =>
                        media.post.id == 120000 + page &&
                        media.contentSize == expected,
                  ),
              reason: 'Page $page actual geometry',
            ),
          );
          await decoded(0, const Size(2, 8));
          final mediaFrame = find.byKey(const ValueKey(('viewer-media', 0)));
          final frame = tester.getRect(mediaFrame);
          final workPage = tester.widget<MediaGroupPage>(
            find.byType(MediaGroupPage),
          );
          expect(
            workPage.checkpoint.pages!.position.viewportDimension,
            closeTo(size.width, .01),
          );
          final drag = await tester.startGesture(frame.center);
          await drag.moveBy(const Offset(-24, 0));
          await drag.moveBy(Offset(-size.width * .2, 0));
          await tester.pump();
          final scroll = workPage.checkpoint.pages!.position;
          expect(
            scroll.pixels,
            greaterThan(size.width * .15),
            reason: 'the carousel uses unscaled full-width gesture coordinates',
          );
          await drag.up();
          await tester.pumpAndSettle();
          if (workPage.checkpoint.memberKey != 'work-page:120:1') {
            workPage.checkpoint.pages!.jumpToPage(1);
            await tester.pumpAndSettle();
          }
          await decoded(1, const Size(8, 8));
          final image = tester
              .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
              .firstWhere((media) => media.post.id == 120001);
          expect(
            image.contentSize,
            const Size(8, 8),
            reason: 'the cover metadata must not constrain a later Page',
          );
          final raw = find.descendant(
            of: find.byWidget(image),
            matching: find.byType(ExtendedRawImage),
          );
          await tester.runAsync(
            () => pumpUntil(
              tester,
              () => raw.evaluate().isNotEmpty,
              reason: 'square Page painted',
            ),
          );
          final rect = tester.getRect(raw.first);
          final expected = size.width < frame.height
              ? size.width
              : frame.height;
          expect(rect.width, closeTo(expected, 1));
          expect(rect.height, closeTo(expected, 1));
          expect(
            tester.getRect(mediaFrame),
            frame,
            reason: 'Page geometry never shrinks the carousel',
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  for (final enabled in [false, true]) {
    testWidgets(
      'Work metadata and display preloading are bounded and honor automatic loading=$enabled',
      (tester) async {
        _mobileViewport(tester);
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        final fetched = <int>[];
        final adapter = _PageImageAdapter();
        final harness = _Harness(
          posts: const [],
          initialIndex: 2,
          loadMedia: enabled,
          entries: [
            for (var id = 120; id < 127; id++)
              GroupViewerEntry(
                summary: pixivWorkSummary(works.work(id: id), access),
                occurrenceId: id,
                source: ViewerSourceBinding(_configs[2]),
              ),
          ],
          imageAdapter: adapter,
          imageCache: TestImageCache({}),
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (id) async {
                fetched.add(id);
                return works.work(id: id);
              },
            ),
          ),
        );
        try {
          await tester.pumpWidget(harness.build());
          await tester.pumpAndSettle();
          if (enabled) {
            await tester.runAsync(
              () => pumpUntil(
                tester,
                () =>
                    adapter.requests.any(
                      (url) => url.endsWith('/media/121000'),
                    ) &&
                    adapter.requests.any(
                      (url) => url.endsWith('/media/123000'),
                    ) &&
                    adapter.requests.any(
                      (url) => url.endsWith('/media/122001'),
                    ) &&
                    adapter.requests.any(
                      (url) => url.endsWith('/media/122002'),
                    ),
                reason: 'adjacent Work covers and next two Page display renditions before navigation',
              ),
            );
            expect(fetched.toSet(), {121, 122, 123});
            expect(
              adapter.requests.any((url) => url.contains('/original/')),
              isFalse,
            );
          } else {
            expect(fetched.toSet(), {
              122,
            }, reason: 'only the foreground loads metadata');
            expect(adapter.requests, isEmpty);
          }
          expect(_pageViewController(tester).page, 2);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'uncropped Work preview survives metadata handoff and never displays the square thumbnail',
    (tester) async {
      _mobileViewport(tester);
      final access = ContentAccessContext.profile(
        config: _configs[2],
        authEpoch: 1,
        policyEpoch: 1,
      );
      final gate = Completer<void>();
      const square = 'https://i.pximg.net/thumb/120_p0.jpg';
      const preview = 'https://i.pximg.net/large/120_p0.jpg';
      final adapter = ControlledImageAdapter();
      final harness = _Harness(
        posts: const [],
        initialThumbnailUrl: square,
        entries: [
          GroupViewerEntry(
            summary: pixivWorkSummary(works.work(), access),
            occurrenceId: 'pending-cover',
            source: ViewerSourceBinding(_configs[2]),
          ),
        ],
        imageAdapter: adapter,
        imageCache: TestImageCache({square: lowerPng, preview: portraitPng}),
        mediaCapability: BooruGroupCapability(
          engine: BooruType.pixiv,
          keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
          presentation: const PixivWorkPresentation(),
          createSource: (_, actor) => PixivWorkSource(
            access: actor,
            fetchWork: (_) async {
              await gate.future;
              return works.work();
            },
          ),
        ),
      );
      try {
        await tester.pumpWidget(harness.build());
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () => tester
                .widgetList<ExtendedRawImage>(find.byType(ExtendedRawImage))
                .any(
                  (image) =>
                      image.image?.width == 2 && image.image?.height == 8,
                ),
            reason: 'full-aspect preview before metadata',
          ),
        );
        expect(gate.isCompleted, isFalse);
        expect(find.byType(PostMedia<Post>), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        final media = tester.widget<PostMedia<Post>>(
          find.byType(PostMedia<Post>).first,
        );
        expect(media.placeholderMediaBuilder?.call(media.post).url, preview);
        await tester.runAsync(
          () => pumpUntil(
            tester,
            () =>
                media.imageController?.imageInfo.value?.image.width == 2 &&
                media.imageController?.imageInfo.value?.image.height == 8,
            reason: 'same uncropped preview in the real Page while target remains pending',
          ),
        );
        expect(
          adapter.requests.any((request) => request.uri.toString() == square),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  for (final (size, direction) in [
    (const Size(400, 800), TextDirection.ltr),
    (const Size(844, 390), TextDirection.ltr),
    (const Size(400, 800), TextDirection.rtl),
  ]) {
    testWidgets(
      'Work media frame routes black margins to Pages and crosses entry boundaries at $size, $direction',
      (tester) async {
        _mobileViewport(tester, size: size);
        final access = ContentAccessContext.profile(
          config: _configs[2],
          authEpoch: 1,
          policyEpoch: 1,
        );
        final entries = <ViewerEntry>[
          PostViewerEntry(
            post: _posts[2],
            occurrenceId: 'before',
            source: ViewerSourceBinding(_configs[2]),
          ),
          for (final id in [120, 121])
            GroupViewerEntry(
              summary: pixivWorkSummary(
                works.work(id: id, pageCount: id == 121 ? 1 : 3),
                access,
              ),
              occurrenceId: 'work:$id',
              source: ViewerSourceBinding(_configs[2]),
            ),
          PostViewerEntry(
            post: _posts[2],
            occurrenceId: 'after',
            source: ViewerSourceBinding(_configs[2]),
          ),
        ];
        final harness = _Harness(
          posts: const [],
          entries: entries,
          initialIndex: 1,
          direction: direction,
          hideOverlay: true,
          reduceAnimations: false,
          mediaCapability: BooruGroupCapability(
            engine: BooruType.pixiv,
            keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
            presentation: const PixivWorkPresentation(),
            createSource: (_, actor) => PixivWorkSource(
              access: actor,
              fetchWork: (id) async =>
                  works.work(id: id, pageCount: id == 121 ? 1 : 3),
            ),
          ),
        );
        try {
          await tester.pumpWidget(harness.build());
          await tester.pumpAndSettle();
          final pager = _pageViewController(tester);
          final previousSign = direction == TextDirection.ltr ? 1.0 : -1.0;
          Future<void> swipe(bool next) async {
            await tester.dragFrom(
              Offset(size.width * .5, 40),
              Offset(
                (next ? -previousSign : previousSign) * size.width * .7,
                0,
              ),
            );
            await tester.pumpAndSettle();
          }

          String? page(int id) => tester
              .widgetList<MediaGroupPage>(find.byType(MediaGroupPage))
              .firstWhere((widget) => widget.entry.occurrenceId == 'work:$id')
              .checkpoint
              .memberKey;
          // Include the return from Details, where media has a smaller frame.
          await pager.expandToSnapPoint();
          await tester.pumpAndSettle();
          final detailsFrame = tester.getRect(
            find.byKey(const ValueKey(('viewer-media', 1))),
          );
          await tester.dragFrom(
            Offset(8, detailsFrame.center.dy),
            Offset(-previousSign * size.width * .7, 0),
          );
          await tester.pumpAndSettle();
          expect(
            pager.page,
            1,
            reason: 'Details letterboxing belongs to the media Page pager',
          );
          expect(page(120), 'work-page:120:1');
          await tester.dragFrom(
            Offset(8, detailsFrame.center.dy),
            Offset(previousSign * size.width * .7, 0),
          );
          await tester.pumpAndSettle();
          expect(pager.page, 1);
          expect(page(120), 'work-page:120:0');
          await pager.resetSheet();
          await tester.pumpAndSettle();
          await swipe(true);
          expect(pager.page, 1);
          expect(page(120), 'work-page:120:1');
          await swipe(false);
          expect(pager.page, 1);
          expect(page(120), 'work-page:120:0');
          final boundary = await tester.startGesture(
            Offset(size.width * .4, 40),
          );
          await boundary.moveBy(Offset(previousSign * 30, 0));
          await boundary.moveBy(Offset(previousSign * size.width * .25, 0));
          await tester.pump();
          expect(
            pager.precisePage.value,
            inExclusiveRange(0, 1),
            reason: 'the outer entry follows the finger at a Work boundary',
          );
          await boundary.moveBy(Offset(previousSign * size.width * .4, 0));
          await boundary.up();
          await tester.pumpAndSettle();
          expect(
            pager.page,
            0,
            reason: 'outward swipe on the first Page reaches the previous Post',
          );
          await swipe(false);
          expect(
            pager.page,
            0,
            reason: 'the first entry has no previous neighbor',
          );
          await swipe(true);
          expect(pager.page, 1);
          await swipe(true);
          await swipe(true);
          expect(
            pager.page,
            1,
            reason: 'arriving at the last Page does not skip a Work in the same gesture',
          );
          expect(page(120), 'work-page:120:2');
          await swipe(true);
          expect(
            pager.page,
            2,
            reason: 'a fresh outward swipe reaches the next Work',
          );
          await swipe(true);
          expect(
            pager.page,
            3,
            reason: 'a single-image Work passes through to the following Post',
          );
          await swipe(true);
          expect(pager.page, 3, reason: 'the last entry has no next neighbor');
          await swipe(false);
          expect(pager.page, 2);
          await swipe(false);
          expect(pager.page, 1);
          expect(page(120), 'work-page:120:2');
          await swipe(false);
          expect(pager.page, 1);
          expect(page(120), 'work-page:120:1');
          if (size.width == 400 && direction == TextDirection.ltr) {
            await tester.runAsync(
              () => pumpUntil(
                tester,
                () => tester
                    .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
                    .any(
                      (media) =>
                          media.post.booruData is PixivPostData &&
                          (media.post.booruData as PixivPostData).pageIndex ==
                              1 &&
                          media.imageController?.loadState.value ==
                              LoadState.completed,
                    ),
                reason: 'decoded current Work Page before pinch',
              ),
            );
            final upper = await tester.startGesture(
              const Offset(200, 300),
              pointer: 21,
            );
            final lower = await tester.startGesture(
              const Offset(200, 500),
              pointer: 22,
            );
            await upper.moveBy(const Offset(0, -60));
            await lower.moveBy(const Offset(0, 60));
            await tester.pump();
            await upper.moveBy(const Offset(0, -40));
            await lower.moveBy(const Offset(0, 40));
            await upper.up();
            await lower.up();
            await tester.pumpAndSettle();
            expect(pager.zoom.value, isTrue);
            expect(pager.page, 1);
            expect(page(120), 'work-page:120:1');
            expect(pager.isExpanded, isFalse);
            final pinchTop = await tester.startGesture(
              const Offset(200, 250),
              pointer: 23,
            );
            final pinchBottom = await tester.startGesture(
              const Offset(200, 550),
              pointer: 24,
            );
            await pinchTop.moveBy(const Offset(0, 100));
            await pinchBottom.moveBy(const Offset(0, -100));
            await tester.pump();
            await pinchTop.up();
            await pinchBottom.up();
            await tester.pumpAndSettle();
            expect(pager.zoom.value, isFalse);
            expect(pager.overlay.value, isFalse);
            final held = await tester.startGesture(
              const Offset(200, 40),
              pointer: 25,
            );
            await held.moveBy(const Offset(-30, 0));
            await held.moveBy(const Offset(-60, 0));
            await tester.pump();
            final interrupt = await tester.startGesture(
              const Offset(200, 300),
              pointer: 26,
            );
            await interrupt.up();
            await held.up();
            await tester.pumpAndSettle();
            expect(pager.page, 1);
            expect(
              page(120),
              'work-page:120:1',
              reason: 'multi-touch cancels a partially dragged Page',
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          harness.dispose();
          await tester.pump();
        }
      },
    );
  }

  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  testWidgets(
    'live entries append a Post to a group-only viewer without replacing its pager',
    (tester) async {
      _mobileViewport(tester);
      final changes = ChangeNotifier();
      addTearDown(changes.dispose);
      final entries = <ViewerEntry>[
        _groupEntry('group', 10, BookmarkedPoolCategory.series),
      ];
      final harness = _Harness(
        posts: const [],
        entries: entries,
        repository: const _GalleryRepository(),
        entrySource: ViewerEntryLiveSource(
          changes: changes,
          entries: () => entries,
          pagination: PostDetailsLiveSource(
            changes: changes,
            posts: () => const [],
            hasMore: () => false,
            loading: () => false,
            failed: () => false,
            fetchMore: () async {},
          ),
        ),
      );
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final pager = _pageViewController(tester);
      final state = tester.state(find.byType(PostDetailsPageView));
      entries.add(PostViewerEntry(post: _posts.first, occurrenceId: 'post'));
      changes.notifyListeners();
      await tester.pumpAndSettle();
      expect(_pageViewController(tester), same(pager));
      expect(tester.state(find.byType(PostDetailsPageView)), same(state));
      expect(pager.totalPage, 2);
      expect(pager.page, 0);
      pager.jumpToPage(1);
      await tester.pumpAndSettle();
      expect(_detailsController(tester).postAtPage(1), _posts.first);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('slideshow stops before advancing from a Post into a group', (
    tester,
  ) async {
    _mobileViewport(tester);
    final harness = _Harness(
      entries: [
        PostViewerEntry(post: _posts.first, occurrenceId: 'post'),
        _groupEntry('group', 10, BookmarkedPoolCategory.series),
      ],
      repository: const _GalleryRepository(),
    );
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    final pager = _pageViewController(tester);
    await pager.startSlideshow();
    await tester.pump(pager.slideshowOptions.duration);
    await tester.pumpAndSettle();
    expect(pager.slideshowController.state.value.isPaused, isTrue);
    expect(pager.page, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mixed entries keep one pager through Post, Series, Post, Collection, Post',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final entries = <ViewerEntry>[
        PostViewerEntry(post: _posts[0], occurrenceId: 'a'),
        _groupEntry('b', 10, BookmarkedPoolCategory.series),
        PostViewerEntry(post: _posts[1], occurrenceId: 'c'),
        _groupEntry('d', 20, BookmarkedPoolCategory.collection),
        PostViewerEntry(post: _posts[0], occurrenceId: 'e'),
      ];
      final harness = _Harness(
        entries: entries,
        repository: const _GalleryRepository(),
      );
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      final pager = _pageViewController(tester);
      final controller = _detailsController(tester);
      final pagerState = tester.state(find.byType(PostDetailsPageView));
      for (var i = 1; i < entries.length; i++) {
        await tester.drag(find.byType(PageView).first, const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(pager.page, i);
        expect(_pageViewController(tester), same(pager));
        expect(
          tester.state(find.byType(PostDetailsPageView)),
          same(pagerState),
        );
        expect(_detailsController(tester), same(controller));
        if (entries[i] is GroupViewerEntry) {
          expect(
            find.text('gallery-${entries[i].occurrenceId}'),
            findsOneWidget,
          );
          expect(find.byType(PostDetailsFullInfoSheet), findsNothing);
          expect(
            InheritedPost.maybeOf(
              tester.element(find.text('gallery-${entries[i].occurrenceId}')),
            ),
            isNull,
          );
          final before = pager.page;
          await tester.drag(
            find.text('gallery-${entries[i].occurrenceId}'),
            const Offset(0, -250),
          );
          await tester.pumpAndSettle();
          expect(pager.page, before);
        } else {
          expect(
            controller.postAtPage(i),
            (entries[i] as PostViewerEntry).post,
          );
        }
      }
      await tester.drag(find.byType(PageView).first, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(pager.page, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a group-only sequence starts directly on a repeated Pool without a Post controller',
    (tester) async {
      _mobileViewport(tester);
      final harness = _Harness(
        posts: const [],
        initialIndex: 1,
        hideOverlay: true,
        reduceAnimations: false,
        entries: [
          _groupEntry('first', 10, BookmarkedPoolCategory.series),
          _groupEntry('second', 10, BookmarkedPoolCategory.series),
        ],
        repository: const _GalleryRepository(),
      );
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      expect(find.text('gallery-second'), findsOneWidget);
      expect(_pageViewController(tester).overlay.value, isTrue);
      // Gallery navigation remains available independently of Post overlay
      // state, including delayed media/route transitions and the O shortcut.
      _pageViewController(tester).hideOverlay();
      await tester.pumpAndSettle();
      expect(
        find.byType(KurumiCircularIconButton).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(PostDetailsItem<Post>), findsNothing);
      final context = tester.element(find.text('gallery-second'));
      expect(PostDetails.maybeOf<Post>(context), isNull);
      expect(InheritedPost.maybeOf(context), isNull);
      await tester.drag(find.byType(PageView).first, const Offset(700, 0));
      await tester.pumpAndSettle();
      expect(_pageViewController(tester).page, 0);
      expect(_pageViewController(tester).overlay.value, isTrue);
      expect(find.text('gallery-first'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
        _disposeAfterUnmount(tester, harness.dispose);
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
      _disposeAfterUnmount(tester, harness.dispose);
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
        reason: 'completion while a finger is held must cancel that navigation drag',
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
        posts: _posts.take(2).toList(),
        thumbnailQuality: ImageQuality.low,
        imageAdapter: adapter,
        imageCache: TestImageCache({'thumbnail-1': lowerPng}),
      );
      _disposeAfterUnmount(tester, harness.dispose);
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
      _disposeAfterUnmount(tester, harness.dispose);
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
        _zoomAction('Next Page'),
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

  testWidgets('missing post geometry follows decoded representation changes', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final adapter = ControlledImageAdapter();
    final post = _post(
      id: 1,
      booruType: BooruType.danbooru,
      host: 'https://danbooru.example',
      data: _posts.first.booruData,
      height: 0,
    );
    final harness = _Harness(
      posts: [post],
      imageAdapter: adapter,
      imageCache: TestImageCache({'thumbnail-1': lowerPng}),
    );
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.runAsync(
      () => pumpUntil(
        tester,
        () => adapter.pending.keys.any((url) => url.contains('/media/1')),
        reason: 'sample request',
      ),
    );
    adapter.complete(
      adapter.pending.keys.singleWhere((url) => url.contains('/media/1')),
      targetPng,
    );
    await tester.runAsync(() => waitForPixel(tester, [0, 0, 255, 255]));
    await tester.pump();
    Size? geometry() => tester
        .widget<InteractiveViewerExtended>(
          find.byType(InteractiveViewerExtended).first,
        )
        .contentSize;
    expect(geometry(), const Size(8, 8));

    _detailsController(tester).loadOriginalImage(post);
    await tester.runAsync(
      () => pumpUntil(
        tester,
        () => adapter.pending.keys.any((url) => url.endsWith('/original-1')),
        reason: 'original request',
      ),
    );
    adapter.complete(
      adapter.pending.keys.singleWhere((url) => url.endsWith('/original-1')),
      portraitPng,
    );
    await tester.runAsync(() => waitForPixel(tester, [0, 255, 0, 255]));
    await tester.pump();
    expect(geometry(), const Size(2, 8));
    await tester.pumpWidget(const SizedBox());
  });

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
    _disposeAfterUnmount(tester, harness.dispose);
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
      _disposeAfterUnmount(tester, harness.dispose);
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
        reason: 'the available preview must paint inside the actual AutoComic viewport',
      );
      screenshot.dispose();
      expect(_zoomAction('Next Page'), findsNothing);
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
        _disposeAfterUnmount(tester, harness.dispose);
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
  testWidgets('zoom is inert when Original is the default quality', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final adapter = ControlledImageAdapter();
    final harness = _Harness(
      posts: [_posts.first],
      loadOriginalOnZoom: true,
      postQuality: PostQuality.original,
      imageAdapter: adapter,
      imageCache: TestImageCache({
        'thumbnail-1': lowerPng,
        'sample-1': targetPng,
      }),
    );
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.runAsync(
      () => pumpUntil(
        tester,
        () => adapter.pending.keys.any((url) => url.endsWith('/original-1')),
        reason: 'default Original request',
      ),
    );
    final original = adapter.pending.keys.singleWhere(
      (url) => url.endsWith('/original-1'),
    );
    adapter.complete(original, originalPng);
    await tester.runAsync(() => waitForPixel(tester, [0, 255, 0, 255]));
    final details = _detailsController(tester);
    expect(details.originalImagePostKeys.value, isEmpty);
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
    await tester.pumpAndSettle();
    expect(_pageViewController(tester).zoom.value, isTrue);
    expect(details.originalImagePostKeys.value, isEmpty);
    expect(
      adapter.requests.where((r) => r.uri.toString() == original),
      hasLength(1),
    );
    expect(await paintedPixel(tester), [0, 255, 0, 255]);
    await tester.pumpWidget(const SizedBox());
  });

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
      _disposeAfterUnmount(tester, harness.dispose);
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
      expect(_zoomAction('Next Page'), findsNothing);
    });
  }

  testWidgets('failed image media cannot edge-navigate while zoomed', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final harness = _Harness(invalidImage: true);
    _disposeAfterUnmount(tester, harness.dispose);
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorPlaceholder), findsWidgets);

    await _swipeOutwardAtRightEdge(tester);
    expect(_pageViewController(tester).page, 0);
    expect(_zoomAction('Next Page'), findsNothing);
  });

  testWidgets('changes one post only after releasing an outward edge drag', (
    tester,
  ) async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _mobileViewport(tester, size: const Size(800, 1200));
    final harness = _Harness();
    _disposeAfterUnmount(tester, harness.dispose);
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
    expect(_comicButton('Next Page'), findsNothing);
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
      name: 'Next with a restored vertical preference in LTR',
      legacyVertical: true,
      direction: TextDirection.ltr,
      source: 0,
      target: 1,
      drag: -170.0,
    ),
    (
      name: 'Previous with a restored vertical preference in LTR',
      legacyVertical: true,
      direction: TextDirection.ltr,
      source: 1,
      target: 0,
      drag: 170.0,
    ),
    (
      name: 'Next in horizontal RTL mode',
      legacyVertical: false,
      direction: TextDirection.rtl,
      source: 0,
      target: 1,
      drag: 170.0,
    ),
    (
      name: 'Previous in horizontal RTL mode',
      legacyVertical: false,
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
          legacyVertical: scenario.legacyVertical,
          direction: scenario.direction,
          initialIndex: scenario.source,
          reduceAnimations: false,
        );
        _disposeAfterUnmount(tester, harness.dispose);
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
      _disposeAfterUnmount(tester, harness.dispose);
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
      _disposeAfterUnmount(tester, harness.dispose);
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
    final harness = _Harness(legacyVertical: true);
    _disposeAfterUnmount(tester, harness.dispose);
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
    final harness = _Harness(legacyVertical: true, reduceAnimations: false);
    _disposeAfterUnmount(tester, harness.dispose);
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
    final harness = _Harness(legacyVertical: true, reduceAnimations: false);
    _disposeAfterUnmount(tester, harness.dispose);
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
    _disposeAfterUnmount(tester, harness.dispose);
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
    _disposeAfterUnmount(tester, harness.dispose);
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

  for (final lateSecondPointer in [false, true]) {
    testWidgets('vertical pinch, pan, and return to fit retain ownership, '
        'late second pointer=$lateSecondPointer', (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: const Size(800, 1200));
      final harness = _Harness();
      _disposeAfterUnmount(tester, harness.dispose);
      await tester.pumpWidget(harness.build());
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      final pager = _pageViewController(tester);
      pager.hideAllUI();
      await tester.pumpAndSettle();
      final first = await tester.startGesture(
        const Offset(400, 450),
        pointer: 1,
      );
      if (lateSecondPointer) {
        await first.moveBy(const Offset(0, -40));
        await tester.pump();
      }
      final second = await tester.startGesture(
        const Offset(400, 650),
        pointer: 2,
      );
      await tester.pump();
      await first.moveBy(const Offset(0, -80));
      await second.moveBy(const Offset(0, 80));
      await tester.pump();
      await first.moveBy(const Offset(0, -40));
      await second.moveBy(const Offset(0, 40));
      await tester.pump();
      await first.moveBy(const Offset(0, -80));
      await second.moveBy(const Offset(0, 80));
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      final transform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      expect(kurumiIsZoomed(transform.value), isTrue);
      expect(pager.zoom.value, isTrue);
      expect(pager.isExpanded, isFalse);
      expect(pager.overlay.value, isFalse);
      final beforePan = transform.value.storage[13];
      final pan = await tester.startGesture(const Offset(400, 550));
      await pan.moveBy(const Offset(0, -40));
      await tester.pump();
      await pan.moveBy(const Offset(0, -80));
      await pan.up();
      await tester.pumpAndSettle();
      expect(transform.value.storage[13], lessThan(beforePan - 20));
      expect(pager.isExpanded, isFalse);
      final top = await tester.startGesture(const Offset(400, 350), pointer: 3);
      final bottom = await tester.startGesture(
        const Offset(400, 750),
        pointer: 4,
      );
      await tester.pump();
      await top.moveBy(const Offset(0, 150));
      await bottom.moveBy(const Offset(0, -150));
      await tester.pump();
      await top.up();
      await bottom.up();
      await tester.pumpAndSettle();
      expect(kurumiIsZoomed(transform.value), isFalse);
      expect(pager.zoom.value, isFalse);
      expect(pager.swipe.value, isTrue);
      expect(pager.overlay.value, isFalse);
      await tester.dragFrom(const Offset(650, 550), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(pager.page, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    });
  }

  testWidgets(
    'pinching retains image pan and enables bounded navigation',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester, size: const Size(800, 1200));
      final harness = _Harness();
      _disposeAfterUnmount(tester, harness.dispose);
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
      expect(_zoomAction('Previous Page'), findsNothing);
      expect(_zoomAction('Next Page'), findsOneWidget);
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
      _invokeZoomAction(tester, 'Next Page');
      await tester.pumpAndSettle();
      expect(pageView.page, 1);
    },
  );

  testWidgets(
    'uses horizontal paging and zoom controls with a restored vertical preference',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final harness = _Harness(legacyVertical: true);
      _disposeAfterUnmount(tester, harness.dispose);
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
      expect(_comicButton('Next Page'), findsNothing);

      transform.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();

      expect(pageView.zoom.value, isTrue);
      expect(pageView.overlay.value, isTrue);
      expect(_zoomAction('Next Page'), findsOneWidget);

      tester
          .widget<InteractiveViewerExtended>(
            find.byType(InteractiveViewerExtended).first,
          )
          .onTap
          ?.call();
      await tester.pump();
      expect(pageView.overlay.value, isFalse);
      expect(_zoomAction('Next Page'), findsOneWidget);

      tester
          .widget<InteractiveViewerExtended>(
            find.byType(InteractiveViewerExtended).first,
          )
          .onTap
          ?.call();
      await tester.pump();
      expect(pageView.overlay.value, isTrue);
      expect(_zoomAction('Next Page'), findsOneWidget);

      transform.value = Matrix4.identity();
      await tester.pumpAndSettle();
      expect(pageView.zoom.value, isFalse);
      await tester.drag(_postPageView(tester), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(pageView.page, 1);
    },
  );

  testWidgets(
    'keeps initially hidden toolbar hidden through zoom with a restored vertical preference',
    (
      tester,
    ) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final harness = _Harness(legacyVertical: true, hideOverlay: true);
      _disposeAfterUnmount(tester, harness.dispose);
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
      expect(_zoomAction('Next Page'), findsOneWidget);

      tester
          .widget<InteractiveViewerExtended>(
            find.byType(InteractiveViewerExtended).first,
          )
          .onTap
          ?.call();
      await tester.pump();
      expect(pageView.overlay.value, isTrue);
      expect(_zoomAction('Next Page'), findsOneWidget);
    },
  );

  testWidgets(
    'grid details keep the same mixed viewer while Next waits for and opens appended posts',
    (tester) async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      _mobileViewport(tester);
      final pending = Completer<PostResult<Post>>();
      final live = _LiveRouteHarness(loadNext: (_) => pending.future);
      _disposeAfterUnmount(tester, live.dispose);
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
      expect(_comicButton('Next Page'), findsNothing);
      details.loadOriginalImage(_liveInitial[1]);
      await _waitForCurrentImage(tester);
      _zoomCurrentPost(tester);
      await tester.pump();

      expect(live.requestedPages, [2]);
      expect(_zoomAction('Next Page'), findsNothing);
      await tester.pump();
      expect(details.currentPost.value.id, 22);

      pending.complete(PostResult(posts: [_liveNext], total: 3));
      await tester.pumpAndSettle();
      expect(pageView.totalPage, 3);
      expect(_zoomAction('Next Page'), findsOneWidget);
      transform.value = Matrix4.diagonal3Values(2, 2, 1);
      _invokeZoomAction(tester, 'Next Page');
      await tester.pumpAndSettle();

      expect(details.currentPost.value.id, 33);
      expect(_detailsController(tester), same(details));
      expect(_pageViewController(tester), same(pageView));
      expect(transform.value.getMaxScaleOnAxis(), 2);
      final nextTransform = tester
          .widget<PostViewerTransformationScope>(
            find.byType(PostViewerTransformationScope),
          )
          .controller
          .transformationController;
      expect(nextTransform, isNot(same(transform)));
      expect(nextTransform.value, Matrix4.identity());
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
    _disposeAfterUnmount(tester, live.dispose);
    await live.grid.refresh();
    await tester.pumpWidget(live.build());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _waitForCurrentImage(tester);
    final details = _detailsController(tester);
    final pageView = _pageViewController(tester);
    _zoomCurrentPost(tester);
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
    expect(_zoomAction('Next Page'), findsOneWidget);
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
      _disposeAfterUnmount(tester, live.dispose);
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
      expect(_zoomAction('Next Page'), findsNothing);

      final held = await tester.startGesture(const Offset(200, 400));
      await held.moveBy(const Offset(-170, 0));
      pending.complete(PostResult(posts: [_liveNext], total: 3));
      await tester.pumpAndSettle();
      expect(_zoomAction('Next Page'), findsOneWidget);
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
      _disposeAfterUnmount(tester, live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      _zoomCurrentPost(tester);
      await tester.pump();

      expect(live.requestedPages, [2]);
      expect(_comicButton('Next Page'), findsNothing);
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
      _disposeAfterUnmount(tester, live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);

      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      _zoomCurrentPost(tester);
      await tester.pumpAndSettle();

      expect(live.requestedPages, [2, 3, 4]);
      expect(pageView.totalPage, 3);
      expect(details.currentPost.value.id, 22);
      _invokeZoomAction(tester, 'Next Page');
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
      _disposeAfterUnmount(tester, live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      final details = _detailsController(tester);
      final pageView = _pageViewController(tester);
      _zoomCurrentPost(tester);
      await tester.pumpAndSettle();

      expect(live.requestedPages, [2, 3, 4]);
      expect(_zoomAction('Load More'), findsOneWidget);
      expect(_comicButton('Next Page'), findsNothing);
      expect(pageView.totalPage, 2);
      await tester.pump(const Duration(seconds: 2));
      expect(live.requestedPages, [2, 3, 4]);

      await _swipeOutwardAtRightEdge(
        tester,
        settle: false,
        indicatorIcon: Icons.expand_more,
        indicatorLabel: 'Load More',
      );
      await tester.pump(const Duration(milliseconds: 40));
      expect(_edgeContentIsFaded(tester), isFalse);
      expect(pageView.page, 1);
      await tester.pumpAndSettle();
      expect(live.requestedPages, [2, 3, 4, 5]);
      expect(_zoomAction('Next Page'), findsOneWidget);
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
      _disposeAfterUnmount(tester, live.dispose);
      await live.grid.refresh();
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await _waitForCurrentImage(tester);
      final details = _detailsController(tester);
      _zoomCurrentPost(tester);
      await tester.pump();

      expect(live.requestedPages, [2, 3]);
      expect(_zoomAction('Retry'), findsOneWidget);
      _invokeZoomAction(tester, 'Retry');
      await tester.pumpAndSettle();
      expect(live.requestedPages, [2, 3, 3]);
      expect(_zoomAction('Next Page'), findsOneWidget);
      expect(details.currentPost.value.id, 22);
    },
  );

  testWidgets('an empty page followed by the final page hides Next', (
    tester,
  ) async {
    _mobileViewport(tester);
    final live = _LiveRouteHarness(
      loadNext: (attempt) async => attempt == 1
          ? PostResult(posts: [_liveInitial[1]], total: null, hasMore: true)
          : PostResult<Post>.empty(),
    );
    _disposeAfterUnmount(tester, live.dispose);
    await live.grid.refresh();
    await tester.pumpWidget(live.build());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final details = _detailsController(tester);
    _zoomCurrentPost(tester);
    await tester.pump();

    expect(live.requestedPages, [2, 3]);
    expect(_comicButton('Next Page'), findsNothing);
    expect(_comicButton('Load More'), findsNothing);
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
      _disposeAfterUnmount(tester, live.dispose);
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
      _disposeAfterUnmount(tester, live.dispose);
      await live.grid.refresh();
      unawaited(live.grid.fetchMore());
      await tester.pumpWidget(live.build());
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(live.requestedPages, [2]);

      pending.complete(PostResult(posts: [_liveInitial[1]], total: 3));
      // A duplicate-only page schedules a cooldown without requesting frames.
      // Advance the controlled clock until the next request, since settling
      // frames alone can finish before that timer fires.
      for (
        var frame = 0;
        live.requestedPages.length < 2 && frame < 100;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
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
    _disposeAfterUnmount(tester, harness.dispose);
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
    _disposeAfterUnmount(tester, harness.dispose);
    final request = (_configs.first.auth, 'artist');

    harness.container.read(chipColorsFromTagStringProvider(request));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          home: CurrentBooruConfigScope(
            config: _configs.first,
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
      _disposeAfterUnmount(tester, harness.dispose);

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
      // Details is the shared presentation mode across ordinary Post pages.
      expect(pageView.sheetState.value, SheetState.expanded);
      expect(pageView.sheetController.isAttached, isFalse);
      expect(pageView.displacement.value, 0);
      expect(pageView.zoom.value, isFalse);

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
      // Unsupported sources retain Details with their own generic metadata.
      expect(find.text('Tags'), findsOneWidget);
      expect(find.textContaining('unknown@'), findsNothing);
      _expectMedia(tester, postId: 1, host: '');

      expect(details.currentPage.value, 3);
      expect(details.currentPost.value, _posts[3]);
      expect(pageView.currentPage.value, 3);
      expect(harness.container.read(currentBooruConfigProvider), globalBefore);
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
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

  testWidgets(
    'launching profile restores native presentation when origin is unspecified',
    (tester) async {
      BooruType? requestedType;
      final post = _posts.first.copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.unknown,
          booruId: 0,
          source: '',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booruConfigProvider.overrideWith(
              () => BooruConfigNotifier(initialConfigs: [_configs.first]),
            ),
            booruPostPresentationProvider.overrideWith((ref, request) {
              requestedType = request.origin.booruType;
              return const _Presentation('danbooru');
            }),
          ],
          child: MaterialApp(
            home: PostPagePresentationScope(
              post: post,
              fallbackConfig: _configs.first,
              builder: (context, ref, presentation) => Text(
                '${presentation.fallbackReason}|${ref.watchConfig.url}|'
                '${presentation.context.presentation.runtimeType}',
              ),
            ),
          ),
        ),
      );

      expect(requestedType, BooruType.danbooru);
      expect(
        find.text(
          'null|https://danbooru.example|_Presentation',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _disposeAfterUnmount(WidgetTester tester, VoidCallback dispose) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    dispose();
    await tester.pump();
  });
}

void _zoomCurrentPost(WidgetTester tester) {
  final transform = tester
      .widget<PostViewerTransformationScope>(
        find.byType(PostViewerTransformationScope),
      )
      .controller
      .transformationController;
  transform.value = Matrix4.diagonal3Values(2, 2, 1);
}

int _diagnosticCount(State state, String name) {
  final properties = DiagnosticPropertiesBuilder();
  state.debugFillProperties(properties);
  return properties.properties
          .singleWhere((property) => property.name == name)
          .value!
      as int;
}

Map<String, int> _viewerDiagnostics(WidgetTester tester) {
  final state = tester.state(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MixedPostDetailsView',
    ),
  );
  return {
    for (final name in [
      'mediaCheckpoints',
      'selectedMediaControllers',
      'mediaControllers',
      'mountedMediaControllers',
    ])
      name: _diagnosticCount(state, name),
  };
}

bool _controllerAlive(PostDetailsController<Post> controller) {
  try {
    return ChangeNotifier.debugAssertNotDisposed(controller);
    // Disposal is a debug assertion; catching it lets this test count live actors.
    // ignore: avoid_catching_errors
  } on FlutterError {
    return false;
  }
}

PostDetailsController<Post> _detailsController(WidgetTester tester) {
  final details = tester.widget<PostDetails>(find.byType(PostDetails));
  return (details.data! as PostDetailsData<Post>).controller;
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
    bool legacyVertical = false,
    this.direction = TextDirection.ltr,
    this.initialIndex = 0,
    this.posts,
    this.entries,
    this.entrySource,
    BooruRepository? repository,
    BooruGroupCapability? mediaCapability,
    BooruPostPresentation? postPresentation,
    StateProvider<MediaGroupState>? mediaState,
    bool reduceAnimations = true,
    bool hideOverlay = false,
    bool loadMedia = true,
    bool emptyFirstImage = false,
    bool invalidImage = false,
    bool loadOriginalOnZoom = false,
    bool darkTheme = false,
    PostQuality postQuality = PostQuality.high,
    HttpClientAdapter? imageAdapter,
    ImageCacheManager? imageCache,
    this.initialThumbnailUrl,
    ImageQuality thumbnailQuality = ImageQuality.automatic,
  }) : container = ProviderContainer(
         overrides: [
           if (mediaState != null)
             mediaGroupProvider.overrideWith(
               (ref, entry) => ref.watch(mediaState),
             ),
           miscDataStoreProvider.overrideWithValue(MemoryMiscDataStore()),
           if (router != null) routerProvider.overrideWithValue(router),
           settingsProvider.overrideWithValue(
             Settings.defaultSettings.copyWith(
               reduceAnimations: reduceAnimations,
               listing: Settings.defaultSettings.listing.copyWith(
                 imageQuality: thumbnailQuality,
               ),
               viewer: ImageViewerSettings.fromJson({
                 ...Settings.defaultSettings.viewer
                     .copyWith(
                       loadOriginalOnZoom: loadOriginalOnZoom,
                       postQuality: postQuality,
                       postDetailsOverlayInitialState: hideOverlay
                           ? PostDetailsOverlayInitialState.hide
                           : PostDetailsOverlayInitialState.show,
                     )
                     .toJson(),
                 if (legacyVertical) 'swipeMode': 1,
               }),
             ),
           ),
           colorSchemeProvider.overrideWithValue(
             ColorScheme.fromSeed(
               seedColor: Colors.blue,
               brightness: darkTheme ? Brightness.dark : Brightness.light,
             ),
           ),
           initialSettingsBooruConfigProvider.overrideWithValue(_globalConfig),
           booruConfigProvider.overrideWith(
             () => BooruConfigNotifier(initialConfigs: _configs),
           ),
           globalBlacklistedTagsProvider.overrideWith(_EmptyBlacklist.new),
           contentEffectivePolicyProvider.overrideWith(
             (ref, profileId) => const AsyncData('test-empty-policy'),
           ),
           booruEngineRegistryProvider.overrideWith(_createEngineRegistry),
           booruGroupCapabilityProvider.overrideWith((ref, type) {
             if (mediaCapability != null && type == mediaCapability.engine) {
               return mediaCapability;
             }
             if (repository is _GalleryRepository &&
                 type == BooruType.danbooru) {
               return _galleryGroupCapability();
             }
             return ref
                 .watch(booruEngineRegistryProvider)
                 .getGroupCapability(type);
           }),
           booruPostPresentationProvider.overrideWith((ref, request) {
             return postPresentation ??
                 switch (request.data) {
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
               postQuality: postQuality,
             ),
           ),
           booruRepoProvider.overrideWith((ref, config) => repository),
           booruBuilderProvider.overrideWith((ref, config) => null),
           automaticMediaLoadingEnabledProvider.overrideWithValue(loadMedia),
           zoomStudyEnabledProvider.overrideWithValue(false),
           dioForWidgetProvider.overrideWith(
             (ref, config) =>
                 Dio(BaseOptions(baseUrl: 'https://images.example/'))
                   ..httpClientAdapter =
                       imageAdapter ?? _TestImageAdapter(invalidImage),
           ),
           mediaOverrideDioProvider.overrideWith(
             (ref, config) => Dio()
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
           appPlatformProvider.overrideWithValue(AppPlatform.android),
           externalUrlLauncherProvider.overrideWithValue(
             RecordingExternalUrlLauncher(),
           ),
           favoriteRepoProvider.overrideWith(
             (ref, config) => EmptyFavoriteRepository(),
           ),
         ],
       );

  final ProviderContainer container;
  final TextDirection direction;
  final int initialIndex;
  final List<Post>? posts;
  final List<ViewerEntry>? entries;
  final ViewerEntryLiveSource? entrySource;
  final String? initialThumbnailUrl;

  Widget build({ThemeData? theme, double? textScale, EdgeInsets? padding}) =>
      UncontrolledProviderScope(
        container: container,
        child: BooruLocalization(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) =>
                // ignore: deprecated_member_use
                MaterialUiCompatibilityBridge(
                  child: KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: textScale == null && padding == null
                        ? child!
                        : MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              textScaler: textScale == null
                                  ? null
                                  : TextScaler.linear(textScale),
                              padding: padding,
                              viewPadding: padding,
                            ),
                            child: child!,
                          ),
                  ),
                ),
            home: Directionality(
              textDirection: direction,
              child: MixedPostDetailsPage(
                posts: posts ?? _posts,
                entries: entries,
                entrySource: entrySource,
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
        builder: (context, child) =>
            // ignore: deprecated_member_use
            MaterialUiCompatibilityBridge(
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
      ),
    ),
  );

  var _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
  }
}

class _EmptyBlacklist extends GlobalBlacklistedTagsNotifier {
  @override
  IList<BlacklistedTag> build() => <BlacklistedTag>[].lock;
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
          ? TaskEither.right(
              PostResult(posts: _liveInitial, total: null, hasMore: true),
            )
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
      legacyVertical: true,
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

  var _disposed = false;
  void dispose() {
    if (_disposed) return;
    _disposed = true;
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
        groupCapability: components.createGroupCapability?.call(ref),
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

final _globalConfig = BooruConfig.defaultConfig(
  booruType: BooruType.gelbooru,
  url: 'https://global.example',
  customDownloadFileNameFormat: null,
);

final _configs =
    [
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
        ].indexed
        .map(
          (entry) => BooruConfig.fromJson({
            ...entry.$2.toJson(),
            'id': '00000000-0000-4000-8000-00000000000${entry.$1 + 1}',
          }),
        )
        .toList();

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
  double width = 100,
  Set<String>? artistTags,
  Set<String> tags = const {},
  Set<String>? characterTags,
  Set<String>? copyrightTags,
  String format = 'jpg',
  String videoUrl = '',
  double duration = 0,
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
    videoUrl: videoUrl,
    videoThumbnailUrl: '',
    width: width,
    height: height,
    artistTags: artistTags,
    characterTags: characterTags,
    copyrightTags: copyrightTags,
    format: format,
    md5: 'md5-$id',
    fileSize: 1,
    duration: duration,
    tags: tags,
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
  const _Presentation(this.name, {this.detailsHeight, this.commentary = false});

  final double? detailsHeight;
  final bool commentary;

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
      if (commentary)
        DetailsPart.artistInfo: (context) => SliverToBoxAdapter(
          child: ArtistSection(
            commentary: ArtistCommentary(
              originalTitle: 'Post ${post.id}',
              originalDescription: 'Swipe this commentary',
              translatedTitle: '',
              translatedDescription: '',
            ),
            artistTags: const {},
            source: post.source,
          ),
        ),
      if (detailsHeight case final height?)
        DetailsPart.tags: (context) =>
            SliverToBoxAdapter(child: SizedBox(height: height)),
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
  const _MediaResolver(
    this.host, {
    this.emptyFirstImage = false,
    this.postQuality = PostQuality.high,
  });
  final PostQuality postQuality;

  final String host;
  final bool emptyFirstImage;

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      emptyFirstImage && post.id == 1
      ? ''
      : postQuality == PostQuality.original
      ? post.originalImageUrl
      : '$host/media/${post.id}';

  @override
  double? resolveMediaAspectRatio(Post post, BooruConfigViewer config) =>
      post.aspectRatio;

  @override
  String resolveVideoUrl(Post post, BooruConfigViewer config) =>
      '$host/video/${post.id}';

  @override
  double? resolveVideoAspectRatio(Post post, BooruConfigViewer config) => 1;
}

final class _TestImageAdapter implements HttpClientAdapter {
  _TestImageAdapter(this.invalidImage, {this.bytes});

  final bool invalidImage;
  final Uint8List? bytes;
  static final _png = File('assets/images/logo.png').readAsBytesSync();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    invalidImage ? Uint8List.fromList([1, 2, 3]) : bytes ?? _png,
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

GroupViewerEntry _groupEntry(
  String occurrence,
  int id,
  BookmarkedPoolCategory category,
) => GroupViewerEntry(
  summary: ContentGroupSummary(
    reference: const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse(_configs.first.url),
      kind: ContentKind.group,
      sourceKey: 'pool:$id',
    ),
    title: 'Pool $id',
    memberCount: 2,
    displayCategory: switch (category) {
      BookmarkedPoolCategory.series => 'series',
      BookmarkedPoolCategory.collection => 'collection',
      BookmarkedPoolCategory.unknown => null,
    },
  ),
  occurrenceId: occurrence,
  source: ViewerSourceBinding(_configs.first),
);

class _GalleryRepository extends BooruRepositoryDefault {
  const _GalleryRepository();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BooruGroupCapability _galleryGroupCapability() => BooruGroupCapability(
  engine: BooruType.danbooru,
  keyCodec: const BooruContentKeyCodec(BooruType.danbooru),
  createSource: (_, access) => _GalleryGroupSource(access),
  presentation: const _GalleryGroupPresentation(),
);

class _GalleryGroupSource extends ContentGroupSource {
  _GalleryGroupSource(this.access);

  @override
  final ContentAccessContext access;

  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => TaskEither.right(ContentGroupSummary(reference: reference));

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => TaskEither.right(
    ContentGroupDetails(summary: ContentGroupSummary(reference: reference)),
  );

  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => TaskEither.right((
    page: ContentPage<GroupMember>(items: const [], total: 0),
    resolved: const <ContentEntry>[],
  ));
}

class _GalleryGroupPresentation implements BooruGroupPresentation {
  const _GalleryGroupPresentation();

  @override
  bool supports(ContentGroupSummary summary) => true;

  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.memberGrid;

  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      'members';

  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      const SizedBox.shrink();

  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) {
    final entry = GroupViewerScope.maybeEntryOf(context)!;
    return CustomScrollView(
      slivers: [
        const ViewerEntryNavigationHeader(),
        SliverToBoxAdapter(child: Text('gallery-${entry.occurrenceId}')),
        SliverList.list(
          children: [
            for (var i = 0; i < 60; i++)
              SizedBox(height: 50, child: Text('member-$i')),
          ],
        ),
      ],
    );
  }
}

final class _PlaybackProbe implements BooruPlayer {
  var playing = false;
  var plays = 0;
  @override
  bool get isPlaying => playing;
  @override
  Future<void> play() async {
    playing = true;
    plays++;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _captureViewerModes(WidgetTester tester) async {
  final previousHitWarning = WidgetController.hitTestWarningShouldBeFatal;
  WidgetController.hitTestWarningShouldBeFatal = true;
  addTearDown(
    () => WidgetController.hitTestWarningShouldBeFatal = previousHitWarning,
  );
  await _loadViewerCaptureFonts(tester);
  final html = File('docs/designs/mockups/2026-11-10-unified-viewer.html')
      .readAsStringSync();
  final art = base64Decode(
    RegExp('data:image/[^;]+;base64,([A-Za-z0-9+/=]+)')
        .firstMatch(html)!
        .group(1)!,
  );
  final cases = [
    (
      name: 'square-414',
      viewport: const Size(414, 915),
      media: const Size(930, 926),
      scale: 1.0,
      bytes: art,
    ),
    (
      name: 'portrait-320',
      viewport: const Size(320, 800),
      media: const Size(2, 8),
      scale: 2.0,
      bytes: portraitPng,
    ),
    (
      name: 'panorama-landscape',
      viewport: const Size(844, 390),
      media: const Size(1200, 160),
      scale: 1.0,
      bytes:
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            canvas.drawRect(
              const Rect.fromLTWH(0, 0, 1200, 160),
              ui.Paint()..color = const Color(0xff49667d),
            );
            canvas.drawRect(
              const Rect.fromLTWH(0, 0, 400, 160),
              ui.Paint()..color = const Color(0xffceae8b),
            );
            canvas.drawRect(
              const Rect.fromLTWH(800, 0, 400, 160),
              ui.Paint()..color = const Color(0xff7b8e69),
            );
            final picture = recorder.endRecording();
            final image = await picture.toImage(1200, 160);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            picture.dispose();
            return data!.buffer.asUint8List();
          }) ??
          Uint8List(0),
    ),
  ];
  final directory = Directory(_viewerCaptureDirectory)
    ..createSync(recursive: true);
  for (final item in cases) {
    tester.view.physicalSize = item.viewport;
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    final post = _post(
      id: 1,
      booruType: BooruType.danbooru,
      host: 'https://danbooru.example',
      data: DanbooruPostData(
        lastCommentAt: null,
        upScore: 1,
        downScore: 0,
        favCount: 2,
        approverId: null,
        generalTags: {for (var i = 1; i <= 32; i++) 'reference_tag_$i'},
        metaTags: const {},
        hasChildren: false,
        hasLarge: true,
        pixelHash: '',
      ),
      tags: {for (var i = 1; i <= 32; i++) 'reference_tag_$i'},
      artistTags: {'punziebunnie'},
      width: item.media.width,
      height: item.media.height,
      characterTags: {'aerith_gainsborough', 'princess_peach'},
      copyrightTags: {'final_fantasy', 'super_mario'},
    );
    final harness = _Harness(
      posts: [post],
      darkTheme: true,
      hideOverlay: true,
      reduceAnimations: false,
      imageAdapter: _TestImageAdapter(false, bytes: item.bytes),
      imageCache: TestImageCache({}),
    );
    final boundaryKey = GlobalKey();
    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: harness.build(
            theme: ThemeData(
              fontFamily: 'Roboto',
              colorScheme: harness.container.read(colorSchemeProvider),
            ),
            textScale: item.scale,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => tester
              .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
              .any(
                (media) =>
                    media.imageController?.imageInfo.value?.image.width ==
                    item.media.width,
              ),
          reason: 'capture media decoded',
        ),
      );
      await tester.pumpAndSettle();
      final pager = _pageViewController(tester);
      Future<void> capture(String mode) async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File(
            '${directory.path}/flutter-${item.name}-$mode.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }

      expect(find.byType(KurumiInfoCircleIcon).hitTestable(), findsNothing);
      await capture('immersive');
      pager.showAllUI();
      await tester.pumpAndSettle();
      await capture('overlay');
      if (item.name == 'square-414') {
        final gesture = await tester.startGesture(const Offset(200, 560));
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();
        await capture('drag-early');
        await gesture.moveBy(const Offset(0, -160));
        await tester.pump();
        await capture('drag-late');
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        await capture('snap-mid');
        await tester.pumpAndSettle();
      }
      await pager.expandToSnapPoint();
      await tester.pumpAndSettle();
      await capture('details-top');
      final mediaHeight = tester
          .getSize(find.byKey(const ValueKey(('viewer-media', 0))))
          .height;
      await tester.scrollUntilVisible(
        find.text('File Details').hitTestable(),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey(('viewer-details-scroll', 0))),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('File Details'));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey(('viewer-details-scroll', 0))),
          )
          .controller!;
      expect(
        scroll.position.maxScrollExtent,
        greaterThan(mediaHeight),
      );
      scroll.jumpTo(scroll.position.maxScrollExtent.clamp(0, 650));
      await tester.pumpAndSettle();
      await capture('details-scrolled');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    }
  }
  tester.view.reset();
}

Future<void> _loadViewerCaptureFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final configFile = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(await configFile.readAsString())
                as Map<String, dynamic>)['packages']
            as List;
    final flutter = packages.cast<Map<String, dynamic>>().singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final sdk = configFile.absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../');
    for (final font in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(
            File.fromUri(
              sdk.resolve('bin/cache/artifacts/material_fonts/${font.$2}'),
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader('packages/material_symbols_icons/MaterialSymbolsOutlined')
          ..addFont(
            rootBundle.load(
              'packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
            ),
          ))
        .load();
  });
}

Future<void> _capturePixivWorkModes(WidgetTester tester) async {
  await _loadViewerCaptureFonts(tester);
  final art = base64Decode(
    RegExp('data:image/[^;]+;base64,([A-Za-z0-9+/=]+)')
        .firstMatch(
          File('docs/designs/mockups/2026-11-10-unified-viewer.html')
              .readAsStringSync(),
        )!
        .group(1)!,
  );
  final directory = Directory(_viewerCaptureDirectory)
    ..createSync(recursive: true);
  final access = ContentAccessContext.profile(
    config: _configs[2],
    authEpoch: 1,
    policyEpoch: 1,
  );
  for (final (name, viewport, scale) in [
    ('pixiv-414', const Size(414, 915), 1.0),
    ('pixiv-320', const Size(320, 800), 2.0),
    ('pixiv-landscape', const Size(844, 390), 1.0),
  ]) {
    _mobileViewport(tester, size: viewport);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetViewPadding);
    final harness = _Harness(
      posts: const [],
      entries: [
        GroupViewerEntry(
          summary: pixivWorkSummary(works.work(), access),
          occurrenceId: 'capture',
          source: ViewerSourceBinding(_configs[2]),
        ),
      ],
      hideOverlay: true,
      darkTheme: true,
      reduceAnimations: false,
      imageAdapter: _TestImageAdapter(false, bytes: art),
      imageCache: TestImageCache({}),
      mediaCapability: BooruGroupCapability(
        engine: BooruType.pixiv,
        keyCodec: const BooruContentKeyCodec(BooruType.pixiv),
        presentation: const PixivWorkPresentation(),
        createSource: (_, actor) => PixivWorkSource(
          access: actor,
          fetchWork: (_) async => works.work(),
        ),
      ),
    );
    final key = GlobalKey();
    try {
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: harness.build(
            theme: ThemeData(
              fontFamily: 'Roboto',
              colorScheme: harness.container.read(colorSchemeProvider),
            ),
            textScale: scale,
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
        ),
      );
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => tester
              .widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>))
              .any(
                (media) =>
                    media.imageController?.loadState.value ==
                    LoadState.completed,
              ),
          reason: 'decoded Work Page',
        ),
      );
      await tester.pumpAndSettle();
      final pager = _pageViewController(tester);
      Future<void> capture(String mode) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File('${directory.path}/flutter-$name-$mode.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      }

      await capture('immersive');
      pager.showAllUI();
      await tester.pumpAndSettle();
      expect(
        find.byType(DefaultInheritedPostActionToolbar<Post>),
        findsWidgets,
      );
      await capture('overlay');
      await pager.expandToSnapPoint();
      await tester.pumpAndSettle();
      expect(
        find.byType(DefaultInheritedPostActionToolbar<Post>),
        findsWidgets,
      );
      await capture('details');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
      await tester.pump();
    }
  }
}

final class _PageImageAdapter extends _TestImageAdapter {
  _PageImageAdapter() : super(false);
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requests.add(url);
    return ResponseBody.fromBytes(
      url.endsWith('/media/120000') ? portraitPng : targetPng,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }
}
