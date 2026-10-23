import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:booru_clients/generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';
import 'package:boorusama/core/configs/create/src/pages/add_booru_page.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/images/providers.dart';

import '../posts/details/progressive_image_test_utils.dart';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/create/src/types/quick_profile_site.dart';

void main() {
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final root = configFile.absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve('../../');
    await (FontLoader('Roboto')..addFont(
          File.fromUri(
            root.resolve(
              'bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  final sites = QuickProfileSiteCatalog.fromBoorus([
    for (final config in BooruYamlConfigs.values) BooruScaffold(config: config),
  ]);

  testWidgets(
    'actual registry preset is selectable in a narrow enlarged picker',
    (tester) async {
      await ensureI18nInitialized('en-US');
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      QuickProfileSite? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            automaticMediaLoadingEnabledProvider.overrideWithValue(false),
            defaultImageCacheManagerProvider.overrideWithValue(
              TestImageCache({}),
            ),
          ],
          child: BooruLocalization(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: QuickProfileSetupPicker(
                  sites: sites,
                  onSelected: (site) => selected = site,
                  onCustomSite: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final tile = find.text('Safebooru (Danbooru)');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(tile);
      expect(selected!.toEditId().url, 'https://safebooru.donmai.us/');
      expect(selected!.toEditId().initialName, 'Safebooru (Danbooru)');
      expect(selected!.authentication, QuickProfileAuthentication.optional);
      expect(tester.takeException(), isNull);
    },
  );

  test('registered Safebooru Danbooru preset prepopulates optional setup', () {
    final site = sites.singleWhere(
      (site) => site.url == 'https://safebooru.donmai.us/',
    );

    expect(site.booruType, BooruType.danbooru);
    expect(site.profileName, 'Safebooru (Danbooru)');
    expect(site.authentication, QuickProfileAuthentication.optional);
    final id = site.toEditId();
    expect(id.booruType, BooruType.danbooru);
    expect(id.url, 'https://safebooru.donmai.us/');
    expect(id.initialName, 'Safebooru (Danbooru)');
  });

  test('keeps Danbooru and Gelbooru Safebooru as distinct presets', () {
    final danbooru = sites.singleWhere(
      (site) => site.url == 'https://danbooru.donmai.us/',
    );
    final safebooru = sites.singleWhere(
      (site) => site.url == 'https://safebooru.org/',
    );

    expect(danbooru.profileName, 'Danbooru');
    expect(danbooru.booruType, BooruType.danbooru);
    expect(safebooru.profileName, 'Safebooru');
    expect(safebooru.booruType, BooruType.gelbooruV2);
    expect(sites.map((site) => site.url).toSet().length, sites.length);
  });
}
