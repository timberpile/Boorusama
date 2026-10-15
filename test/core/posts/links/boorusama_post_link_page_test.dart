import 'dart:async';

import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link.dart';
import 'package:boorusama/core/posts/links/boorusama_post_link_page.dart';
import 'package:boorusama/core/posts/links/linked_post_provider.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:mocktail/mocktail.dart';

import '../../../bulk_downloads/common.dart';
import 'boorusama_post_link_test.dart' show config;

class _Cache extends Mock implements ImageCacheManager {}

typedef Request = (BoorusamaPostLink, BooruConfig);

BoorusamaPostLink address(int id) => BoorusamaPostLink.parse(
  Uri(
    scheme: 'boorusama',
    host: 'post',
    path: '/open',
    queryParameters: {
      'v': '1',
      'engine': 'danbooru',
      'site': 'https://site.test',
      'key': 'id:$id',
    },
  ).toString(),
);

class Profiles extends BooruConfigNotifier {
  Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

Future<GoRouter> pumpLink(
  WidgetTester tester, {
  required Profiles profiles,
  required Future<Post?> Function(Request) fetch,
  String? uri,
  Widget Function(BuildContext, GoRouterState)? setup,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: uri ?? address(42).uri.toString(),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'open',
            builder: (context, state) => BoorusamaPostLinkPage(
              uri: state.uri.toString(),
              key: ValueKey(state.uri.toString()),
              postBuilder: (_, post, profile) => Scaffold(
                body: Text('Opened ${post.id} with ${profile.name}'),
              ),
            ),
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
        linkedPostProvider.overrideWith((ref, request) => fetch(request)),
      ],
      child: MaterialApp.router(
        theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: TranslationProvider(
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
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
  ).copyWith(name: 'Second', login: 'second-account');

  testWidgets('cold route automatically uses one matching recipient profile', (
    tester,
  ) async {
    final calls = <Request>[];
    await pumpLink(
      tester,
      profiles: Profiles([first]),
      fetch: (request) async {
        calls.add(request);
        return dummyPost(id: 42);
      },
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Opened 42 with First'), findsOneWidget);
    expect(calls, [(address(42), first)]);
  });

  testWidgets('multiple profiles require a choice and exclude other sites', (
    tester,
  ) async {
    final calls = <Request>[];
    await pumpLink(
      tester,
      profiles: Profiles([
        first,
        second,
        config('https://other.test').copyWith(name: 'Unrelated'),
      ]),
      fetch: (request) async {
        calls.add(request);
        return dummyPost(id: 42);
      },
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(calls, isEmpty);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('second-account'), findsOneWidget);
    expect(find.text('Unrelated'), findsNothing);
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(calls.single.$2, second);
    expect(find.text('Opened 42 with Second'), findsOneWidget);
  });

  testWidgets(
    'setup resumes the pending post only after the setup route closes',
    (tester) async {
      final profiles = Profiles([]);
      final calls = <Request>[];
      Uri? setupUri;
      await pumpLink(
        tester,
        profiles: profiles,
        fetch: (request) async {
          calls.add(request);
          return dummyPost(id: 42);
        },
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
      expect(calls, isEmpty);
      expect(find.text('Add Profile'), findsOneWidget);
      await tester.tap(find.text('Add Profile'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(setupUri!.queryParameters['url'], 'https://site.test');
      expect(setupUri!.queryParameters['setAsCurrent'], 'false');
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(
        calls,
        isEmpty,
        reason: 'Do not load behind a still-open profile editor',
      );
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('Opened 42 with First'), findsOneWidget);
      expect(calls, hasLength(1));
    },
  );

  testWidgets('cancelling setup does not create, fetch or reopen setup', (
    tester,
  ) async {
    final calls = <Request>[];
    await pumpLink(
      tester,
      profiles: Profiles([]),
      fetch: (request) async {
        calls.add(request);
        return null;
      },
      setup: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () => GoRouter.of(context).pop(),
          child: const Text('Cancel setup'),
        ),
      ),
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
    await tester.tap(find.text('Cancel setup'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Add Profile'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a warm platform link supersedes a pending cold-start fetch', (
    tester,
  ) async {
    final pending = <int, Completer<Post?>>{};
    await pumpLink(
      tester,
      profiles: Profiles([first]),
      fetch: (request) {
        final id = (request.$1.postId as NumericPostId).value;
        return (pending[id] = Completer<Post?>()).future;
      },
    );
    expect(pending.keys, [42]);
    final acknowledged = Completer<void>();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      const JSONMethodCodec().encodeMethodCall(
        MethodCall(
          'pushRouteInformation',
          {'location': address(43).uri.toString()},
        ),
      ),
      (_) => acknowledged.complete(),
    );
    await acknowledged.future;
    await tester.pump();
    expect(pending.keys, [42, 43]);
    pending[42]!.complete(dummyPost(id: 42));
    await tester.pump();
    expect(find.text('Opened 42 with First'), findsNothing);
    pending[43]!.complete(dummyPost(id: 43));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Opened 43 with First'), findsOneWidget);
  });

  testWidgets('invalid references never reach a repository', (tester) async {
    var calls = 0;
    final uri = address(42).uri;
    await pumpLink(
      tester,
      profiles: Profiles([first]),
      uri: uri
          .replace(queryParameters: {...uri.queryParameters, 'v': '999'})
          .toString(),
      fetch: (_) async {
        calls++;
        return null;
      },
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(
      find.text(
        'This link is invalid or is not supported by this version of Boorusama.',
      ),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets('failed fetch can retry or choose a different matching account', (
    tester,
  ) async {
    var calls = 0;
    await pumpLink(
      tester,
      profiles: Profiles([first, second]),
      fetch: (request) async {
        calls++;
        if (request.$2 == first) {
          throw ServerError(
            httpStatusCode: 403,
            message: 'must-not-be-displayed',
          );
        }
        return dummyPost(id: 42);
      },
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.textContaining('must-not-be-displayed'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(calls, 2);
    await tester.tap(find.text('Choose another profile'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Opened 42 with Second'), findsOneWidget);
  });

  testWidgets('profile choice fits narrow width with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLink(
      tester,
      profiles: Profiles([
        first.copyWith(
          name: 'First account with a deliberately long display name',
        ),
        second,
      ]),
      textScale: 2,
      fetch: (_) async => null,
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Second'));
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
