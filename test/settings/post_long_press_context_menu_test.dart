import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/settings/src/pages/appearance/image_listing_settings_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  test('old or malformed settings retain direct selection by default', () {
    for (final stored in [null, false, 'true', 1]) {
      final json = Settings.defaultSettings.toJson()
        ..remove('postLongPressContextMenu');
      if (stored != null) json['postLongPressContextMenu'] = stored;
      expect(Settings.fromJson(json).postLongPressContextMenu, isFalse);
    }
  });

  test('the comparison preference persists through serialization and other updates', () {
    final settings = Settings.defaultSettings
        .copyWith(postLongPressContextMenu: true)
        .copyWith(reduceAnimations: true);
    expect(
      Settings.fromJson(settings.toJson()).postLongPressContextMenu,
      isTrue,
    );
    expect(
      Settings.fromJson(
        settings.copyWith(postLongPressContextMenu: false).toJson(),
      ).postLongPressContextMenu,
      isFalse,
    );
  });

  testWidgets(
    'comparison switch toggles both ways at narrow width and enlarged text',
    (tester) async {
      await ensureI18nInitialized('en-US');
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var value = false;
      await tester.pumpWidget(
        BooruLocalization(
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
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) =>
                      PostLongPressContextMenuSetting(
                        value: value,
                        onChanged: (next) => setState(() => value = next),
                      ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(KurumiSwitchListTile));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      await tester.tap(find.byType(KurumiSwitchListTile));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
