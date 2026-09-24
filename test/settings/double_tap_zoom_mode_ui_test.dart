// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import 'package:boorusama/core/settings/src/pages/appearance/image_viewer_settings_section.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  testWidgets('offers both double-tap zoom behaviors and reports changes', (
    tester,
  ) async {
    DoubleTapZoomMode? updatedMode;

    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: DoubleTapZoomModeSetting(
                value: Settings.defaultSettings.viewer.doubleTapZoomMode,
                onChanged: (mode) => updatedMode = mode,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final selector = tester
        .widget<KurumiOptionDropDownButton<DoubleTapZoomMode>>(
          find.byType(KurumiOptionDropDownButton<DoubleTapZoomMode>),
        );

    expect(selector.value, DoubleTapZoomMode.fitCycle);
    expect(
      selector.items.map((item) => item.value),
      DoubleTapZoomMode.values,
    );

    selector.onChanged(DoubleTapZoomMode.classic);

    expect(updatedMode, DoubleTapZoomMode.classic);
  });
}
