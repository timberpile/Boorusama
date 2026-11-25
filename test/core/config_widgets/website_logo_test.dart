import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/developer_options/blocked_media_placeholder.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/widgets/website_logo.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:dio/dio.dart';

class _IconCache extends Fake implements ImageCacheManager {}

void main() {
  testWidgets('a public bookmark can use the existing source favicon service', (
    tester,
  ) async {
    final source = const AnonymousSourcePolicy().resolve(
      BooruType.danbooru,
      Uri.parse('https://safebooru.donmai.us'),
    )!;
    final key = ContentAccessKey(
      engine: source.engine,
      siteNamespace: source.site.host,
      authEpoch: 1,
      policyEpoch: 1,
    );
    final scope = AnonymousReadScope(
      source: source,
      key: key,
      createDio: () => throw StateError('Site transport used for a favicon'),
      current: () => true,
    );
    addTearDown(scope.dispose);
    final config = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000000',
      'booruId': source.engine.id,
      'booruIdHint': source.engine.id,
      'url': source.site.toString(),
    }).copyWith(anonymousReadScope: scope);
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAccessRequiredProvider.overrideWithValue(true),
          currentContentAccessKeyProvider.overrideWithValue(key),
          contentAccessContextProvider(key).overrideWithValue(
            ContentAccessContext.anonymous(config: config, scope: scope),
          ),
          faviconDioProvider.overrideWithValue(dio),
          defaultImageCacheManagerProvider.overrideWithValue(_IconCache()),
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
        ],
        child: const BooruLocalization(
          child: MaterialApp(
            home: ConfigAwareWebsiteLogo(
              url: 'https://www.pixiv.net/en/artworks/42',
            ),
          ),
        ),
      ),
    );
    // With automatic loads disabled, a permitted icon gets the normal media
    // placeholder. A rejected icon shows the generic globe immediately.
    expect(find.byType(BlockedMediaPlaceholder), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked source scopes do not probe or read imported favicons', (
    tester,
  ) async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentAccessRequiredProvider.overrideWithValue(true),
          defaultImageCacheManagerProvider.overrideWith(
            (ref) => throw StateError('No imported favicon cache access'),
          ),
        ],
        child: MaterialApp(
          home: WebsiteLogo(
            url: 'https://127.0.0.1/private/icon.png',
            dio: dio,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(WebsiteLogo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  final cases = [
    (
      type: BooruType.danbooru,
      input: 'danbooru.donmai.us',
      expected: 'https://danbooru.donmai.us',
    ),
    (
      type: BooruType.gelbooru,
      input: 'gelbooru.com',
      expected: 'https://gelbooru.com',
    ),
    (
      type: BooruType.gelbooru,
      input: 'https://gelbooru.com/',
      expected: 'https://gelbooru.com/',
    ),
    (
      type: BooruType.gelbooru,
      input: 'booru.local:8080',
      expected: 'https://booru.local:8080',
    ),
    (
      type: BooruType.gelbooru,
      input: '[::1]:8080',
      expected: 'https://[::1]:8080',
    ),
  ];

  for (final testCase in cases) {
    test('site logo resolves ${testCase.input} as a web source', () {
      final logo = ConfigAwareWebsiteLogo.fromBooruType(
        testCase.type,
        testCase.input,
      );

      expect(logo.url, testCase.expected);
    });
  }

  final assetCases = [
    (
      type: BooruType.danbooru,
      url: 'https://danbooru.donmai.us/',
      asset: 'assets/images/danbooru-logo.png',
    ),
    (
      type: BooruType.hydrus,
      url: 'http://127.0.0.1:45869/',
      asset: 'assets/images/hydrus-logo.png',
    ),
  ];

  for (final testCase in assetCases) {
    testWidgets('${testCase.type.displayName} keeps its bundled site icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ConfigAwareWebsiteLogo.fromBooruType(
              testCase.type,
              testCase.url,
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, testCase.asset);
    });
  }
}
