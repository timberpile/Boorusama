import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link_page.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link.dart';
import 'package:boorusama/core/posts/links/boorusama_search_link_page.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:kurumi/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';

import 'boorusama_post_link_test.dart' show config;

class _Cache extends Mock implements ImageCacheManager {}

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

BoorusamaSearchLink address(String query) => BoorusamaSearchLink.fromRaw(
  auth: config('https://site.test').auth,
  query: query,
)!;

Future<GoRouter> _pumpSearchLink(
  WidgetTester tester, {
  required _Profiles profiles,
  String? initialUri,
  Widget Function(BuildContext, GoRouterState)? setup,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: initialUri ?? address('one_piece').uri.toString(),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'open',
            builder: (context, state) {
              if (state.uri.host == 'search') {
                return BoorusamaSearchLinkPage(
                  key: ValueKey(state.uri.toString()),
                  uri: state.uri.toString(),
                  searchBuilder: (_, params, profile) => Scaffold(
                    body: Text(
                      'Search ${params.query ?? params.tags?.list.join(',')} with ${profile.name}',
                    ),
                  ),
                );
              }
              return BoorusamaPostLinkPage(
                uri: state.uri.toString(),
                postBuilder: (_, post, profile) => Scaffold(
                  body: Text('Post ${post.id} with ${profile.name}'),
                ),
              );
            },
          ),
          GoRoute(
            path: 'boorus/add',
            builder: setup ?? (_, _) => const SizedBox(),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        booruConfigProvider.overrideWith(() => profiles),
        defaultImageCacheManagerProvider.overrideWithValue(_Cache()),
        automaticMediaLoadingEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: TranslationProvider(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
          ),
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  final first = config('https://site.test').copyWith(name: 'First');
  final second = config(
    'https://site.test',
    id: '00000000-0000-4000-8000-000000000002',
  ).copyWith(name: 'Second');

  testWidgets('cold search link opens with the one matching local profile', (
    tester,
  ) async {
    await _pumpSearchLink(tester, profiles: _Profiles([first]));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Search one_piece with First'), findsOneWidget);
  });

  testWidgets('typed searches preserve tag structure when opening', (
    tester,
  ) async {
    final url = BoorusamaSearchLink.fromTags(
      auth: first.auth,
      tags: ['one_piece', '-rating:s'],
    )!.uri.toString();
    await _pumpSearchLink(
      tester,
      profiles: _Profiles([first]),
      initialUri: url,
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Search one_piece,-rating:s with First'), findsOneWidget);
  });

  testWidgets('different sites and engines are excluded, account is explicit', (
    tester,
  ) async {
    await _pumpSearchLink(
      tester,
      profiles: _Profiles([
        first,
        second,
        config('https://another.test'),
        config('https://site.test', type: BooruType.moebooru),
      ]),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Search one_piece with First'), findsNothing);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Search one_piece with Second'), findsOneWidget);
  });

  testWidgets('missing profile offers setup and resumes unchanged query', (
    tester,
  ) async {
    final profiles = _Profiles([]);
    Uri? setupUri;
    await _pumpSearchLink(
      tester,
      profiles: profiles,
      setup: (context, state) {
        setupUri = state.uri;
        return Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => profiles.replace([first]),
                child: const Text('Create'),
              ),
              TextButton(
                onPressed: () => GoRouter.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      },
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.text('Add Profile'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(setupUri?.queryParameters['url'], 'https://site.test');
    expect(setupUri?.queryParameters['setAsCurrent'], 'false');
    expect(
      setupUri?.queryParameters['type'],
      first.auth.booruType.id.toString(),
    );
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.textContaining('Search one_piece'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Search one_piece with First'), findsOneWidget);
  });

  testWidgets('invalid links never render search results', (tester) async {
    await _pumpSearchLink(
      tester,
      profiles: _Profiles([first]),
      initialUri: address('one_piece').uri
          .replace(
            queryParameters: {
              ...address('one_piece').uri.queryParameters,
              'v': '999',
            },
          )
          .toString(),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(
      find.textContaining('invalid or is not supported'),
      findsOneWidget,
    );
    expect(find.textContaining('Search one_piece'), findsNothing);
  });

  testWidgets('warm incoming link supersedes the previous query', (
    tester,
  ) async {
    await _pumpSearchLink(tester, profiles: _Profiles([first]));
    final acknowledged = Completer<void>();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      const JSONMethodCodec().encodeMethodCall(
        MethodCall(
          'pushRouteInformation',
          {'location': address('new_query').uri.toString()},
        ),
      ),
      (_) => acknowledged.complete(),
    );
    await acknowledged.future;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Search new_query with First'), findsOneWidget);
    expect(find.text('Search one_piece with First'), findsNothing);
  });

  testWidgets('profile selection fits a narrow display and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSearchLink(
      tester,
      profiles: _Profiles([
        first.copyWith(name: 'A long account name used on a tiny screen'),
        second,
      ]),
      textScale: 2,
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    final target = find.byKey(ValueKey(second.id));
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(target.hitTestable());
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Search one_piece with Second'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
