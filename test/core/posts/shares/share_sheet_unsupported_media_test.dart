import 'dart:io';
import 'dart:typed_data';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';

import '../../../bulk_downloads/common.dart';
import 'share_test_utils.dart';

class _FileSystem extends Mock implements AppFileSystem {}

class _CacheManager extends Mock implements ManagedImageCacheManager {}

void main() {
  testWidgets('unsupported media sharing disables retry and Share', (
    tester,
  ) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('share-sheet-test-'),
    );
    addTearDown(() => root!.delete(recursive: true));
    final fs = _FileSystem();
    when(fs.getTemporaryPath).thenAnswer((_) async => root!.path);
    final cache = _CacheManager();
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    final cachedImage = File('${root!.path}/cacheimage/cached-image');
    await tester.runAsync(() async {
      await cachedImage.parent.create(recursive: true);
      await cachedImage.writeAsBytes(png);
    });
    when(() => cache.generateCacheKey(any())).thenReturn('cached-image');
    when(
      () => cache.acquireFile('cached-image'),
    ).thenAnswer((_) async => _TestFileLease(cachedImage.path));
    when(() => cache.getCachedFileBytes('cached-image')).thenReturn(png);
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
          appFileSystemProvider.overrideWithValue(fs),
          mediaUrlResolverProvider.overrideWith(
            (ref, config) => const SampleMediaUrlResolver(),
          ),
          postLinkGeneratorProvider.overrideWith(
            (ref, config) => const IntIdPostLinkGenerator(
              baseUrl: 'https://site.test',
              pathTemplate: 'posts/{id}',
            ),
          ),
          downloadFileUrlExtractorProvider.overrideWith(
            (ref, config) => const UrlInsidePostExtractor(),
          ),
          bypassDdosHeadersProvider.overrideWith(
            (ref, url) => const {},
          ),
          httpHeadersProvider.overrideWith((ref, config) => const {}),
          dioForWidgetProvider.overrideWith((ref, config) => Dio()),
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
                id: 42,
                sampleImageUrl: 'https://site.test/sample.png',
                originalImageUrl: 'https://site.test/original.png',
              ),
              auth: auth,
              viewer: viewer,
              imageCacheManager: cache,
              shareAdapter: ShareActionAdapter(
                (_) => Future.error(UnimplementedError('No file sharing')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Share Image'));
      await pumpUntilShareCondition(
        tester,
        () => find
            .text('Media sharing is not supported on this device.')
            .evaluate()
            .isNotEmpty,
        reason: 'The failed native share must report unsupported media',
      );
      // Error UI is published before the operation's finally releases its file.
      // Wait for that release before teardown removes the containing directory.
      await pumpUntilShareCondition(
        tester,
        () => Directory('${root.path}/boorusama-share').listSync().isEmpty,
        reason: 'The failed native share must release its temporary file',
      );
    });
    await tester.pumpAndSettle();

    expect(
      find.text('Media sharing is not supported on this device.'),
      findsWidgets,
    );
    expect(find.text('Retry'), findsNothing);
    expect(find.byTooltip('Share Image'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Share Image'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
}

class _TestFileLease extends ImageCacheFileLease {
  _TestFileLease(this.path);
  @override
  final String path;
  @override
  bool get isRetained => true;
  @override
  Future<void> release() async {}
}
