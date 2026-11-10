import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/http/client/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/src/image/raw_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../posts/details/progressive_image_test_utils.dart' as helpers;

final _current = StateProvider<ContentAccessContext?>((ref) => null);

void main() {
  for (final custom in [false, true]) {
    testWidgets(
      'public Realbooru icon ${custom ? 'rejects an imported URL' : 'uses the existing cached site icon and revokes it'}',
      (tester) async {
        final source = const AnonymousSourcePolicy().resolve(
          BooruType.gelbooruV2,
          Uri.parse('https://realbooru.com'),
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
          createDio: () => throw StateError('No API client needed for an icon'),
          current: () => true,
        );
        addTearDown(scope.dispose);
        final config = BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': '11111111-1111-4111-8111-111111111111',
          'booruId': source.engine.id,
          'booruIdHint': source.engine.id,
          'url': source.site.toString(),
        }).copyWith(anonymousReadScope: scope);
        final icon = PostSource.from(source.site.toString()).whenWeb(
          (s) => s.faviconUrl,
          () => throw StateError('Expected web source'),
        );
        final cache = helpers.TestImageCache({icon: helpers.targetPng});
        final adapter = helpers.ControlledImageAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final container = ProviderContainer(
          overrides: [
            _current.overrideWith(
              (ref) =>
                  ContentAccessContext.anonymous(config: config, scope: scope),
            ),
            currentContentAccessKeyProvider.overrideWithValue(key),
            contentAccessRequiredProvider.overrideWithValue(true),
            contentAccessContextProvider.overrideWith(
              (ref, key) => ref.watch(_current),
            ),
            automaticMediaLoadingEnabledProvider.overrideWithValue(true),
            faviconDioProvider.overrideWithValue(dio),
            defaultImageCacheManagerProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: helpers.testApp(
              ConfigAwareWebsiteLogo.fromConfig(
                config.auth,
                customIconUrl: custom ? 'https://127.0.0.1/private.png' : null,
              ),
            ),
          ),
        );
        if (custom) {
          expect(find.byType(ExtendedRawImage), findsNothing);
        } else {
          await tester.runAsync(
            () => helpers.waitForPixel(tester, [0, 0, 255, 255]),
          );
          container.read(_current.notifier).state = null;
          await tester.pump();
          expect(find.byType(ExtendedRawImage), findsNothing);
        }
        expect(adapter.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
