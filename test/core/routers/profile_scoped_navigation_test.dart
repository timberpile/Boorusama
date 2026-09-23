// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

// Project imports:
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/comments/routes.dart';
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/router.dart';
import 'package:boorusama/core/search/search/routes.dart';
import 'package:boorusama/boorus/danbooru/tags/related/providers.dart';
import 'package:boorusama/boorus/danbooru/tags/related/src/related_tag_repository.dart';
import 'package:boorusama/boorus/danbooru/tags/related/types.dart';

void main() {
  testWidgets('comment pages keep the profile that launched them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: CurrentBooruConfigScope(
            config: _globalConfig,
            child: MaterialApp(
              home: CurrentBooruConfigScope(
                config: _pageConfig,
                child: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showCommentPage<void>(
                        context,
                        config: _pageConfig,
                        builder: (_, _) => Consumer(
                          builder: (context, ref, _) => Text(
                            ref.watchConfig.url,
                          ),
                        ),
                      ),
                      child: const Text('Comments'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Comments'));
    await tester.pumpAndSettle();

    expect(find.text(_pageConfig.url), findsOneWidget);
    expect(find.text(_globalConfig.url), findsNothing);
  });

  testWidgets('search navigation carries the profile that launched it', (
    tester,
  ) async {
    BooruConfig? openedConfig;
    late final GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => CurrentBooruConfigScope(
            config: _pageConfig,
            child: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => goToSearchPage(ref, tag: 'test'),
                  child: const Text('Search'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) {
            openedConfig = state.extra as BooruConfig?;
            return const Scaffold(body: Text('Results'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(openedConfig, _pageConfig);
  });

  testWidgets('Danbooru search helpers use the profile scoped to the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          danbooruRelatedTagRepProvider(_pageConfig.auth).overrideWithValue(
            RelatedTagRepositoryBuilder(
              fetch: (_, {category, order, limit}) =>
                  Completer<DanbooruRelatedTag>().future,
            ),
          ),
        ],
        child: CurrentBooruConfigScope(
          config: _globalConfig,
          child: CurrentBooruConfigScope(
            config: _pageConfig,
            child: Consumer(
              builder: (context, ref, _) {
                ref.watch(danbooruRelatedTagProvider('test'));
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

final _globalConfig = BooruConfig.defaultConfig(
  booruType: BooruType.danbooru,
  url: 'https://global.example',
  customDownloadFileNameFormat: null,
);

final _pageConfig = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://page.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': 42,
});
