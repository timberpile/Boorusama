// Flutter imports:
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

  testWidgets('retired zoom selector is absent from image viewer settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ImageViewerSettingsSection(
                  viewer: Settings.defaultSettings.viewer,
                  onUpdate: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ImageViewerSettingsSection));
    expect(
      find.text(context.t.settings.image_viewer.double_tap_zoom_behavior),
      findsNothing,
    );
    expect(
      find.text(context.t.settings.image_viewer.snap_zoom_to_fit),
      findsOneWidget,
    );
  });
}
