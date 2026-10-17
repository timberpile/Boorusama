// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart' as material_ui;

// Project imports:
import 'package:boorusama/boorus/danbooru/posts/post/src/providers.dart';
import 'package:boorusama/boorus/e621/downloads/providers.dart';
import 'package:boorusama/boorus/e621/posts/types.dart';
import 'package:boorusama/boorus/moebooru/downloads/providers.dart';
import 'package:boorusama/boorus/moebooru/posts/post_data.dart';
import 'package:boorusama/boorus/philomena/downloads/providers.dart';
import 'package:boorusama/boorus/philomena/posts/types.dart';
import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/network/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/download_activity/activity.dart';
import 'package:boorusama/core/downloads/downloader/providers.dart';
import 'package:boorusama/core/downloads/downloader/types.dart';
import 'package:boorusama/core/downloads/sidecar/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/posts/details_parts/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/reboot.dart';

import '../application/support/fake_booru_backend.dart';
import '../application/support/fake_image_dio.dart';
import '../application/support/headless_app_harness.dart';
import '../support/boorusama_test_runtime.dart';

Bookmark _bookmark(BooruConfig config, {bool video = false}) => Bookmark(
  id: 1,
  booruId: config.auth.booruIdHint,
  postId: 101,
  createdAt: DateTime.utc(2026, 10, 17),
  updatedAt: DateTime.utc(2026, 10, 17),
  thumbnailUrl: 'https://images.test/101-preview.jpg',
  sampleUrl: 'https://images.test/101-sample.jpg',
  originalUrl: video
      ? 'https://images.test/101-original.mp4'
      : 'https://images.test/101-original.jpg',
  sourceUrl: config.url,
  width: 100,
  height: 100,
  md5: '00000000000000000000000000000101',
  tags: const {'cat', 'blue_hair'},
  realSourceUrl: 'https://source.test/101',
  format: video ? '.mp4' : '.jpg',
  imageUrlResolver: const DefaultImageUrlResolver(),
  metadata: const {},
).copyWith(sourceUrl: '${config.url}posts/101');

const _settings = Settings.defaultSettings;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final format in SidecarFormat.values) {
    test(
      'bookmark downloads freeze $format snapshot using actual Original',
      () async {
        final backend = FakeBooruBackend();
        final service = MemoryDownloadService();
        final settings = _settings.copyWith(
          downloadSidecarFormat: format,
          downloadQuality: DownloadQuality.preview,
          downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
        );
        final runtime = backend.createRuntime(
          settings: settings,
          downloadService: service,
        );
        final initial = runtime.initialState;
        final container = ProviderContainer(
          overrides: buildBoorusamaOverrides(
            runtime,
            RebootData(
              config: initial.initialConfig,
              configs: initial.configs,
              settings: initial.settings,
            ),
          ),
        );
        addTearDown(container.dispose);
        await container.read(bookmarkProvider.future);

        await container.read(bookmarkProvider.notifier).downloadBookmarks(
          backend.config.auth,
          backend.config.download,
          [_bookmark(backend.config, video: true)],
        );

        expect(service.requests, hasLength(1));
        final request = service.requests.single;
        expect(request.url, 'https://images.test/101-original.mp4');
        expect(request.metadata!.isVideo, isTrue);
        if (format == SidecarFormat.off) {
          expect(request.sidecar, isNull);
        } else {
          expect(request.sidecar!.format, format);
          expect(request.sidecar!.quality, 'original');
          expect(request.sidecar!.postId, '101');
          expect(request.sidecar!.site, 'https://headless.booru.test');
          expect(request.sidecar!.urls, contains('https://source.test/101'));
          expect(request.sidecar!.postUrl, '${backend.config.url}posts/101');
          expect(request.sidecar!.tags, ['blue_hair', 'cat']);
        }
      },
    );
  }
  for (final (index, quality) in [
    (0, 'preview'),
    (1, 'sample'),
    (2, 'original'),
  ]) {
    testWidgets(
      'real default $quality menu records selected URL and quality in JSON',
      (tester) async {
        final backend = FakeBooruBackend();
        backend.posts[0] = TestPost(
          id: 101,
          tags: const {'cat', 'blue_hair'},
          thumbnailImageUrl: 'https://images.test/101-preview.jpg',
          sampleImageUrl: 'https://images.test/101-sample.jpg',
          originalImageUrl: 'https://images.test/101-original.jpg',
        );
        final service = MemoryDownloadService();
        final settings = _settings.copyWith(
          downloadSidecarFormat: SidecarFormat.json,
          downloadQuality: quality == 'original'
              ? DownloadQuality.preview
              : DownloadQuality.original,
          downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
        );
        final harness = HeadlessAppHarness(
          booruBackend: backend,
          runtime: backend.createRuntime(
            settings: settings,
            downloadService: service,
          ),
          additionalOverrides: [
            deterministicImageDioOverride(),
            deterministicFaviconDioOverride(),
            // Exercise the actual production source entries, not hand-built entries.
            downloadSourceProvider.overrideWith(
              (ref, config) => const DefaultDownloadSource(),
            ),
          ],
        );
        try {
          await harness.pump(tester);
          await harness.openFirstPost(tester);
          await tester.tap(find.byType(KurumiInfoCircleIcon).first);
          await harness.pumpUntilFound(tester, find.byType(DownloadPostButton));
          await harness.settle(tester);

          final downloadButton = find.byType(DownloadPostButton).last;
          await tester.ensureVisible(downloadButton);
          final post = tester.widget<DownloadPostButton>(downloadButton).post;
          expect(post.thumbnailImageUrl, isNotEmpty);
          expect(post.thumbnailImageUrl, isNot(post.originalImageUrl));
          final control = find
              .descendant(
                of: downloadButton,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is material_ui.IconButton &&
                      widget.onLongPress != null,
                ),
              )
              .first;
          tester.widget<material_ui.IconButton>(control).onLongPress!.call();
          await harness.pumpUntilFound(
            tester,
            find.byType(KurumiPopupMenuItem),
          );
          await harness.settle(tester);

          await tester.tap(find.byType(KurumiPopupMenuItem).at(index));
          await harness.pumpUntil(tester, () => service.requests.isNotEmpty);
          expect(
            service.requests.single.url,
            'https://images.test/101-$quality.jpg',
          );
          expect(service.requests.single.sidecar, isNotNull);
          expect(service.requests.single.sidecar!.quality, quality);
        } finally {
          await harness.teardown(tester);
        }
      },
    );
  }
  test(
    'bookmark download applies the configured media host override',
    () async {
      final backend = FakeBooruBackend();
      final service = MemoryDownloadService();
      final config = backend.config.copyWith(
        networkSettings: () => NetworkSettings(
          mediaHostOverrides: [
            MediaHostOverride(from: 'images.test', to: 'mirror.test'),
          ],
        ),
      );
      final runtime = backend.createRuntime(
        configs: [backend.configB, config],
        initialConfig: backend.configB,
        settings: _settings.copyWith(
          downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
        ),
        downloadService: service,
      );
      final initial = runtime.initialState;
      final container = ProviderContainer(
        overrides: [
          ...buildBoorusamaOverrides(
            runtime,
            RebootData(
              config: initial.initialConfig,
              configs: initial.configs,
              settings: initial.settings,
            ),
          ),
          httpHeadersProvider.overrideWith(
            (ref, auth) {
              expect(auth.url, config.url);
              return {
                'Authorization': 'source-secret',
                'Cookie': 'source-cookie',
                'X-Api-Key': 'source-key',
                'Accept': 'image/*',
              };
            },
          ),
          bypassDdosHeadersProvider.overrideWith((ref, url) {
            expect(url, 'https://mirror.test/101-original.jpg');
            return Future.value({'cookie': 'destination-clearance'});
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(bookmarkProvider.future);

      await container.read(bookmarkProvider.notifier).downloadBookmarks(
        backend.configB.auth,
        backend.configB.download,
        [_bookmark(config)],
      );

      expect(service.requests, hasLength(1));
      expect(
        service.requests.single.url,
        'https://mirror.test/101-original.jpg',
      );
      expect(service.requests.single.headers, {
        'Accept': 'image/*',
        'cookie': 'destination-clearance',
      });
      expect(service.requests.single.metadata!.mediaHostOverridden, isTrue);
      expect(
        service.requests.single.metadata!.siteUrl,
        '${config.url}posts/101',
      );
    },
  );
  for (final url in ['', 'https://exact.test/custom.jpg']) {
    test(
      'exact URL "$url" does not inherit a global quality or fallback',
      () async {
        final backend = FakeBooruBackend();
        final service = MemoryDownloadService();
        final runtime = backend.createRuntime(
          settings: _settings.copyWith(
            downloadSidecarFormat: SidecarFormat.json,
            downloadQuality: DownloadQuality.preview,
            downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
          ),
          downloadService: service,
        );
        final initial = runtime.initialState;
        final container = ProviderContainer(
          overrides: buildBoorusamaOverrides(
            runtime,
            RebootData(
              config: initial.initialConfig,
              configs: initial.configs,
              settings: initial.settings,
            ),
          ),
        );
        addTearDown(container.dispose);
        final params = container.read(
          downloadNotifierParamsProvider((
            backend.config.auth,
            backend.config.download,
          )),
        );
        await container
            .read(downloadNotifierProvider(params).notifier)
            .download(backend.posts.first, overrideUrl: url);
        if (url.isEmpty) {
          expect(service.requests, isEmpty);
          expect(
            container.read(immediateDownloadActivitiesProvider).single.phase,
            DownloadActivityPhase.failed,
          );
        } else {
          expect(service.requests.single.url, url);
          expect(service.requests.single.sidecar!.quality, 'custom');
        }
      },
    );
  }

  testWidgets(
    'Moebooru missing JPEG omits Large rather than substituting Original',
    (tester) async {
      final post = TestPost(
        id: 101,
        tags: const {'cat'},
        thumbnailImageUrl: 'https://images.test/preview.jpg',
        sampleImageUrl: 'https://images.test/sample.jpg',
        originalImageUrl: 'https://images.test/original.png',
      ).copyWith(booruData: const MoebooruPostData(largeImageUrl: ''));
      late List<DownloadSource> sources;
      await tester.pumpWidget(
        BooruLocalization(
          child: material_ui.MaterialApp(
            home: material_ui.Builder(
              builder: (context) {
                sources = const MoebooruDownloadSource().getDownloadSources(
                  context,
                  post,
                );
                return const material_ui.SizedBox();
              },
            ),
          ),
        ),
      );
      expect(sources.map((source) => source.url), [
        'https://images.test/preview.jpg',
        'https://images.test/sample.jpg',
        'https://images.test/original.png',
      ]);
      expect(sources.map((source) => source.quality), [
        'preview',
        'sample',
        'original',
      ]);
    },
  );

  testWidgets('e621 empty concrete video variants are unavailable', (
    tester,
  ) async {
    final post = TestPost(id: 101, tags: const {'cat'}).copyWith(
      booruData: const E621PostData(
        generalTags: {},
        metaTags: {},
        speciesTags: {},
        invalidTags: {},
        loreTags: {},
        upScore: 0,
        downScore: 0,
        favCount: 0,
        isFavorited: false,
        sources: [],
        description: '',
        videoVariants: [
          E621VideoVariantData(
            type: E621VideoVariantType.v480p,
            url: '',
            size: 0,
            width: 0,
            height: 0,
            codec: '',
            fps: 0,
          ),
        ],
      ),
    );
    late List<DownloadSource> sources;
    await tester.pumpWidget(
      BooruLocalization(
        child: material_ui.MaterialApp(
          home: material_ui.Builder(
            builder: (context) {
              sources = const E621DownloadSource().getDownloadSources(
                context,
                post,
              );
              return const material_ui.SizedBox();
            },
          ),
        ),
      ),
    );
    expect(sources.where((source) => source.url == ''), isEmpty);
  });
  for (final fixture in _siteSourceFixtures()) {
    testWidgets(
      '${fixture.name} source URLs and actual JSON snapshot identities agree',
      (tester) async {
        final backend = FakeBooruBackend();
        final service = MemoryDownloadService();
        final runtime = backend.createRuntime(
          settings: _settings.copyWith(
            downloadSidecarFormat: SidecarFormat.json,
            downloadQuality: DownloadQuality.preview,
            downloadNetworkPolicy: DownloadNetworkPolicy.anyNetwork,
          ),
          downloadService: service,
        );
        final initial = runtime.initialState;
        final container = ProviderContainer(
          overrides: buildBoorusamaOverrides(
            runtime,
            RebootData(
              config: initial.initialConfig,
              configs: initial.configs,
              settings: initial.settings,
            ),
          ),
        );
        addTearDown(container.dispose);
        late List<DownloadSource> sources;
        await tester.pumpWidget(
          BooruLocalization(
            child: material_ui.MaterialApp(
              home: material_ui.Builder(
                builder: (context) {
                  sources = fixture.provider.getDownloadSources(
                    context,
                    fixture.post,
                  );
                  return const material_ui.SizedBox();
                },
              ),
            ),
          ),
        );
        expect(
          sources.map((source) => (source.url, source.quality)),
          fixture.expected,
        );
        await tester.runAsync(() async {
          final params = container.read(
            downloadNotifierParamsProvider((
              backend.config.auth,
              backend.config.download,
            )),
          );
          for (final source in sources) {
            await container
                .read(downloadNotifierProvider(params).notifier)
                .download(
                  fixture.post,
                  overrideUrl: source.url,
                  quality: source.quality,
                );
          }
        });
        expect(
          service.requests.map(
            (request) => (request.url, request.sidecar!.quality),
          ),
          fixture.expected,
        );
        await tester.pump();
      },
    );
  }
}

typedef _SourceFixture = ({
  String name,
  DownloadSourceProvider provider,
  Post post,
  List<(String, String)> expected,
});

List<_SourceFixture> _siteSourceFixtures() {
  final base = TestPost(
    id: 101,
    tags: const {'cat'},
    thumbnailImageUrl: 'https://images.test/preview.jpg',
    sampleImageUrl: 'https://images.test/sample.jpg',
    originalImageUrl: 'https://images.test/original.png',
  );
  final core = base.core;
  final danbooru = base.copyWith(
    core: PostCoreData(
      id: core.id,
      thumbnailImageUrl: core.thumbnailImageUrl,
      sampleImageUrl: core.sampleImageUrl,
      originalImageUrl: core.originalImageUrl,
      videoUrl: core.videoUrl,
      videoThumbnailUrl: core.videoThumbnailUrl,
      width: core.width,
      height: core.height,
      format: core.format,
      md5: core.md5,
      fileSize: core.fileSize,
      duration: core.duration,
      tags: core.tags,
      rating: core.rating,
      hasComment: core.hasComment,
      isTranslated: core.isTranslated,
      hasParentOrChildren: core.hasParentOrChildren,
      source: core.source,
      score: core.score,
      mediaVariants: const {
        '180x180': 'https://images.test/180.jpg',
        '360x360': 'https://images.test/360.jpg',
        '720x720': 'https://images.test/720.jpg',
      },
    ),
  );
  return [
    (
      name: 'Danbooru',
      provider: const DanbooruDownloadSource(),
      post: danbooru,
      expected: [
        ('https://images.test/preview.jpg', 'preview'),
        ('https://images.test/180.jpg', '180x180'),
        ('https://images.test/360.jpg', '360x360'),
        ('https://images.test/720.jpg', '720x720'),
        ('https://images.test/sample.jpg', 'sample'),
        ('https://images.test/original.png', 'original'),
      ],
    ),
    (
      name: 'Moebooru JPEG/Large',
      provider: const MoebooruDownloadSource(),
      post: base.copyWith(
        booruData: const MoebooruPostData(
          largeImageUrl: 'https://images.test/original-size.jpeg',
        ),
      ),
      expected: [
        ('https://images.test/preview.jpg', 'preview'),
        ('https://images.test/original-size.jpeg', 'large'),
        ('https://images.test/sample.jpg', 'sample'),
        ('https://images.test/original.png', 'original'),
      ],
    ),
    (
      name: 'Philomena representations',
      provider: const PhilomenaDownloadSource(),
      post: base.copyWith(
        booruData: const PhilomenaPostData(
          description: '',
          commentCount: 0,
          favCount: 0,
          upvotes: 0,
          representation: PhilomenaRepresentation(
            thumbTiny: 'https://images.test/tiny.jpg',
            thumbSmall: 'https://images.test/thumb-small.jpg',
            thumb: 'https://images.test/thumb.jpg',
            small: 'https://images.test/small.jpg',
            medium: 'https://images.test/medium.jpg',
            tall: 'https://images.test/tall.jpg',
            large: 'https://images.test/large.jpg',
            full: 'https://images.test/full.png',
          ),
        ),
      ),
      expected: [
        ('https://images.test/tiny.jpg', 'thumb_tiny'),
        ('https://images.test/thumb-small.jpg', 'thumb_small'),
        ('https://images.test/thumb.jpg', 'thumb'),
        ('https://images.test/small.jpg', 'small'),
        ('https://images.test/medium.jpg', 'medium'),
        ('https://images.test/tall.jpg', 'tall'),
        ('https://images.test/large.jpg', 'large'),
        ('https://images.test/full.png', 'original'),
      ],
    ),
    (
      name: 'e621 video variants',
      provider: const E621DownloadSource(),
      post: base.copyWith(
        booruData: const E621PostData(
          generalTags: {},
          metaTags: {},
          speciesTags: {},
          invalidTags: {},
          loreTags: {},
          upScore: 0,
          downScore: 0,
          favCount: 0,
          isFavorited: false,
          sources: [],
          description: '',
          videoVariants: [
            E621VideoVariantData(
              type: E621VideoVariantType.v480p,
              url: 'https://images.test/480.webm',
              size: 100,
              width: 640,
              height: 480,
              codec: 'vp9',
              fps: 30,
            ),
            E621VideoVariantData(
              type: E621VideoVariantType.v720p,
              url: 'https://images.test/720.webm',
              size: 200,
              width: 1280,
              height: 720,
              codec: 'vp9',
              fps: 30,
            ),
          ],
        ),
      ),
      expected: [
        ('https://images.test/preview.jpg', 'preview'),
        ('https://images.test/sample.jpg', 'sample'),
        ('https://images.test/480.webm', '480p'),
        ('https://images.test/720.webm', '720p'),
        ('https://images.test/original.png', 'original'),
      ],
    ),
    (
      name: 'Philomena legacy fallback',
      provider: const PhilomenaDownloadSource(),
      post: base,
      expected: [
        ('https://images.test/preview.jpg', 'preview'),
        ('https://images.test/sample.jpg', 'sample'),
        ('https://images.test/original.png', 'original'),
      ],
    ),
  ];
}
