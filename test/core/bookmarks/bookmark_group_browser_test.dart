// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';

void main() {
  testWidgets('leaves missing preview cells empty', (tester) async {
    final previews = [Bookmark.empty.copyWith(id: 1)];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: BookmarkGroupPreviewGrid(
            previews: previews,
            itemBuilder: (context, bookmark) =>
                Text('${bookmark.id}', key: ValueKey(bookmark.id)),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    expect(find.byKey(const ValueKey(2)), findsNothing);
  });

  testWidgets('renders all available preview cells up to four', (tester) async {
    final previews = List.generate(
      4,
      (index) => Bookmark.empty.copyWith(id: index + 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: BookmarkGroupPreviewGrid(
            previews: previews,
            itemBuilder: (context, bookmark) =>
                Text('${bookmark.id}', key: ValueKey(bookmark.id)),
          ),
        ),
      ),
    );

    for (final bookmark in previews) {
      expect(find.byKey(ValueKey(bookmark.id)), findsOneWidget);
    }
  });

  testWidgets('separates preview cells with a small transparent gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 200,
          child: BookmarkGroupPreviewGrid(
            previews: [Bookmark.empty],
            itemBuilder: (context, bookmark) => const ColoredBox(
              color: Colors.red,
            ),
          ),
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(grid.padding, const EdgeInsets.all(2));
    expect(delegate.crossAxisSpacing, 2);
    expect(delegate.mainAxisSpacing, 2);
  });
}
