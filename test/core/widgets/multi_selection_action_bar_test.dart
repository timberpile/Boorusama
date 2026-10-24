// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

// Project imports:
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/widgets/multi_select_button.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';

void main() {
  for (final sample in [
    (width: 360.0, count: 4, scale: 1.0),
    (width: 320.0, count: 5, scale: 2.0),
    (width: 900.0, count: 6, scale: 1.0),
  ]) {
    testWidgets('selection bar fits actions up to five slots at $sample', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(Size(sample.width, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWithValue(Settings.defaultSettings),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: Size(sample.width, 700),
                      textScaler: TextScaler.linear(sample.scale),
                    ),
                    child: SizedBox(
                      width: sample.width,
                      height: 100,
                      child: MultiSelectionActionBar(
                        children: [
                          for (var i = 0; i < sample.count; i++)
                            MultiSelectButton(
                              name: 'Action $i',
                              icon: const Icon(Icons.copy),
                              onPressed: () {},
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final visible = sample.count > 5 ? 4 : sample.count;
        for (var i = 0; i < visible; i++) {
          expect(find.text('Action $i').hitTestable(), findsOneWidget);
        }
        if (sample.count > 5) {
          expect(find.text('Action 4'), findsNothing);
          expect(find.text('Action 5'), findsNothing);
          await tester.tap(find.bySemanticsLabel('More'));
          await tester.pumpAndSettle();
          expect(find.text('Action 4').hitTestable(), findsOneWidget);
          expect(find.text('Action 5').hitTestable(), findsOneWidget);
        } else {
          expect(find.byType(KurumiPopupMenuButton), findsNothing);
        }
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('popup actions remain directly usable on constrained rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWithValue(Settings.defaultSettings),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 260,
                child: MultiSelectionActionBar(
                  children: [
                    MultiSelectButton(
                      icon: const Icon(Icons.download),
                      name: 'Download',
                      onPressed: () {},
                    ),
                    const MultiSelectPopupButton(
                      icon: Icon(Icons.bookmark),
                      name: 'Bookmark',
                      enabled: true,
                      items: [Text('Group actions')],
                    ),
                    MultiSelectButton(
                      icon: const Icon(Icons.delete),
                      name: 'Delete',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bookmark'), findsOneWidget);

    final popupTapTarget = find
        .descendant(
          of: find.byType(MultiSelectPopupButton),
          matching: find.byType(InkWell),
        )
        .first;
    await tester.tap(popupTapTarget);
    await tester.pumpAndSettle();

    expect(find.text('Group actions'), findsOneWidget);
  });
}
