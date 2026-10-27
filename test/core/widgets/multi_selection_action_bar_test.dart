// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
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

  for (final (name, scale) in [
    ('Modify Search', 1.0),
    ('Modify Search', 2.0),
    ('Suche anpassen', 1.0),
    ('Suche anpassen', 2.0),
  ]) {
    testWidgets(
      'wrapped $name preserves button and icon geometry at $scale',
      (
        tester,
      ) async {
        Future<void> mount({required bool wrap}) => tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsProvider.overrideWithValue(Settings.defaultSettings),
            ],
            child: BooruLocalization(
              child: MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: const Size(800, 600),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 320,
                          child: MultiSelectionActionBar(
                            children: [
                              MultiSelectButton(
                                name: 'Download',
                                icon: const Icon(Icons.download),
                                onPressed: () {},
                              ),
                              const MultiSelectPopupButton(
                                name: 'Bookmark',
                                icon: Icon(Icons.bookmark),
                                enabled: true,
                                items: [Text('Groups')],
                              ),
                              MultiSelectPopupButton(
                                name: name,
                                icon: const Icon(Icons.manage_search),
                                enabled: true,
                                wrapLabel: wrap,
                                items: [
                                  KurumiPopupMenuItem(
                                    title: const Text('This Post and Newer'),
                                    onTap: () {},
                                  ),
                                ],
                              ),
                              MultiSelectButton(
                                name: 'Other',
                                icon: const Icon(Icons.copy),
                                onPressed: () {},
                              ),
                              MultiSelectButton(
                                name: 'More',
                                icon: const Icon(Icons.more_horiz),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final button = find.byWidgetPredicate(
          (widget) => widget is MultiSelectPopupButton && widget.name == name,
        );
        final icon = find.byIcon(Icons.manage_search);
        await mount(wrap: false);
        final buttonBefore = tester.getRect(button);
        final iconBefore = tester.getRect(icon);
        final neighborBefore = tester.getRect(find.byIcon(Icons.bookmark));
        await mount(wrap: true);
        expect(tester.getRect(button), buttonBefore);
        expect(tester.getRect(icon), iconBefore);
        expect(tester.getRect(find.byIcon(Icons.bookmark)), neighborBefore);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(name),
        );
        expect(tester.widget<Text>(find.text(name)).maxLines, 2);
        expect(paragraph.didExceedMaxLines, isFalse);
        if (scale == 1) {
          final first = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: name.indexOf(' ')),
          );
          final second = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: name.indexOf(' ') + 1,
              extentOffset: name.length,
            ),
          );
          expect(second.single.top, greaterThan(first.single.top));
        }
        final labelBounds = tester.getRect(find.text(name));
        expect(labelBounds.top, greaterThanOrEqualTo(iconBefore.bottom));
        expect(labelBounds.bottom, lessThanOrEqualTo(buttonBefore.bottom));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('This Post and Newer'), findsOneWidget);
        await tester.tap(find.text('This Post and Newer'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
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
