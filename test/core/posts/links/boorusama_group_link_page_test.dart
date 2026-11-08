import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/content/anonymous_access_provider.dart';
import 'package:boorusama/core/content/anonymous_read_scope.dart';
import 'package:boorusama/core/content/content_access.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/posts/details/src/widgets/mixed_post_details_page.dart';
import 'package:boorusama/core/posts/details/src/types/viewer_entry.dart';
import 'package:boorusama/core/posts/links/boorusama_group_link_page.dart';
import 'package:boorusama/core/posts/links/boorusama_link_file.dart';
import 'package:boorusama/core/router.dart';
import 'package:cache_manager/cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:mocktail/mocktail.dart';

import '../../../application/support/headless_app_harness.dart';
import 'boorusama_post_link_test.dart' show config;

class _Cache extends Mock implements ImageCacheManager {}

class _Profiles extends BooruConfigNotifier {
  _Profiles(List<BooruConfig> profiles) : super(initialConfigs: profiles);
  void replace(List<BooruConfig> profiles) => state = profiles;
}

const _customUri =
    'boorusama://group/open?v=1&engine=danbooru&site=http%3A%2F%2Fsite.test%3A8080%2Finstall&key=pool%3A42';

Future<GoRouter> _pumpLink(
  WidgetTester tester,
  _Profiles profiles, {
  String uri = _customUri,
  double textScale = 1,
  Widget Function(BuildContext, GoRouterState)? setup,
}) async {
  final router = GoRouter(
    initialLocation: uri,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Home')),
        routes: [
          GoRoute(
            path: 'open',
            builder: (_, state) =>
                BoorusamaGroupLinkPage(uri: state.uri.toString()),
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
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
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

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

void main() {
  final first = config('http://site.test:8080/install').copyWith(name: 'First');
  final second = config(
    'http://site.test:8080/install',
    id: '00000000-0000-4000-8000-000000000002',
  ).copyWith(name: 'Second');

  testWidgets('decoded Group file opens through the application router', (
    tester,
  ) async {
    final harness = await HeadlessAppHarness.mount(
      tester,
      additionalOverrides: [
        booruConfigProvider.overrideWith(() => _Profiles([])),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    final file = BoorusamaLinkFile.fromUri(_customUri);
    container
        .read(routerProvider)
        .go(BoorusamaLinkFile.decode(file.encode()).uri.toString());
    await harness.pumpUntilFound(tester, find.byType(BoorusamaGroupLinkPage));
    expect(find.text('Add Profile'), findsOneWidget);
    expect(find.byType(MixedPostDetailsPage), findsNothing);
  });

  testWidgets('selected profile is pinned to the Group entry', (tester) async {
    final profiles = _Profiles([first, second]);
    final harness = await HeadlessAppHarness.mount(
      tester,
      additionalOverrides: [
        booruConfigProvider.overrideWith(() => profiles),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container.read(routerProvider).go(_customUri);
    await harness.pumpUntilFound(tester, find.byType(BoorusamaGroupLinkPage));
    await harness.pumpUntilFound(
      tester,
      find.descendant(
        of: find.byType(BoorusamaGroupLinkPage),
        matching: find.text('Second'),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(BoorusamaGroupLinkPage),
        matching: find.text('Second'),
      ),
    );
    await harness.pumpUntilFound(tester, find.byType(MixedPostDetailsPage));
    GroupViewerEntry entry() =>
        tester
                .widget<MixedPostDetailsPage>(find.byType(MixedPostDetailsPage))
                .entries!
                .single
            as GroupViewerEntry;
    expect(entry().contentReference.sourceKey, 'pool:42');
    expect(entry().source!.config.id, second.id);
    profiles.replace([first]);
    await tester.pump();
    expect(entry().source!.resolve([first]), isNull);
  });

  testWidgets('public link stays public when a matching profile appears', (
    tester,
  ) async {
    const site = 'https://safebooru.donmai.us';
    const uri =
        'boorusama://group/open?v=1&engine=danbooru&site=https%3A%2F%2Fsafebooru.donmai.us&key=pool%3A42';
    final profiles = _Profiles([]);
    final publicConfig = config(site);
    final harness = await HeadlessAppHarness.mount(
      tester,
      additionalOverrides: [
        booruConfigProvider.overrideWith(() => profiles),
        anonymousContentAccessProvider.overrideWith((ref, source) {
          final key = ContentAccessKey(
            engine: BooruType.danbooru,
            siteNamespace: source.site.host,
            authEpoch: 1,
            policyEpoch: 1,
          );
          final scope = AnonymousReadScope(
            source: source,
            key: key,
            current: () => true,
            createDio: () => Dio(),
          );
          ref.onDispose(scope.dispose);
          return ContentAccessContext.anonymous(
            config: publicConfig.copyWith(anonymousReadScope: scope),
            scope: scope,
          );
        }),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container.read(routerProvider).go(uri);
    await harness.pumpUntilFound(tester, find.byType(MixedPostDetailsPage));
    GroupViewerEntry entry() =>
        tester
                .widget<MixedPostDetailsPage>(find.byType(MixedPostDetailsPage))
                .entries!
                .single
            as GroupViewerEntry;
    final binding = entry().source!;
    expect(binding.publicOrigin, isNotNull);
    profiles.replace([publicConfig]);
    await tester.pump();
    expect(entry().source, same(binding));
    expect(entry().source!.publicOrigin, isNotNull);
    expect(entry().source!.resolve([publicConfig]), isNull);
  });

  testWidgets('ambiguous source waits for explicit profile selection', (
    tester,
  ) async {
    await _pumpLink(tester, _Profiles([first, second]));
    await _settle(tester);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(MixedPostDetailsPage), findsNothing);
  });

  testWidgets(
    'unknown HTTP installation offers setup with the complete source',
    (tester) async {
      Uri? setupUri;
      await _pumpLink(
        tester,
        _Profiles([]),
        setup: (_, state) {
          setupUri = state.uri;
          return const Scaffold(body: Text('Setup'));
        },
      );
      await _settle(tester);
      expect(find.byType(MixedPostDetailsPage), findsNothing);
      await tester.tap(find.text('Add Profile'));
      await _settle(tester);
      expect(setupUri?.queryParameters['url'], 'http://site.test:8080/install');
      expect(setupUri?.queryParameters['setAsCurrent'], 'false');
    },
  );

  testWidgets('closing a root link safely returns home', (tester) async {
    await _pumpLink(tester, _Profiles([]));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.close));
    await _settle(tester);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('chooser remains usable at 320 dp and double text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpLink(
      tester,
      _Profiles([
        first.copyWith(name: 'A long account name used on a tiny screen'),
        second,
      ]),
      textScale: 2,
    );
    await _settle(tester);
    final target = find.byKey(ValueKey(second.id));
    await tester.scrollUntilVisible(target, 120);
    await _settle(tester);
    expect(target.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
