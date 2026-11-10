import 'package:boorusama/core/bookmarks/src/widgets/bookmark_local_group_card.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'decoded cover quadrants remain attached during drag and overscroll',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: BookmarkGroupPreviewGrid(
                      previews: [
                        for (var i = 0; i < 4; i++)
                          PostBookmark.empty.copyWith(id: i),
                      ],
                      itemBuilder: (_, bookmark) => ColoredBox(
                        key: ValueKey(bookmark.id),
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 1600),
              ],
            ),
          ),
        ),
      );
      Rect relative(int i) {
        final card = tester.getRect(find.byType(BookmarkGroupPreviewGrid));
        return tester.getRect(find.byKey(ValueKey(i))).shift(-card.topLeft);
      }

      final before = [for (var i = 0; i < 4; i++) relative(i)];
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey(0))),
      );
      for (final delta in [
        const Offset(0, 120),
        const Offset(0, -40),
        const Offset(0, 60),
      ]) {
        await gesture.moveBy(delta);
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          expect(
            (relative(i).topLeft - before[i].topLeft).distance,
            lessThan(.001),
          );
          expect(
            (relative(i).bottomRight - before[i].bottomRight).distance,
            lessThan(.001),
          );
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        expect(
          (relative(i).topLeft - before[i].topLeft).distance,
          lessThan(.001),
        );
      }
    },
  );
}
