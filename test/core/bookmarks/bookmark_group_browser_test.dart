// Flutter imports:
import 'package:material_ui/material_ui.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';

void main() {
  testWidgets('preview grid leaves missing cells transparent', (tester) async {
    final previews = [PostBookmark.empty.copyWith(id: 1)];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 200,
          child: BookmarkGroupPreviewGrid(
            previews: previews,
            itemBuilder: (context, bookmark) => Text(
              '${bookmark.id}',
              key: ValueKey(bookmark.id),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey(1)), findsOneWidget);
    final empty = find.descendant(
      of: find.byType(BookmarkGroupPreviewGrid),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == double.infinity &&
            widget.height == double.infinity,
      ),
    );
    expect(empty, findsNWidgets(3));
  });

  testWidgets('preview grid separates all four square cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 200,
          child: BookmarkGroupPreviewGrid(
            previews: [PostBookmark.empty],
            itemBuilder: (_, _) => const ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    final preview = find.byType(BookmarkGroupPreviewGrid);
    final padding = tester.widget<Padding>(
      find.descendant(of: preview, matching: find.byType(Padding)).first,
    );
    expect(padding.padding, const EdgeInsets.all(2));
    expect(
      find.descendant(
        of: preview,
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 2,
        ),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: preview,
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 2,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('preview cells fill the square card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: BookmarkGroupPreviewGrid(
              previews: [
                for (var i = 0; i < 4; i++) PostBookmark.empty.copyWith(id: i),
              ],
              itemBuilder: (_, bookmark) =>
                  ColoredBox(key: ValueKey(bookmark.id), color: Colors.red),
            ),
          ),
        ),
      ),
    );
    final previewRect = tester.getRect(find.byType(BookmarkGroupPreviewGrid));
    final first = tester.getRect(find.byKey(const ValueKey(0)));
    final last = tester.getRect(find.byKey(const ValueKey(3)));
    expect(first.topLeft, previewRect.topLeft + const Offset(2, 2));
    expect(last.bottomRight, previewRect.bottomRight - const Offset(2, 2));
    expect(first.size, last.size);
    expect(first.height, first.width);
    expect(tester.takeException(), isNull);
  });

  test('still previews use samples while video previews use thumbnails', () {
    final still = PostBookmark.empty.copyWith(
      originalUrl: 'https://example.com/image.jpg',
      sampleUrl: 'https://example.com/sample.jpg',
      thumbnailUrl: 'https://example.com/thumb.jpg',
    );
    final video = PostBookmark.empty.copyWith(
      originalUrl: 'https://example.com/video.mp4',
      sampleUrl: 'https://example.com/video-sample.jpg',
      thumbnailUrl: 'https://example.com/video-thumb.jpg',
    );

    expect(bookmarkGroupPreviewUrl(still), still.sampleUrl);
    expect(bookmarkGroupPreviewUrl(video), video.thumbnailUrl);
  });
}
