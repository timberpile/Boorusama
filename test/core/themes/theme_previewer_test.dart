// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/configs/appearance/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/configs/types.dart';
import 'package:boorusama/core/themes/viewers/src/providers/theme_previewer_notifier.dart';
import 'package:boorusama/core/themes/viewers/src/widgets/theme_previewer_sheet.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  testWidgets('theme tiles paint on the visible sheet material', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(Settings.defaultSettings),
          dynamicColorSupportProvider.overrideWithValue(false),
          themePreviewerProvider.overrideWith(
            () => ThemePreviewerNotifier(
              initialColors: ColorSettings.fromBasicScheme(
                'boorusama_black',
                nickname: 'Midnight',
              ),
              updateMethod: ThemeUpdateMethod.applyDirectly,
              onThemeUpdated: (_) {},
              onExit: () {},
              light: null,
              dark: null,
              systemDarkMode: true,
            ),
          ),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: const Scaffold(
              body: SizedBox.expand(
                child: ThemePreviewerSheet(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final opaqueDecorationsBeforeMaterial = <DecoratedBox>[];
    tester.element(find.byType(SwitchListTile).first).visitAncestorElements((
      element,
    ) {
      if (element.widget is Material) return false;

      if (element.widget case final DecoratedBox box) {
        final color = switch (box.decoration) {
          final BoxDecoration decoration => decoration.color,
          _ => null,
        };
        if (color != null && color.a > 0) {
          opaqueDecorationsBeforeMaterial.add(box);
        }
      }

      return true;
    });

    expect(opaqueDecorationsBeforeMaterial, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
