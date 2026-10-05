import 'dart:async';
import 'package:boorusama/boorus/e621/downloads/providers.dart';
import 'package:boorusama/boorus/e621/posts/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:oktoast/oktoast.dart';

import '../../../bulk_downloads/common.dart';

class _VideoExtractor
    implements DownloadFileUrlExtractor, ExactVideoUrlExtractor {
  var calls = 0;

  @override
  bool canResolveExactVideo(Post post) => true;

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) async {
    expect(quality, 'original');
    calls++;
    return const DownloadUrlData.urlOnly(
      'https://cdn.test/exact.mp4?token=resolved',
    );
  }
}

void main() {
  testWidgets(
    'pending clipboard write keeps progress but cannot be cancelled',
    (
      tester,
    ) async {
      final writeStarted = Completer<void>();
      final pendingWrite = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          writeStarted.complete();
          await pendingWrite.future;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      const auth = BooruConfigAuth(
        booruId: 1,
        booruIdHint: 1,
        url: 'https://site.test',
        apiKey: null,
        login: null,
        passHash: null,
        proxySettings: null,
        networkSettings: null,
      );
      const viewer = BooruConfigViewer(
        imageDetaisQuality: null,
        videoQuality: null,
        viewerNotesFetchBehavior: null,
        settings: null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadFileUrlExtractorProvider.overrideWith(
              (ref, config) => _VideoExtractor(),
            ),
            mediaUrlResolverProvider.overrideWith(
              (ref, config) => const SampleMediaUrlResolver(),
            ),
            postLinkGeneratorProvider.overrideWith(
              (ref, config) => const IntIdPostLinkGenerator(
                baseUrl: 'https://site.test',
                pathTemplate: 'posts/{id}',
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: OKToast(child: TranslationProvider(child: child!)),
            ),
            home: Scaffold(
              body: UnifiedPostShareSheet(
                post: dummyPost(
                  id: 42,
                  format: 'mp4',
                  videoUrl: 'https://site.test/preview.mp4',
                ),
                auth: auth,
                viewer: viewer,
                imageCacheManager: DefaultImageCacheManager(),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Copy video link'));
        await Future<void>.delayed(const Duration(milliseconds: 650));
      });
      await tester.pump();
      expect(writeStarted.isCompleted, isTrue);
      expect(find.text('Copying to clipboard…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Copied'), findsNothing);

      pendingWrite.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  final cases = [
    (name: 'stored preview', videoUrl: 'https://site.test/preview.mp4'),
    (name: 'lazy video', videoUrl: ''),
  ];

  for (final testCase in cases) {
    testWidgets('copies the exact video link for ${testCase.name}', (
      tester,
    ) async {
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final extractor = _VideoExtractor();
      const auth = BooruConfigAuth(
        booruId: 1,
        booruIdHint: 1,
        url: 'https://site.test',
        apiKey: null,
        login: null,
        passHash: null,
        proxySettings: null,
        networkSettings: null,
      );
      const viewer = BooruConfigViewer(
        imageDetaisQuality: null,
        videoQuality: null,
        viewerNotesFetchBehavior: null,
        settings: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            downloadFileUrlExtractorProvider.overrideWith(
              (ref, config) => extractor,
            ),
            mediaUrlResolverProvider.overrideWith(
              (ref, config) => const SampleMediaUrlResolver(),
            ),
            postLinkGeneratorProvider.overrideWith(
              (ref, config) => const IntIdPostLinkGenerator(
                baseUrl: 'https://site.test',
                pathTemplate: 'posts/{id}',
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: OKToast(child: TranslationProvider(child: child!)),
            ),
            home: Scaffold(
              body: UnifiedPostShareSheet(
                post: dummyPost(
                  id: 42,
                  format: 'mp4',
                  videoUrl: testCase.videoUrl,
                ),
                auth: auth,
                viewer: viewer,
                imageCacheManager: DefaultImageCacheManager(),
              ),
            ),
          ),
        ),
      );

      expect(find.text(testCase.videoUrl), findsNothing);
      expect(find.text('Prepared when selected'), findsNothing);
      expect(find.byTooltip('Copy video link'), findsOneWidget);
      expect(find.byTooltip('Share video'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy video link'));
      await tester.pumpAndSettle();

      expect(copied, 'https://cdn.test/exact.mp4?token=resolved');
      expect(find.text('exact.mp4'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('preview-only video keeps both Video actions disabled', (
    tester,
  ) async {
    const auth = BooruConfigAuth(
      booruId: 1,
      booruIdHint: 1,
      url: 'https://site.test',
      apiKey: null,
      login: null,
      passHash: null,
      proxySettings: null,
      networkSettings: null,
    );
    const viewer = BooruConfigViewer(
      imageDetaisQuality: null,
      videoQuality: null,
      viewerNotesFetchBehavior: null,
      settings: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadFileUrlExtractorProvider.overrideWith(
            (ref, config) => const UrlInsidePostExtractor(),
          ),
          mediaUrlResolverProvider.overrideWith(
            (ref, config) => const SampleMediaUrlResolver(),
          ),
          postLinkGeneratorProvider.overrideWith(
            (ref, config) => const IntIdPostLinkGenerator(
              baseUrl: 'https://site.test',
              pathTemplate: 'posts/{id}',
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: TranslationProvider(child: child!),
          ),
          home: Scaffold(
            body: UnifiedPostShareSheet(
              post: dummyPost(
                id: 45,
                format: 'mp4',
                sampleImageUrl: 'https://site.test/preview.jpg',
                thumbnailImageUrl: 'https://site.test/thumb.jpg',
              ),
              auth: auth,
              viewer: viewer,
              imageCacheManager: DefaultImageCacheManager(),
            ),
          ),
        ),
      ),
    );

    for (final tooltip in [
      'Copy video link',
      'Share video',
    ]) {
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip(tooltip),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    }
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('https://site.test/thumb.jpg'), findsNothing);
  });

  final originalAlsoSample = dummyPost(
    id: 53,
    format: 'mp4',
    originalImageUrl: 'https://site.test/full.mp4',
    sampleImageUrl: 'https://site.test/full.mp4',
    thumbnailImageUrl: 'https://site.test/thumb.jpg',
  );
  final e621OriginalAlsoSample = originalAlsoSample.copyWith(
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
          type: E621VideoVariantType.original,
          url: 'https://site.test/full.mp4',
          size: 0,
          width: 0,
          height: 0,
          codec: '',
          fps: 0,
        ),
      ],
    ),
  );
  final sharedOriginalCases =
      <
        ({
          String name,
          Post post,
          DownloadFileUrlExtractor extractor,
        })
      >[
        (
          name: 'default',
          post: originalAlsoSample,
          extractor: const UrlInsidePostExtractor(),
        ),
        (
          name: 'Gelbooru V2 fields',
          post: dummyPost(
            id: 54,
            format: 'mp4',
            originalImageUrl: 'https://site.test/full.mp4',
            sampleImageUrl: 'https://site.test/full.mp4',
            videoUrl: 'https://site.test/full.mp4',
            thumbnailImageUrl: 'https://site.test/thumb.jpg',
          ),
          extractor: const UrlInsidePostExtractor(),
        ),
        (
          name: 'E621 exact',
          post: e621OriginalAlsoSample,
          extractor: const E621DownloadFileUrlExtractor(),
        ),
      ];

  for (final testCase in sharedOriginalCases) {
    testWidgets(
      'proven original also stored as sample keeps Video actions for ${testCase.name}',
      (tester) async {
        String? copied;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        const auth = BooruConfigAuth(
          booruId: 1,
          booruIdHint: 1,
          url: 'https://site.test',
          apiKey: null,
          login: null,
          passHash: null,
          proxySettings: null,
          networkSettings: null,
        );
        const viewer = BooruConfigViewer(
          imageDetaisQuality: null,
          videoQuality: null,
          viewerNotesFetchBehavior: null,
          settings: null,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              downloadFileUrlExtractorProvider.overrideWith(
                (ref, config) => testCase.extractor,
              ),
              mediaUrlResolverProvider.overrideWith(
                (ref, config) => const SampleMediaUrlResolver(),
              ),
              postLinkGeneratorProvider.overrideWith(
                (ref, config) => const IntIdPostLinkGenerator(
                  baseUrl: 'https://site.test',
                  pathTemplate: 'posts/{id}',
                ),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: OKToast(child: TranslationProvider(child: child!)),
              ),
              home: Scaffold(
                body: UnifiedPostShareSheet(
                  post: testCase.post,
                  auth: auth,
                  viewer: viewer,
                  imageCacheManager: DefaultImageCacheManager(),
                ),
              ),
            ),
          ),
        );

        for (final tooltip in [
          'Copy video link',
          'Share video',
        ]) {
          expect(
            tester
                .widget<IconButton>(
                  find.ancestor(
                    of: find.byTooltip(tooltip),
                    matching: find.byType(IconButton),
                  ),
                )
                .onPressed,
            isNotNull,
          );
        }
        expect(find.text('https://site.test/full.mp4'), findsNothing);
        await tester.tap(find.byTooltip('Copy video link'));
        await tester.pumpAndSettle();
        expect(copied, 'https://site.test/full.mp4');
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      },
    );
  }
}
