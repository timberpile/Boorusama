import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cache_manager/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/create/src/pages/add_booru_page.dart';
import 'package:boorusama/core/configs/create/src/pages/create_booru_config_scaffold.dart';
import 'package:boorusama/core/configs/create/providers.dart';
import 'package:boorusama/core/configs/create/src/types/quick_profile_site.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/providers.dart';

void main() {
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterRoot = configFile.absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../');
    final font = FontLoader('Roboto')
      ..addFont(
        File.fromUri(
          flutterRoot.resolve(
            'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
          ),
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
    await ensureI18nInitialized('en-US');
  });

  testWidgets(
    'shows only required account status and returns the selected site',
    (
      tester,
    ) async {
      QuickProfileSite? selected;
      final sites = _sites();

      await tester.pumpWidget(
        _TestApp(
          child: QuickProfileSetupPicker(
            sites: sites,
            onSelected: (site) => selected = site,
            onCustomSite: () {},
          ),
        ),
      );

      expect(find.text('Account required'), findsOneWidget);
      expect(find.text('Account optional'), findsNothing);
      expect(find.text('No account needed'), findsNothing);
      expect(find.text('rule34.xxx'), findsNothing);
      expect(find.text('danbooru.donmai.us'), findsNothing);
      expect(find.text('nozomi.la'), findsNothing);

      await tester.tap(find.text('Rule34'));
      expect(selected, sites.first);
    },
  );

  testWidgets('keeps the required badge on the site name row', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: QuickProfileSetupPicker(
          sites: _sites(),
          onSelected: (_) {},
          onCustomSite: () {},
        ),
      ),
    );

    final requiredBadge = find.byKey(
      const ValueKey('quick-profile-auth-required-https://rule34.xxx/'),
    );
    final requiredTile = find.byKey(
      const ValueKey('quick-profile-https://rule34.xxx/'),
    );
    final optionalTile = find.byKey(
      const ValueKey('quick-profile-https://danbooru.donmai.us/'),
    );
    final unnecessaryTile = find.byKey(
      const ValueKey('quick-profile-https://nozomi.la/'),
    );

    expect(requiredBadge, findsOneWidget);
    expect(
      tester.getCenter(requiredBadge).dy,
      closeTo(tester.getCenter(find.text('Rule34')).dy, 1),
    );
    expect(
      tester.getSize(requiredTile).height,
      tester.getSize(optionalTile).height,
    );
    expect(
      tester.getSize(requiredTile).height,
      tester.getSize(unnecessaryTile).height,
    );
    expect(
      tester.getSemantics(requiredBadge).getSemanticsData().label,
      contains('Account required'),
    );
    final chevron = find.descendant(
      of: requiredTile,
      matching: find.byType(Icon),
    );
    expect(
      tester.getRect(requiredBadge).right,
      closeTo(tester.getRect(chevron).left - 8, 1),
    );
  });

  testWidgets('keeps custom URL setup reachable from the picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: AddBooruPageInternal(
          setCurrentBooruOnSubmit: false,
          quickSetupSites: _sites(),
        ),
      ),
    );

    await tester.tap(find.text('Set up a custom site'));
    await tester.pump();

    expect(find.text('Site URL'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('places custom profile setup at the top of the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: SizedBox.expand(
          child: AddBooruPageInternal(
            setCurrentBooruOnSubmit: false,
            quickSetupSites: _sites(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Set up a custom site'));
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Create a new profile')).dy,
      lessThan(100),
    );
  });

  testWidgets('uses the selected site name as the initial profile name', (
    tester,
  ) async {
    final id = _sites().first.toEditId();

    await tester.pumpWidget(
      _TestApp(
        child: CreateBooruConfigScope(
          id: id,
          config: BooruConfig.defaultConfig(
            booruType: id.booruType,
            url: id.url,
            customDownloadFileNameFormat: null,
          ),
          child: Consumer(
            builder: (context, ref, _) => Text(
              ref.watch(initialBooruConfigProvider).name,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Rule34'), findsOneWidget);
  });

  testWidgets('builds logos only for visible site rows', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sites = List.generate(
      30,
      (index) => QuickProfileSite(
        booruType: BooruType.danbooru,
        url: 'https://site$index.donmai.us/',
        profileName: 'Site $index',
        authentication: QuickProfileAuthentication.optional,
      ),
    );

    await tester.pumpWidget(
      _TestApp(
        child: QuickProfileSetupPicker(
          sites: sites,
          onSelected: (_) {},
          onCustomSite: () {},
        ),
      ),
    );

    expect(find.byType(ConfigAwareWebsiteLogo).evaluate().length, lessThan(30));
    expect(find.text('Site 29'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Site 29'),
      400,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Site 29'), findsOneWidget);
  });

  for (final width in [240.0, 320.0]) {
    testWidgets(
      'fits a long site name and required badge at large text at $width pixels',
      (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longName = 'A very long booru site name that must not collide';
        const url = 'https://long-name.example/';

        await tester.pumpWidget(
          _TestApp(
            textScaler: const TextScaler.linear(2),
            child: QuickProfileSetupPicker(
              sites: const [
                QuickProfileSite(
                  booruType: BooruType.danbooru,
                  url: url,
                  profileName: longName,
                  authentication: QuickProfileAuthentication.required,
                ),
              ],
              onSelected: (_) {},
              onCustomSite: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final requiredBadge = find.byKey(
          const ValueKey('quick-profile-auth-required-$url'),
        );
        expect(requiredBadge, findsOneWidget);
        expect(
          tester.getRect(find.text(longName)).right,
          lessThan(tester.getRect(requiredBadge).left),
        );
        expect(
          tester.getCenter(requiredBadge).dy,
          closeTo(tester.getCenter(find.text(longName)).dy, 1),
        );
        final semantics = tester
            .getSemantics(find.byKey(const ValueKey('quick-profile-$url')))
            .getSemanticsData();
        expect(semantics.hasAction(SemanticsAction.tap), isTrue);
        expect(semantics.label, contains(longName));
        expect(semantics.label, contains('Account required'));
      },
    );
  }

  for (final c in [
    (locale: 'en-US', label: 'Account required'),
    (locale: 'de-DE', label: 'Benutzerkonto erforderlich'),
  ]) {
    testWidgets(
      'keeps the badge compact at 320 pixels and double text in ${c.locale}',
      (tester) async {
        await tester.runAsync(() => ensureI18nInitialized(c.locale));
        addTearDown(() => ensureI18nInitialized('en-US'));
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const site = QuickProfileSite(
          booruType: BooruType.gelbooruV2,
          url: 'https://gelbooru.com/',
          profileName: 'Gelbooru',
          authentication: QuickProfileAuthentication.required,
        );
        await tester.pumpWidget(
          _TestApp(
            textScaler: const TextScaler.linear(2),
            child: QuickProfileSetupPicker(
              sites: const [site],
              onSelected: (_) {},
              onCustomSite: () {},
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final badge = find.byKey(
          const ValueKey('quick-profile-auth-required-https://gelbooru.com/'),
        );
        expect(tester.getSize(badge).height, lessThanOrEqualTo(48));
        expect(
          tester.getSize(find.text('Gelbooru')).width,
          greaterThanOrEqualTo(100),
        );
        final label = find.text(c.label);
        expect(label, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final lines = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: c.label.length),
        );
        expect(
          lines.map((box) => box.top).toSet().length,
          lessThanOrEqualTo(2),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        final semantics = tester
            .getSemantics(
              find.byKey(const ValueKey('quick-profile-https://gelbooru.com/')),
            )
            .getSemanticsData();
        expect(semantics.label, contains('Gelbooru'));
        expect(semantics.label, contains(c.label));
        expect(semantics.hasAction(SemanticsAction.tap), isTrue);
      },
    );
  }
}

List<QuickProfileSite> _sites() => const [
  QuickProfileSite(
    booruType: BooruType.gelbooruV2,
    url: 'https://rule34.xxx/',
    profileName: 'Rule34',
    authentication: QuickProfileAuthentication.required,
  ),
  QuickProfileSite(
    booruType: BooruType.danbooru,
    url: 'https://danbooru.donmai.us/',
    profileName: 'Danbooru',
    authentication: QuickProfileAuthentication.optional,
  ),
  QuickProfileSite(
    booruType: BooruType.nozomi,
    url: 'https://nozomi.la/',
    profileName: 'Nozomi.la',
    authentication: QuickProfileAuthentication.unnecessary,
  ),
];

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.textScaler});

  final Widget child;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    return BooruLocalization(
      child: ProviderScope(
        overrides: [
          automaticMediaLoadingEnabledProvider.overrideWithValue(false),
          defaultImageCacheManagerProvider.overrideWithValue(_NoImageCache()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
  }
}

class _NoImageCache implements ImageCacheManager {
  @override
  FutureOr<String?> getCachedFilePath(String key, {Duration? maxAge}) => null;

  @override
  FutureOr<Uint8List?> getCachedFileBytes(String key, {Duration? maxAge}) =>
      null;

  @override
  String generateCacheKey(String url, {String? customKey}) => url;

  @override
  Future<void> saveFile(String key, Uint8List bytes) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
