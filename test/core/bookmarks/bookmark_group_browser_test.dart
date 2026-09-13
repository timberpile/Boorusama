// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/pages/bookmark_group_browser_page.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';

void main() {
  testWidgets('preview grid leaves missing cells transparent', (tester) async {
    final previews = [Bookmark.empty.copyWith(id: 1)];

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
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.childrenDelegate.estimatedChildCount, 4);
  });

  testWidgets('preview grid separates all four square cells', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 200,
          child: BookmarkGroupPreviewGrid(
            previews: [Bookmark.empty],
            itemBuilder: (_, _) => const ColoredBox(color: Colors.red),
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

  test('still previews use samples while video previews use thumbnails', () {
    final still = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/image.jpg',
      sampleUrl: 'https://example.com/sample.jpg',
      thumbnailUrl: 'https://example.com/thumb.jpg',
    );
    final video = Bookmark.empty.copyWith(
      originalUrl: 'https://example.com/video.mp4',
      sampleUrl: 'https://example.com/video-sample.jpg',
      thumbnailUrl: 'https://example.com/video-thumb.jpg',
    );

    expect(bookmarkGroupPreviewUrl(still), still.sampleUrl);
    expect(bookmarkGroupPreviewUrl(video), video.thumbnailUrl);
  });
}
