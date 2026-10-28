import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/ddos/handler/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/posts/links/boorusama_box_icon.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/foundation/filesystem.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';
import 'package:kurumi/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:oktoast/oktoast.dart';
import 'package:share_plus/share_plus.dart';

import '../../../bulk_downloads/common.dart';
import '../../../support/fakes/memory_app_file_system.dart';

class _Cache extends Mock implements ManagedImageCacheManager {}

const _auth = BooruConfigAuth(
  booruId: 1,
  booruIdHint: 1,
  url: 'https://site.test',
  apiKey: 'must-not-leak',
  login: 'private',
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

Post _post({String preview = 'https://site.test/sample.png'}) =>
    dummyPost(
      id: 42,
      sampleImageUrl: preview,
      format: 'png',
    ).copyWith(
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: 1,
        source: 'https://site.test',
        profileIdHint: '00000000-0000-4000-8000-000000000001',
      ),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Post post,
  required _Cache cache,
  required AppFileSystem fs,
  ShareActionAdapter? adapter,
  String profileName = 'My Danbooru',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        loggerProvider.overrideWithValue(AppLogger()),
        appFileSystemProvider.overrideWithValue(fs),
        defaultImageCacheManagerProvider.overrideWithValue(cache),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
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
        bypassDdosHeadersProvider.overrideWith((ref, url) => const {}),
        httpHeadersProvider.overrideWith((ref, config) => const {}),
        dioForWidgetProvider.overrideWith((ref, config) => Dio()),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: OKToast(child: TranslationProvider(child: child!)),
        ),
        home: Scaffold(
          body: UnifiedPostShareSheet(
            post: post,
            auth: _auth,
            profileName: profileName,
            viewer: _viewer,
            imageCacheManager: cache,
            shareAdapter: adapter,
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Links'));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

void main() {
  testWidgets('post Links exposes one file action, no raw or mixed share', (
    tester,
  ) async {
    final cache = _Cache();
    when(() => cache.generateCacheKey(any())).thenReturn('key');
    when(() => cache.getCachedFileBytes(any())).thenReturn(null);
    await _pump(tester, post: _post(), cache: cache, fs: MemoryAppFileSystem());
    expect(find.byKey(const ValueKey('share-bslink-file')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('share-bslink-file')),
        matching: find.byType(BoorusamaBoxIcon),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('share-bslink-image')), findsNothing);
    expect(find.byTooltip('Copy Boorusama Link'), findsNothing);
    expect(find.byTooltip('Share Image and Boorusama Link'), findsNothing);
    expect(find.textContaining('boorusama://'), findsNothing);
    expect(find.byTooltip('Copy Post Link'), findsOneWidget);
    expect(find.byTooltip('Share Booru Link'), findsOneWidget);
    expect(find.byTooltip('Copy Image Link'), findsOneWidget);
    expect(find.byTooltip('Copy Post ID'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final preview in ['https://site.test/sample.png', '']) {
    testWidgets('standalone post document needs no image: $preview', (
      tester,
    ) async {
      final cache = _Cache();
      when(() => cache.generateCacheKey(any())).thenReturn('key');
      when(() => cache.getCachedFileBytes(any())).thenReturn(null);
      final fs = MemoryAppFileSystem();
      final post = _post(preview: preview);
      var calls = 0;
      await _pump(
        tester,
        post: post,
        cache: cache,
        fs: fs,
        adapter: ShareActionAdapter((params) async {
          calls++;
          expect(params.files, hasLength(1));
          expect(params.uri, isNull);
          expect(params.text, 'Post 42 on My Danbooru');
          final attachment = params.files!.single;
          expect(attachment.mimeType, BoorusamaLinkFile.mimeType);
          expect(attachment.name, 'boorusama-post-42.bslink');
          expect(params.sharePositionOrigin!.width, greaterThan(0));
          expect(
            BoorusamaLinkFile.decode(await fs.readBytes(attachment.path)).uri,
            BoorusamaPostLink.fromPost(post, auth: _auth)!.uri,
          );
          return const ShareResult('', ShareResultStatus.success);
        }),
      );
      await tester.tap(find.byTooltip('Boorusama Link File'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(calls, 1);
      verifyNever(() => cache.acquireFile(any()));
      verifyNever(() => cache.beginFileWrite(any()));
      expect(find.textContaining('No image is available'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
