import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/downloads/urls/types.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_payload_tile.dart';
import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:image/image.dart' as img;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktoast/oktoast.dart';

import '../../../bulk_downloads/common.dart';

class _PendingExtractor
    implements DownloadFileUrlExtractor, ExactVideoUrlExtractor {
  final result = Completer<DownloadUrlData?>();
  var calls = 0;

  @override
  bool canResolveExactVideo(Post post) => true;

  @override
  Future<DownloadUrlData?> getDownloadFileUrl({
    required Post post,
    required String quality,
  }) {
    calls++;
    return result.future;
  }
}

class _FileSystem extends Mock implements AppFileSystem {}

class _CacheManager extends Mock implements ImageCacheManager {}

const _auth = BooruConfigAuth(
  booruId: 1,
  booruIdHint: 1,
  url: 'https://site.test',
  apiKey: null,
  login: null,
  passHash: null,
  proxySettings: null,
  networkSettings: null,
);

const _viewer = BooruConfigViewer(
  imageDetaisQuality: null,
  videoQuality: null,
  viewerNotesFetchBehavior: null,
  settings: null,
);

Future<void> _openSheet(
  WidgetTester tester, {
  required Post post,
  required DownloadFileUrlExtractor extractor,
  AppFileSystem? fileSystem,
  MediaUrlResolver? mediaUrlResolver,
  double textScale = 1,
  ImageCacheManager? imageCacheManager,
  ValueNotifier<Post>? postNotifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        downloadFileUrlExtractorProvider.overrideWith(
          (ref, config) => extractor,
        ),
        mediaUrlResolverProvider.overrideWith(
          (ref, config) => mediaUrlResolver ?? const SampleMediaUrlResolver(),
        ),
        postLinkGeneratorProvider.overrideWith(
          (ref, config) => const IntIdPostLinkGenerator(
            baseUrl: 'https://site.test',
            pathTemplate: 'posts/{id}',
          ),
        ),
        if (fileSystem != null)
          appFileSystemProvider.overrideWithValue(fileSystem),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: OKToast(child: TranslationProvider(child: child!)),
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) {
                  Widget sheet(Post currentPost) => UnifiedPostShareSheet(
                    post: currentPost,
                    auth: _auth,
                    viewer: _viewer,
                    imageCacheManager:
                        imageCacheManager ?? DefaultImageCacheManager(),
                  );
                  return postNotifier == null
                      ? sheet(post)
                      : ValueListenableBuilder<Post>(
                          valueListenable: postNotifier,
                          builder: (context, currentPost, _) =>
                              sheet(currentPost),
                        );
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Image describes encoded bytes already cached for its URL', (
    tester,
  ) async {
    final cache = _CacheManager();
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 3, height: 2)),
    );
    when(
      () => cache.generateCacheKey('https://site.test/sample.png'),
    ).thenReturn('sample-key');
    when(() => cache.getCachedFileBytes('sample-key')).thenReturn(bytes);

    await _openSheet(
      tester,
      post: dummyPost(
        id: 47,
        sampleImageUrl: 'https://site.test/sample.png',
        originalImageUrl: 'https://site.test/original.jpg',
        width: 2400,
        height: 1600,
        fileSize: 2097152,
        format: 'jpg',
      ),
      extractor: _PendingExtractor(),
      imageCacheManager: cache,
    );

    final image = tester.widget<SharePayloadTile>(
      find.byKey(const ValueKey(SharePayloadId.image)),
    );
    expect(image.description, '3 × 2 · ${bytes.length} B · PNG');
  });

  testWidgets(
    'Image subtitle keeps the sheet height steady as cache bytes arrive',
    (
      tester,
    ) async {
      final cache = _CacheManager();
      final cachedBytes = Completer<Uint8List?>();
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 3, height: 2)),
      );
      when(
        () => cache.generateCacheKey('https://site.test/sample.png'),
      ).thenReturn('sample-key');
      when(
        () => cache.getCachedFileBytes('sample-key'),
      ).thenAnswer((_) => cachedBytes.future);

      await _openSheet(
        tester,
        post: dummyPost(
          id: 48,
          sampleImageUrl: 'https://site.test/sample.png',
          originalImageUrl: 'https://site.test/original.jpg',
        ),
        extractor: _PendingExtractor(),
        imageCacheManager: cache,
        textScale: 2,
      );
      final sheet = find.byType(UnifiedPostShareSheet);
      final before = tester.getTopLeft(sheet).dy;
      final imageTile = find.byKey(const ValueKey(SharePayloadId.image));
      final rowHeight = tester.getSize(imageTile).height;
      expect(
        tester
            .widget<SharePayloadTile>(
              find.byKey(const ValueKey(SharePayloadId.image)),
            )
            .description,
        isNull,
      );

      cachedBytes.complete(bytes);
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<SharePayloadTile>(
              find.byKey(const ValueKey(SharePayloadId.image)),
            )
            .description,
        '3 × 2 · ${bytes.length} B · PNG',
      );
      expect(tester.getTopLeft(sheet).dy, before);
      expect(tester.getSize(imageTile).height, rowHeight);
    },
  );

  final unavailableCacheCases = [
    (name: 'missing', bytes: null),
    (name: 'unknown', bytes: Uint8List.fromList([1, 2, 3])),
    (
      name: 'corrupt',
      bytes: Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]),
    ),
  ];
  for (final testCase in unavailableCacheCases) {
    testWidgets('Image omits metadata for ${testCase.name} cached bytes', (
      tester,
    ) async {
      final cache = _CacheManager();
      final extractor = _PendingExtractor();
      when(
        () => cache.generateCacheKey('https://site.test/sample.png'),
      ).thenReturn('sample-key');
      when(
        () => cache.getCachedFileBytes('sample-key'),
      ).thenReturn(testCase.bytes);
      await _openSheet(
        tester,
        post: dummyPost(
          id: 49,
          sampleImageUrl: 'https://site.test/sample.png',
          originalImageUrl: 'https://site.test/original.jpg',
        ),
        extractor: extractor,
        imageCacheManager: cache,
      );
      final image = tester.widget<SharePayloadTile>(
        find.byKey(const ValueKey(SharePayloadId.image)),
      );
      expect(image.description, isNull);
      expect(find.text('Cancel'), findsNothing);
      expect(extractor.calls, 0);
    });
  }
  testWidgets('late cache bytes cannot replace a newly selected Image', (
    tester,
  ) async {
    final cache = _CacheManager();
    final oldBytes = Completer<Uint8List?>();
    final newBytes = Completer<Uint8List?>();
    const oldUrl = 'https://site.test/old.png';
    const newUrl = 'https://site.test/new.png';
    when(() => cache.generateCacheKey(oldUrl)).thenReturn('old-key');
    when(() => cache.generateCacheKey(newUrl)).thenReturn('new-key');
    when(
      () => cache.getCachedFileBytes('old-key'),
    ).thenAnswer((_) => oldBytes.future);
    when(
      () => cache.getCachedFileBytes('new-key'),
    ).thenAnswer((_) => newBytes.future);
    final first = dummyPost(
      id: 51,
      sampleImageUrl: oldUrl,
      originalImageUrl: 'https://site.test/original.jpg',
    );
    final selectedPost = ValueNotifier<Post>(first);
    addTearDown(selectedPost.dispose);
    final extractor = _PendingExtractor();
    await _openSheet(
      tester,
      post: first,
      postNotifier: selectedPost,
      extractor: extractor,
      imageCacheManager: cache,
    );
    selectedPost.value = dummyPost(
      id: 51,
      sampleImageUrl: newUrl,
      originalImageUrl: 'https://site.test/original.jpg',
    );
    await tester.pump();

    final selectedBytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 2)),
    );
    newBytes.complete(selectedBytes);
    await tester.pump();
    await tester.pump();
    final imageFinder = find.byKey(const ValueKey(SharePayloadId.image));
    expect(
      tester.widget<SharePayloadTile>(imageFinder).description,
      '4 × 2 · ${selectedBytes.length} B · PNG',
    );

    oldBytes.complete(
      Uint8List.fromList(img.encodePng(img.Image(width: 1, height: 1))),
    );
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<SharePayloadTile>(imageFinder).description,
      '4 × 2 · ${selectedBytes.length} B · PNG',
    );
    expect(extractor.calls, 0);
  });
  testWidgets(
    'Original shows known file details without resolving a file name',
    (
      tester,
    ) async {
      final extractor = _PendingExtractor();
      await _openSheet(
        tester,
        post: dummyPost(
          id: 42,
          sampleImageUrl: 'https://site.test/sample.jpg',
          originalImageUrl: 'https://site.test/original.jpg',
          width: 1920,
          height: 1080,
          fileSize: 1048576,
          format: 'jpg',
        ),
        extractor: extractor,
      );

      expect(find.text('1920 × 1080 · 1.0 MB · JPG'), findsOneWidget);
      expect(find.text('File name'), findsNothing);
      expect(find.byTooltip('Copy file name'), findsNothing);
      expect(find.byTooltip('Share file name'), findsNothing);
      expect(extractor.calls, 0);
    },
  );

  testWidgets('Image omits original details for a different viewer variant', (
    tester,
  ) async {
    await _openSheet(
      tester,
      post: dummyPost(
        id: 43,
        sampleImageUrl: 'https://site.test/sample.jpg',
        originalImageUrl: 'https://site.test/original.jpg',
        width: 1920,
        height: 1080,
        fileSize: 1048576,
        format: 'jpg',
      ),
      extractor: _PendingExtractor(),
    );

    final image = tester.widget<SharePayloadTile>(
      find.byKey(const ValueKey(SharePayloadId.image)),
    );
    final original = tester.widget<SharePayloadTile>(
      find.byKey(const ValueKey(SharePayloadId.original)),
    );
    expect(image.description, isNull);
    expect(original.description, '1920 × 1080 · 1.0 MB · JPG');
  });

  testWidgets('Image shows details when it uses the stored original URL', (
    tester,
  ) async {
    await _openSheet(
      tester,
      post: dummyPost(
        id: 44,
        sampleImageUrl: 'https://site.test/sample.png',
        originalImageUrl: 'https://site.test/original.png',
        width: 800,
        height: 600,
        format: 'png',
      ),
      extractor: _PendingExtractor(),
      mediaUrlResolver: _OriginalMediaUrlResolver(),
    );

    expect(find.text('800 × 600 · PNG'), findsNWidgets(2));
    expect(find.textContaining('0 B'), findsNothing);
  });

  testWidgets(
    'Image omits original details when stored original is a preview',
    (
      tester,
    ) async {
      await _openSheet(
        tester,
        post:
            dummyPost(
              id: 46,
              thumbnailImageUrl: 'https://site.test/thumb.jpg',
              sampleImageUrl: 'https://site.test/big-preview.jpg',
              originalImageUrl: 'https://site.test/big-preview.jpg',
              width: 2400,
              height: 1600,
              fileSize: 2097152,
              format: 'jpg',
            ).copyWith(
              origin: PostOrigin.forBooruType(BooruType.animePictures),
            ),
        extractor: _PendingExtractor(),
      );

      final image = tester.widget<SharePayloadTile>(
        find.byKey(const ValueKey(SharePayloadId.image)),
      );
      final original = tester.widget<SharePayloadTile>(
        find.byKey(const ValueKey(SharePayloadId.original)),
      );
      expect(image.description, isNull);
      expect(original.description, '2400 × 1600 · 2.0 MB · JPG');
    },
  );

  testWidgets('Original omits a file type that conflicts with its URL', (
    tester,
  ) async {
    await _openSheet(
      tester,
      post: dummyPost(
        id: 45,
        sampleImageUrl: 'https://site.test/sample.jpg',
        originalImageUrl: 'https://site.test/original.png',
        width: 800,
        height: 600,
        format: 'jpg',
      ),
      extractor: _PendingExtractor(),
    );

    final original = tester.widget<SharePayloadTile>(
      find.byKey(const ValueKey(SharePayloadId.original)),
    );
    expect(original.description, '800 × 600');
  });

  testWidgets('Original has no subtitle when all file details are unknown', (
    tester,
  ) async {
    await _openSheet(
      tester,
      post: dummyPost(originalImageUrl: 'https://site.test/original.jpg'),
      extractor: _PendingExtractor(),
    );

    final original = tester.widget<SharePayloadTile>(
      find.byKey(const ValueKey(SharePayloadId.original)),
    );
    expect(original.description, isNull);
  });

  testWidgets('fast Video Copy never reveals media progress', (tester) async {
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
    await _openSheet(
      tester,
      post: dummyPost(
        id: 50,
        format: 'mp4',
        videoUrl: 'https://site.test/full.mp4',
        originalImageUrl: 'https://site.test/full.mp4',
      ),
      extractor: const UrlInsidePostExtractor(),
    );

    await tester.tap(find.byTooltip('Copy video link'));
    await tester.pump();
    expect(find.text('Cancel'), findsNothing);
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(copied, 'https://site.test/full.mp4');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  final cases = [
    (name: 'Image Copy', tooltip: 'Copy image', video: false),
    (name: 'Original Copy', tooltip: 'Copy original', video: false),
    (name: 'Original Share', tooltip: 'Share original', video: false),
    (name: 'Video Copy', tooltip: 'Copy video link', video: true),
  ];

  for (final testCase in cases) {
    testWidgets('${testCase.name} cancellation restores the sheet', (
      tester,
    ) async {
      final extractor = _PendingExtractor();
      final fileSystem = _FileSystem();
      final temporaryPath = Completer<String?>();
      when(fileSystem.getTemporaryPath).thenAnswer((_) => temporaryPath.future);
      await _openSheet(
        tester,
        post: dummyPost(
          id: 43,
          format: testCase.video ? 'mp4' : 'jpg',
          sampleImageUrl: 'https://site.test/sample.jpg',
          originalImageUrl: testCase.video
              ? 'https://site.test/full.mp4'
              : 'https://site.test/original.jpg',
          videoUrl: testCase.video ? 'https://site.test/full.mp4' : '',
        ),
        extractor: extractor,
        fileSystem: fileSystem,
      );
      final sheet = find.byType(UnifiedPostShareSheet);
      final before = tester.getTopLeft(sheet).dy;

      await tester.tap(find.byTooltip(testCase.tooltip));
      await tester.pump();
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 499));
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.getTopLeft(sheet).dy, before);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(sheet).dy, before);
      if (!extractor.result.isCompleted) {
        extractor.result.complete(
          const DownloadUrlData.urlOnly('https://cdn.test/full.mp4'),
        );
      }
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Preparation cancelled. Retry'), findsNothing);
      if (!temporaryPath.isCompleted) temporaryPath.complete(null);
    });
  }
}

class _OriginalMediaUrlResolver extends DefaultMediaUrlResolver {
  _OriginalMediaUrlResolver() : super(postQuality: PostQuality.high);

  @override
  String resolveMediaUrl(Post post, BooruConfigViewer config) =>
      super.resolveMediaUrl(
        post,
        BooruConfigViewer(
          imageDetaisQuality: 'original',
          videoQuality: config.videoQuality,
          viewerNotesFetchBehavior: config.viewerNotesFetchBehavior,
          settings: config.settings,
        ),
      );
}
