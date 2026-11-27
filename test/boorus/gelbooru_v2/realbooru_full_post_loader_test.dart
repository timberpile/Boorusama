import 'package:flutter/services.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/foundation/info/device_info.dart';

import '../../core/posts/details/progressive_image_test_utils.dart';

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booru_clients/generated.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Project imports:
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_builder.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2.dart';
import 'package:boorusama/boorus/gelbooru_v2/gelbooru_v2_provider.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/post_data.dart';
import 'package:boorusama/boorus/gelbooru_v2/posts/providers.dart';
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
import 'package:boorusama/core/content/content_media_dio.dart';
import 'package:boorusama/core/navigation/destination_activity.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/widgets.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/videos/engines/types.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/foundation/platform.dart';

import '../../support/fakes/memory_app_file_system.dart';

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'opening a Realbooru listing post replaces its thumbnail data with the fetched original',
    (tester) async {
      final fetched = Completer<Post?>();
      var fetches = 0;
      final unresolved = _post(
        originalUrl: _thumbnailUrl,
        metadata: const PostMetadata(page: 1, search: 'portrait', limit: 42),
      );
      final resolved = _post(originalUrl: _originalUrl, thumbnailUrl: '');

      await tester.pumpWidget(
        _Harness(
          post: unresolved,
          onFetch: () {
            fetches++;
            return fetched.future;
          },
        ),
      );
      await tester.pump();

      expect(_visiblePost(tester).originalImageUrl, _thumbnailUrl);
      expect(fetches, 1);

      fetched.complete(resolved);
      await tester.pumpAndSettle();

      expect(_visiblePost(tester).originalImageUrl, _originalUrl);
      expect(_visiblePost(tester).thumbnailImageUrl, _thumbnailUrl);
      expect(fetches, 1);
    },
  );

  for (final swipeToVideo in [false, true]) {
    testWidgets(
      'first visit starts the resolved Realbooru video (swipe=$swipeToVideo)',
      (
        tester,
      ) async {
        final fetched = Completer<Post?>();
        var fetches = 0;
        await tester.pumpWidget(
          _Harness(
            post: swipeToVideo
                ? _post(id: 41, originalUrl: _originalUrl)
                : _videoPoster(),
            adjacentPost: swipeToVideo ? _videoPoster() : null,
            onFetch: () {
              fetches++;
              return fetched.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        if (swipeToVideo) {
          expect(fetches, 0);
          await _swipeToNextPost(tester);
        }

        final page = swipeToVideo ? 1 : 0;
        final controller = _settledItem(tester).detailsController;
        expect(controller.currentSettledPage.value, page);
        expect(controller.postAtPage(page)!.isVideo, isFalse);
        expect(fetches, 1);

        fetched.complete(_video());
        await tester.pumpAndSettle();
        final resolved = _settledItem(tester).post!;
        expect(resolved.isVideo, isTrue);
        expect(controller.currentSettledPage.value, page);
        final player = _PlaybackProbe();
        controller.onBooruVideoPlayerCreated(player, resolved);
        expect(player.plays, 1);

        await controller.pauseCurrentVideo();
        controller.replacePost(page, _video(thumbnailUrl: _sampleUrl));
        await tester.pumpAndSettle();
        expect(player.plays, 1);
        expect(player.isPlaying, isFalse);
      },
    );
  }

  for (final resolveBeforeSwipe in [false, true]) {
    testWidgets(
      'leaving clears first-visit autoplay (resolved=$resolveBeforeSwipe)',
      (
        tester,
      ) async {
        final fetched = Completer<Post?>();
        await tester.pumpWidget(
          _Harness(
            post: _videoPoster(),
            adjacentPost: _post(id: 43, originalUrl: _originalUrl),
            onFetch: () => fetched.future,
          ),
        );
        await tester.pumpAndSettle();
        final controller = _settledItem(tester).detailsController;
        final resolved = _video();
        if (resolveBeforeSwipe) {
          fetched.complete(resolved);
          await tester.pumpAndSettle();
          expect(controller.isVideoPlaying.value, isTrue);
        }

        await _swipeToNextPost(tester);
        expect(controller.currentSettledPage.value, 1);
        if (!resolveBeforeSwipe) {
          fetched.complete(resolved);
          await tester.pumpAndSettle();
        }
        final player = _PlaybackProbe();
        controller.onBooruVideoPlayerCreated(player, controller.postAtPage(0)!);
        expect(player.plays, 0);
        expect(controller.isVideoPlaying.value, isFalse);
      },
    );
  }

  testWidgets('a video resolved while covered starts when its viewer returns', (
    tester,
  ) async {
    final fetched = Completer<Post?>();
    final active = ValueNotifier(true);
    await tester.pumpWidget(
      _Harness(
        post: _videoPoster(),
        navigationActive: active,
        onFetch: () => fetched.future,
      ),
    );
    await tester.pumpAndSettle();
    final controller = _settledItem(tester).detailsController;
    active.value = false;
    await tester.pump();
    fetched.complete(_video());
    await tester.pumpAndSettle();

    final player = _PlaybackProbe();
    controller.onBooruVideoPlayerCreated(player, _settledItem(tester).post!);
    expect(player.plays, 0);
    active.value = true;
    await tester.pumpAndSettle();
    expect(player.plays, 1);

    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });

  for (final sameUrl in [false, true]) {
    testWidgets(
      'Realbooru manual Original action uses resolved media (same=$sameUrl)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final adapter = ControlledImageAdapter();
        final cache = TestImageCache({
          _thumbnailUrl: lowerPng,
          _sampleUrl: targetPng,
        });
        final resolved = _post(
          originalUrl: _originalUrl,
          sampleUrl: sameUrl ? _originalUrl : _sampleUrl,
        );
        var fetches = 0;
        await tester.pumpWidget(
          _Harness(
            post: _post(
              originalUrl: _thumbnailUrl,
              metadata: const PostMetadata(
                page: 1,
                search: 'portrait',
                limit: 42,
              ),
            ),
            onFetch: () async {
              fetches++;
              return resolved;
            },
            imageAdapter: adapter,
            imageCache: cache,
          ),
        );
        await tester.runAsync(() async {
          if (sameUrl) {
            await pumpUntil(
              tester,
              () => adapter.pending.containsKey(_originalUrl),
              reason: 'displayed Original',
            );
            adapter.complete(_originalUrl, originalPng);
            await waitForPixel(tester, [0, 255, 0, 255]);
          } else {
            await waitForPixel(tester, [0, 0, 255, 255]);
            expect(
              adapter.requests.where((r) => r.uri.toString() == _originalUrl),
              isEmpty,
            );
          }
        });
        await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_horiz).hitTestable().first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load Original').hitTestable());
        await tester.runAsync(() async {
          if (!sameUrl) {
            await pumpUntil(
              tester,
              () => adapter.pending.containsKey(_originalUrl),
              reason: 'manual Original request',
            );
            adapter.complete(_originalUrl, originalPng);
          }
          await waitForPixel(tester, [0, 255, 0, 255]);
        });
        expect(fetches, 1);
        expect(
          adapter.requests.where((r) => r.uri.toString() == _originalUrl),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('an already resolved Realbooru post is not fetched again', (
    tester,
  ) async {
    var fetches = 0;

    await tester.pumpWidget(
      _Harness(
        post: _post(originalUrl: _originalUrl),
        onFetch: () async {
          fetches++;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_visiblePost(tester).originalImageUrl, _originalUrl);
    expect(fetches, 0);
  });

  testWidgets('a failed Realbooru detail fetch keeps the listing thumbnail', (
    tester,
  ) async {
    var fetches = 0;

    await tester.pumpWidget(
      _Harness(
        post: _post(
          originalUrl: _thumbnailUrl,
          metadata: const PostMetadata(
            page: 1,
            search: 'portrait',
            limit: 42,
          ),
        ),
        onFetch: () {
          fetches++;
          return Future<Post?>.error(Exception('unreachable'));
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(_visiblePost(tester).originalImageUrl, _thumbnailUrl);
    expect(fetches, 1);
    expect(tester.takeException(), isNull);
  });
}

Post _visiblePost(WidgetTester tester) =>
    tester.widgetList<PostMedia<Post>>(find.byType(PostMedia<Post>)).first.post;

PostDetailsItem<Post> _settledItem(WidgetTester tester) {
  return tester
      .widgetList<PostDetailsItem<Post>>(find.byType(PostDetailsItem<Post>))
      .singleWhere(
        (item) => item.detailsController.currentSettledPage.value == item.index,
      );
}

Future<void> _swipeToNextPost(WidgetTester tester) async {
  await tester.dragFrom(const Offset(400, 230), const Offset(-550, 0));
  await tester.pumpAndSettle();
}

Post _videoPoster() => _post(
  originalUrl: _thumbnailUrl,
  isVideoPreview: true,
  metadata: const PostMetadata(page: 1, search: 'video', limit: 42),
);

Post _video({String thumbnailUrl = _thumbnailUrl}) => _post(
  originalUrl: 'https://realbooru.test/images/ab/cd/video.mp4',
  format: 'mp4',
  thumbnailUrl: thumbnailUrl,
);

final class _PlaybackProbe implements BooruPlayer {
  var plays = 0;
  @override
  var isPlaying = false;

  @override
  Future<void> play() async {
    plays++;
    isPlaying = true;
  }

  @override
  Future<void> pause() async => isPlaying = false;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _thumbnailUrl =
    'https://realbooru.test/thumbnails/ab/cd/'
    'thumbnail_0123456789abcdef0123456789abcdef.jpg';
const _sampleUrl = 'https://realbooru.test/samples/sample.png';
const _originalUrl =
    'https://realbooru.test/images/ab/cd/'
    '0123456789abcdef0123456789abcdef.jpeg';

final _config = BooruConfig.defaultConfig(
  booruType: BooruType.gelbooruV2,
  url: 'https://realbooru.com/',
  customDownloadFileNameFormat: null,
);

Post _post({
  required String originalUrl,
  int id = 42,
  String format = 'jpeg',
  bool isVideoPreview = false,
  String thumbnailUrl = _thumbnailUrl,
  String? sampleUrl,
  PostMetadata? metadata,
}) => Post(
  origin: PostOrigin.fromSource(
    booruType: BooruType.gelbooruV2,
    booruId: BooruType.gelbooruV2.id,
    source: _config.url,
  ),
  core: PostCoreData(
    id: id,
    thumbnailImageUrl: thumbnailUrl,
    sampleImageUrl: sampleUrl ?? originalUrl,
    originalImageUrl: originalUrl,
    videoUrl: format == 'mp4' ? originalUrl : '',
    videoThumbnailUrl: '',
    width: 0,
    height: 0,
    format: format,
    md5: '0123456789abcdef0123456789abcdef',
    fileSize: 0,
    duration: 0,
    tags: const {'portrait'},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    metadata: metadata,
  ),
  booruData: GelbooruV2PostData(
    hasNotes: false,
    isVideoPreview: isVideoPreview,
  ),
);

class _Harness extends StatelessWidget {
  const _Harness({
    required this.post,
    required this.onFetch,
    this.adjacentPost,
    this.navigationActive,
    this.imageAdapter,
    this.imageCache,
  });
  final HttpClientAdapter? imageAdapter;
  final ImageCacheManager? imageCache;

  final Post post;
  final Post? adjacentPost;
  final ValueNotifier<bool>? navigationActive;
  final Future<Post?> Function() onFetch;

  Widget get _viewer => MixedPostDetailsPage(
    posts: [post, ?adjacentPost],
    initialIndex: 0,
    initialThumbnailUrl: _thumbnailUrl,
    scrollController: null,
    disclaimer: null,
  );

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      settingsProvider.overrideWithValue(
        Settings.defaultSettings.copyWith(
          reduceAnimations: true,
          viewer: Settings.defaultSettings.viewer.copyWith(
            loadOriginalOnZoom: false,
            postQuality: PostQuality.high,
          ),
        ),
      ),
      appFileSystemProvider.overrideWithValue(MemoryAppFileSystem()),
      colorSchemeProvider.overrideWithValue(
        ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialSettingsBooruConfigProvider.overrideWithValue(_config),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(initialConfigs: [_config]),
      ),
      gelbooruV2Provider.overrideWithValue(
        GelbooruV2(
          config: BooruYamlConfigs.gelbooruV2,
          globalUserParams:
              BooruYamlConfigs.gelbooruV2.globalUserParams ?? const {},
        ),
      ),
      booruEngineRegistryProvider.overrideWithValue(BooruEngineRegistry()),
      booruPostPresentationProvider.overrideWith(
        (ref, request) => GelbooruV2Builder().postPresentation,
      ),
      booruLoginDetailsProvider.overrideWith(
        (ref, config) => DefaultBooruLoginDetails(
          login: config.login,
          apiKey: config.apiKey,
          url: config.url,
        ),
      ),
      gelbooruV2PostProvider.overrideWith((ref, params) => onFetch()),
      mediaUrlResolverProvider.overrideWith(
        (ref, config) => ref.watch(defaultMediaUrlResolverProvider(config)),
      ),
      booruRepoProvider.overrideWith((ref, config) => null),
      booruBuilderProvider.overrideWith((ref, config) => null),
      automaticMediaLoadingEnabledProvider.overrideWithValue(
        imageAdapter != null,
      ),
      zoomStudyEnabledProvider.overrideWithValue(false),
      deviceInfoProvider.overrideWithValue(DeviceInfo.empty()),
      appPlatformProvider.overrideWithValue(AppPlatform.android),
      if (imageAdapter case final adapter?)
        dioForWidgetProvider.overrideWith(
          (_, _) => Dio()..httpClientAdapter = adapter,
        ),
      if (imageAdapter case final adapter?)
        mediaOverrideDioProvider.overrideWith(
          (_, _) => Dio()..httpClientAdapter = adapter,
        ),
      if (imageAdapter case final adapter?)
        contentMediaDioProvider.overrideWith(
          (_, _) => Dio()..httpClientAdapter = adapter,
        ),
      if (imageCache case final cache?)
        defaultImageCacheManagerProvider.overrideWithValue(cache),
      hasPremiumLayoutProvider.overrideWithValue(false),
      showPremiumFeatsProvider.overrideWithValue(false),
      downloadServiceProvider.overrideWithValue(_DownloadService()),
      httpHeadersProvider.overrideWith((ref, config) => const {}),
      loggerProvider.overrideWithValue(const _Logger()),
      favoriteRepoProvider.overrideWith(
        (ref, config) => EmptyFavoriteRepository(),
      ),
      canFavoriteProvider.overrideWith((ref, config) => false),
    ],
    child: BooruLocalization(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: child!,
        ),
        home: navigationActive == null
            ? _viewer
            : ValueListenableBuilder(
                valueListenable: navigationActive!,
                child: _viewer,
                builder: (_, active, child) =>
                    NavigationActivity(active: active, child: child!),
              ),
      ),
    ),
  );
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
  String getDebugName() => 'Realbooru full post loader test';

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
