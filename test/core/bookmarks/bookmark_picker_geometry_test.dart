import 'package:boorusama/core/bookmarks/src/widgets/bookmark_folder_picker_contents.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final width in [280.0, 396.0]) {
      testWidgets(
        'split row uses independent 80/20 regions at $width $direction',
        (
          tester,
        ) async {
          var selections = 0;
          var openings = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: width,
                      child: BookmarkPickerSplitRow(
                        onOpen: () => openings++,
                        navigationLabel: 'Open group',
                        child: BookmarkPickerMenuItem(
                          title:
                              'A long group title 🐈 using the available width',
                          icon: const Icon(Icons.bookmarks_outlined),
                          onTap: () => selections++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final row = tester.getRect(find.byType(BookmarkPickerSplitRow));
          final ink = find.descendant(
            of: find.byType(BookmarkPickerSplitRow),
            matching: find.byType(InkWell),
          );
          // The two material_ui controls own input above the painted Kurumi row.
          final direct = tester.getRect(ink.at(0));
          final navigation = tester.getRect(ink.at(1));
          expect(direct.width, closeTo(width * .8, .001));
          expect(navigation.width, closeTo(width * .2, .001));
          expect(direct.height, row.height);
          expect(navigation.height, row.height);
          final title = tester.getRect(
            find.textContaining('A long group title'),
          );
          final arrow = tester.getRect(find.byIcon(Icons.chevron_right));
          expect(title.width, greaterThan(width * .7));
          expect(
            direction == TextDirection.ltr
                ? row.right - arrow.right
                : arrow.left - row.left,
            closeTo(8, .001),
          );
          expect(find.byType(VerticalDivider), findsNothing);
          expect(row.height, lessThan(48));
          expect(find.byIcon(Icons.folder_outlined), findsOneWidget);

          final boundary = direction == TextDirection.ltr
              ? direct.right
              : direct.left;
          final selectionX =
              boundary + (direction == TextDirection.ltr ? -1 : 1);
          final navigationX =
              boundary + (direction == TextDirection.ltr ? 1 : -1);
          await tester.tapAt(Offset(selectionX, row.center.dy));
          expect(selections, 1);
          expect(openings, 0);
          await tester.tapAt(Offset(navigationX, row.center.dy));
          await tester.tapAt(
            Offset(
              direction == TextDirection.ltr ? row.right - 1 : row.left + 1,
              row.center.dy,
            ),
          );
          expect(selections, 1);
          expect(openings, 2);

          // Both semantic actions remain independently reachable by keyboard.
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(selections, 2);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(openings, 3);
          final semantics = tester.ensureSemantics();
          try {
            await tester.pump();
            expect(
              tester
                  .getSemantics(find.bySemanticsLabel('Open group'))
                  .rect
                  .width,
              closeTo(width * .2, .001),
            );
          } finally {
            semantics.dispose();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
