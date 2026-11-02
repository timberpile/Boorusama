import 'package:boorusama/core/settings/src/pages/appearance/image_viewer_settings_section.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'viewer settings retain zoom controls without a swipe mode, scale=$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var viewer = Settings.defaultSettings.viewer;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: BooruLocalization(child: child!),
                ),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) => ImageViewerSettingsSection(
                      viewer: viewer,
                      onUpdate: (update) =>
                          setState(() => viewer = update(viewer)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Swipe Mode'), findsNothing);
        final loadOriginal = find.text('Load Original When Zooming');
        await tester.ensureVisible(loadOriginal);
        await tester.tap(loadOriginal);
        await tester.pumpAndSettle();
        expect(viewer.loadOriginalOnZoom, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
