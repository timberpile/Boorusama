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
import 'package:boorusama/boorus/szurubooru/comments/src/routes/route_utils.dart';
import 'package:boorusama/boorus/szurubooru/pools/routes.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';

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

  testWidgets(
    'Szurubooru comment editors carry the profile that launched them',
    (
      tester,
    ) async {
      BooruConfig? openedConfig;
      late final GoRouter router;
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => CurrentBooruConfigScope(
              config: _szurubooruPageConfig,
              child: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: TextButton(
                    onPressed: () => goToSzurubooruCommentCreatePage(
                      ref,
                      postId: 1,
                    ),
                    child: const Text('Comment'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/internal/szurubooru/posts/:id/comments/editor',
            builder: (context, state) {
              openedConfig = state.extra as BooruConfig?;
              return const Scaffold(body: Text('Editor'));
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
      await tester.tap(find.text('Comment'));
      await tester.pumpAndSettle();

      expect(openedConfig, _szurubooruPageConfig);
    },
  );

  testWidgets('Szurubooru pool details carry the profile that launched them', (
    tester,
  ) async {
    BooruConfig? openedConfig;
    late final GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => CurrentBooruConfigScope(
            config: _szurubooruPageConfig,
            child: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => goToSzurubooruPoolDetailPage(ref, _pool),
                  child: const Text('Pool'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/szurubooru/pools/:id',
          builder: (context, state) {
            final extra =
                state.extra! as ({SzurubooruPool pool, BooruConfig config});
            openedConfig = extra.config;
            return const Scaffold(body: Text('Pool details'));
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
    await tester.tap(find.text('Pool'));
    await tester.pumpAndSettle();

    expect(openedConfig, _szurubooruPageConfig);
  });
}

const _pool = SzurubooruPool(
  id: 7,
  names: ['pool'],
  category: null,
  description: null,
  postCount: 0,
  postIds: [],
  thumbnailUrls: [],
  createdAt: null,
  updatedAt: null,
);

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

final _szurubooruPageConfig = BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.szurubooru,
    url: 'https://szurubooru.example',
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': 43,
});
