import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/downloads/urls/providers.dart';
import 'package:boorusama/core/posts/details/providers.dart';
import 'package:boorusama/core/posts/details/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/shares/src/share_action_adapter.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/core/posts/shares/src/share_payload_tile.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:share_plus/share_plus.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

import '../../../bulk_downloads/common.dart';

void main() {
  testWidgets('unavailable link result stays distinct from dismissal', (
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
    final post = dummyPost(
      id: 42,
      sampleImageUrl: 'https://site.test/sample.jpg',
      originalImageUrl: 'https://site.test/full.jpg',
      source: PostSource.from('https://creator.test/art/42'),
    );
    final calls = <ShareParams>[];
    final adapter = ShareActionAdapter((params) async {
      calls.add(params);
      return ShareResult.unavailable;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
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
              profileIconUrl: 'https://icons.test/custom.png',
              post: post,
              auth: auth,
              viewer: viewer,
              imageCacheManager: DefaultImageCacheManager(),
              shareAdapter: adapter,
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Copy image'), findsOneWidget);
    expect(find.byTooltip('Share image'), findsOneWidget);
    expect(find.byTooltip('Copy original'), findsOneWidget);
    expect(find.text('https://site.test/sample.jpg'), findsNothing);
    expect(find.text('https://site.test/full.jpg'), findsNothing);
    expect(find.text('full.jpg'), findsNothing);
    expect(
      tester
          .widgetList<SharePayloadTile>(find.byType(SharePayloadTile))
          .every((tile) => tile.leading != null),
      isTrue,
    );
    expect(find.byTooltip('Share original'), findsOneWidget);
    expect(find.byTooltip('Copy file name'), findsNothing);
    expect(find.byTooltip('Share file name'), findsNothing);
    expect(find.text('Prepared when selected'), findsNothing);

    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Share booru link'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sharing could not be confirmed. Check the opened app or try another target.',
      ),
      findsOneWidget,
    );

    expect(find.byTooltip('Copy post ID'), findsOneWidget);
    expect(find.byTooltip('Share post ID'), findsOneWidget);
    expect(find.byTooltip('Copy source link'), findsOneWidget);
    expect(find.byTooltip('Share source link'), findsOneWidget);
    expect(find.text('https://site.test/posts/42'), findsOneWidget);
    expect(
      tester
          .widgetList<SharePayloadTile>(find.byType(SharePayloadTile))
          .every((tile) => tile.leading != null),
      isTrue,
    );
    final logos = tester.widgetList<ConfigAwareWebsiteLogo>(
      find.byType(ConfigAwareWebsiteLogo),
    );
    expect(
      logos.any((logo) => logo.url == 'https://creator.test/art/42'),
      isTrue,
    );
    expect(
      logos.any(
        (logo) =>
            logo.url == 'https://site.test' &&
            logo.customIconUrl == 'https://icons.test/custom.png',
      ),
      isTrue,
    );
    expect(calls.single.uri, Uri.parse('https://site.test/posts/42'));

    await tester.tap(find.byTooltip('Share post ID'));
    await tester.pumpAndSettle();
    expect(calls.last.text, '42');
    expect(calls.last.uri, isNull);
  });
}
