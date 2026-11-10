import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/anonymous_source_policy.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/content_media_access.dart';
import 'package:boorusama/core/posts/details_parts/src/toolbars/download_post_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  testWidgets(
    'bound download button rejects a newly excluded Post before reading download providers',
    (tester) async {
      final config = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': '11111111-1111-4111-8111-111111111111',
        'booruId': BooruType.danbooru.id,
        'booruIdHint': BooruType.danbooru.id,
        'url': 'https://safebooru.donmai.us',
        'ratingFilter': BooruConfigRatingFilter.custom.index,
        'granularRatingFilterString': 'g',
      });
      final access = ContentAccessContext.profile(
        config: config,
        authEpoch: 1,
        policyEpoch: 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentReadOnlyBooruConfigAuthProvider.overrideWithValue(
              config.auth,
            ),
            currentContentAccessKeyProvider.overrideWithValue(access.key),
            contentAccessContextProvider.overrideWith((ref, key) => access),
            contentEffectiveBlacklistProvider.overrideWith(
              (ref, id) => const AsyncData(<String>{}),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: DownloadPostButton(post: TestPost(id: 91))),
          ),
        ),
      );
      expect(find.byType(IconButton), findsNothing);
      expect(find.byTooltip('Download'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public download button is omitted before download providers', (
    tester,
  ) async {
    final source = const AnonymousSourcePolicy().resolve(
      BooruType.danbooru,
      Uri.parse('https://safebooru.donmai.us'),
    )!;
    final scope = AnonymousReadScope(
      source: source,
      key: ContentAccessKey(
        engine: source.engine,
        siteNamespace: source.site.host,
        authEpoch: 1,
        policyEpoch: 1,
      ),
      current: () => true,
      createDio: () => throw StateError('Must not create an HTTP client'),
    );
    addTearDown(scope.dispose);

    final config = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000000',
      'booruId': source.engine.id,
      'booruIdHint': source.engine.id,
      'url': source.site.toString(),
      'login': null,
      'apiKey': null,
      'passHash': null,
      'proxySettings': null,
      'networkSettings': null,
    }).copyWith(anonymousReadScope: scope);
    final auth = BooruConfigAuth.fromConfig(config);
    final post = TestPost(id: 91);
    final container = ProviderContainer(
      overrides: [
        currentReadOnlyBooruConfigAuthProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: DownloadPostButton(post: post),
          ),
        ),
      ),
    );

    expect(find.byType(IconButton), findsNothing);
    expect(find.byTooltip('Download'), findsNothing);
  });
}
