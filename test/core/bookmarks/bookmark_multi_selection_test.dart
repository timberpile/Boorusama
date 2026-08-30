// Package imports:
import 'package:foundation/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_providers.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_multi_selection.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/types.dart';

class _FakeBookmarkNotifier extends BookmarkNotifier {
  _FakeBookmarkNotifier(this.initialState);

  final BookmarkState initialState;

  @override
  Future<BookmarkState> build() async => initialState;
}

void main() {
  setUpAll(() async {
    await ensureI18nInitialized('en-US');
  });

  final config = BooruConfigAuth.fromConfig(BooruConfig.empty);

  test('aggregates mixed bookmark memberships for the selected posts', () {
    final grouped = Bookmark.empty.copyWith(
      id: 1,
      originalUrl: 'https://example.com/grouped.jpg',
    );
    final ungrouped = Bookmark.empty.copyWith(
      id: 2,
      originalUrl: 'https://example.com/ungrouped.jpg',
    );
    final state = BookmarkState(
      bookmarks: {grouped.uniqueId, ungrouped.uniqueId}.toISet(),
      memberships: {
        grouped.uniqueId: const {10},
        ungrouped.uniqueId: const <int>{},
      },
    );

    final summary = BookmarkGroupSelectionSummary.fromPosts(
      posts: [grouped.toPost(), ungrouped.toPost(), DemoPost()],
      state: state,
      booruId: config.booruIdHint,
    );

    expect(summary.totalPosts, 3);
    expect(summary.bookmarkedPosts, 2);
    expect(summary.ungroupedBookmarks, 1);
    expect(summary.countFor(10), 1);
  });

  testWidgets('formats removal feedback when bookmarks become ungrouped', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              message = formatBookmarkGroupRemovalSuccessMessage(
                context,
                const BookmarkGroupRemovalResult(
                  removedCount: 3,
                  movedToNoGroupCount: 2,
                ),
                'Favorites',
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
      message,
      '3 bookmarks removed from Favorites; '
      '2 bookmarks are now in No Group',
    );
  });

  testWidgets('omits No Group feedback when no bookmarks become ungrouped', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      BooruLocalization(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              message = formatBookmarkGroupRemovalSuccessMessage(
                context,
                const BookmarkGroupRemovalResult(
                  removedCount: 3,
                  movedToNoGroupCount: 0,
                ),
                'Favorites',
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(message, '3 bookmarks removed from Favorites');
  });

  testWidgets('hides actions when no selected post has a bookmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          child: MaterialApp(
            home: BookmarkMultiSelectionMenu(
              posts: [DemoPost()],
              config: config,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to group'), findsOneWidget);
    expect(find.text('Remove from group'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('shows delete for bookmarked posts with the actual count', (
    tester,
  ) async {
    final bookmark = Bookmark.empty.copyWith(
      id: 1,
      originalUrl: 'https://example.com/bookmarked.jpg',
    );
    final state = BookmarkState(
      bookmarks: {bookmark.uniqueId}.toISet(),
      memberships: {
        bookmark.uniqueId: const <int>{},
      },
    );

    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            bookmarkProvider.overrideWith(
              () => _FakeBookmarkNotifier(state),
            ),
          ],
          child: MaterialApp(
            home: BookmarkMultiSelectionMenu(
              posts: [bookmark.toPost(), DemoPost()],
              config: config,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to group'), findsOneWidget);
    expect(find.text('Remove from group'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete bookmarks?'), findsOneWidget);
    expect(
      find.text('This will delete all the 1 bookmarks of the selected posts.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('shows remove for posts with grouped bookmarks', (tester) async {
    final bookmark = Bookmark.empty.copyWith(
      id: 1,
      originalUrl: 'https://example.com/grouped.jpg',
    );
    final state = BookmarkState(
      bookmarks: {bookmark.uniqueId}.toISet(),
      memberships: {
        bookmark.uniqueId: const {10},
      },
    );

    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            bookmarkProvider.overrideWith(
              () => _FakeBookmarkNotifier(state),
            ),
          ],
          child: MaterialApp(
            home: BookmarkMultiSelectionMenu(
              posts: [bookmark.toPost()],
              config: config,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Add to group'), findsOneWidget);
    expect(find.text('Remove from group'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('shows aggregate counts in the add dialog', (tester) async {
    final bookmark = Bookmark.empty.copyWith(
      id: 1,
      originalUrl: 'https://example.com/grouped.jpg',
    );
    final state = BookmarkState(
      bookmarks: {bookmark.uniqueId}.toISet(),
      memberships: {
        bookmark.uniqueId: const {10},
      },
    );

    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            bookmarkProvider.overrideWith(
              () => _FakeBookmarkNotifier(state),
            ),
            bookmarkGroupsProvider.overrideWith(
              (ref) => Future.value([
                const BookmarkGroup(id: 10, name: 'Favorites'),
              ]),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showBookmarkGroupSelectionDialog(
                  context,
                  operation: BookmarkMultiSelectionOperation.add,
                  posts: [bookmark.toPost(), DemoPost()],
                  config: config,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('No Group'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
  });

  testWidgets('remove dialog lists only groups represented by the selection', (
    tester,
  ) async {
    final bookmark = Bookmark.empty.copyWith(
      id: 1,
      originalUrl: 'https://example.com/grouped.jpg',
    );
    final state = BookmarkState(
      bookmarks: {bookmark.uniqueId}.toISet(),
      memberships: {
        bookmark.uniqueId: const {10},
      },
    );

    await tester.pumpWidget(
      BooruLocalization(
        child: ProviderScope(
          overrides: [
            bookmarkProvider.overrideWith(
              () => _FakeBookmarkNotifier(state),
            ),
            bookmarkGroupsProvider.overrideWith(
              (ref) => Future.value([
                const BookmarkGroup(id: 10, name: 'Favorites'),
                const BookmarkGroup(id: 20, name: 'Other'),
              ]),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showBookmarkGroupSelectionDialog(
                  context,
                  operation: BookmarkMultiSelectionOperation.remove,
                  posts: [bookmark.toPost()],
                  config: config,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Remove bookmarks from group'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    expect(find.text('No Group'), findsNothing);
  });
}
