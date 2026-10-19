import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'dart:ui' as ui;

import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/navigation/destination_definition.dart';
import 'package:boorusama/core/navigation/destination_id.dart';
import 'package:boorusama/core/navigation/destination_router.dart';
import 'package:boorusama/core/navigation/navigation_catalog.dart';
import 'package:boorusama/core/navigation/profile_context_menu.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

const _captureStage = String.fromEnvironment('NAVIGATION_VISUAL_STAGE');

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureStage.isEmpty) return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/danbooru-logo.png'),
      tester.element(find.byKey(const Key('capture'))),
    ),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(
      'build/navigation-review/corrective/visuals/$_captureStage-$name.png',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    final file = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((p) => p['name'] == 'flutter');
    final root = file.absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../');
    for (final font in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(
            File.fromUri(
              root.resolve('bin/cache/artifacts/material_fonts/${font.$2}'),
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
    await (FontLoader('packages/material_symbols_icons/MaterialSymbolsOutlined')
          ..addFont(
            rootBundle.load(
              'packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
            ),
          ))
        .load();
    await ensureI18nInitialized('en-US');
  });
  testWidgets('safe sidebar review fixture', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const browse = DestinationId.browse('review');
    late final DestinationRouterBinding binding;
    final catalog = NavigationCatalog(
      eligibleFavoritesProfileIds: ['review'],
      globalEntries: [
        GlobalNavigationDefinition.sharedFavorites(
          label: (_) => 'Favorites',
          icon: Icons.favorite,
        ),
        for (final entry in [
          (AppDestination.blacklist, 'Blacklist', Icons.block),
          (AppDestination.favoriteTags, 'Favorite Tags', Icons.tag),
          (AppDestination.bulkDownload, 'Bulk Download', Icons.download),
          (
            AppDestination.downloadManager,
            'Download Manager',
            Icons.download_done,
          ),
          (AppDestination.settings, 'Settings', Icons.settings),
          (AppDestination.support, 'Get support', Icons.help_outline),
          (AppDestination.donate, 'Donate', Icons.favorite_outline),
        ])
          GlobalNavigationDefinition(
            destination: entry.$1,
            label: (_) => entry.$2,
            icon: entry.$3,
          ),
      ],
      profileSections: [
        ProfileNavigationSection(
          profileId: 'review',
          caption: 'Review profile',
          profileIcon: 'https://danbooru.donmai.us',
          rows: [
            SiteToolDefinition(
              toolId: 'danbooru.explore',
              label: (_) => 'Explore',
              icon: Icons.explore_outlined,
              availability: NavigationAvailability.available,
            ),
            SiteToolDefinition(
              toolId: 'danbooru.pools',
              label: (_) => 'Pools',
              icon: Icons.collections,
              availability: NavigationAvailability.available,
            ),
          ],
        ),
      ],
    );
    binding = DestinationRouterBinding(
      definitions: [
        DestinationRouteDefinition(
          id: browse,
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Review fixture'))),
        ),
      ],
      shellBuilder: (_, _, shell) => AppNavigationShell(
        navigationShell: shell,
        active: browse,
        catalog: catalog,
        browse: browse,
        collapsedProfiles: const {},
        onSelect: (_) async => true,
        onFavorites: () async => true,
        onToggleProfile: (_) {},
      ),
    );
    final router = GoRouter.routingConfig(
      routingConfig: binding.routingConfig,
      initialLocation: browse.location,
    );
    binding.attach(router);
    addTearDown(router.dispose);
    addTearDown(binding.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(Settings.defaultSettings),
        ],
        child: BooruLocalization(
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) =>
                RepaintBoundary(key: const Key('capture'), child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-menu-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Review profile'), findsOneWidget);
    await _capture(tester, 'sidebar');
    expect(tester.takeException(), isNull);
  });
  testWidgets('safe profile popup review fixture', (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (_, child) =>
              RepaintBoundary(key: const Key('capture'), child: child!),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Search'),
              actions: [
                ProfileContextMenuButton(
                  entries: const [
                    ProfileMenuEntry(
                      id: 'a',
                      caption: 'Art',
                      url: 'https://danbooru.donmai.us',
                    ),
                    ProfileMenuEntry(
                      id: 'b',
                      caption: 'Sketches',
                      url: 'https://danbooru.donmai.us',
                    ),
                    ProfileMenuEntry(
                      id: 'c',
                      caption: 'Illustrations',
                      url: 'https://danbooru.donmai.us',
                    ),
                  ],
                  selectedProfileId: 'a',
                  onSelected: (_) {},
                  tooltip: 'Profiles',
                ),
              ],
            ),
            body: const Center(child: Text('Review fixture')),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Profiles'));
    await tester.pumpAndSettle();
    await _capture(tester, 'profile-popup');
    expect(tester.takeException(), isNull);
  });
}
