// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';

void main() {
  const firstGroupId = '550e8400-e29b-41d4-a716-446655440000';
  const secondGroupId = '5f1d7f5e-3114-4dc7-a347-18f95852fc31';
  final bookmarks = [
    Bookmark.empty.copyWith(
      id: 1,
      originalUrl: 'https://example.com/1.jpg',
      sourceUrl: 'https://one.example/posts/1',
      createdAt: DateTime.utc(2026),
      tags: const {'red'},
    ),
    Bookmark.empty.copyWith(
      id: 2,
      originalUrl: 'https://example.com/2.jpg',
      sourceUrl: 'https://two.example/posts/2',
      createdAt: DateTime.utc(2026, 1, 2),
      tags: const {'blue'},
    ),
    Bookmark.empty.copyWith(
      id: 3,
      originalUrl: 'https://example.com/3.jpg',
      sourceUrl: 'https://one.example/posts/3',
      createdAt: DateTime.utc(2026, 1, 3),
      tags: const {'red', 'blue'},
    ),
  ];
  final groups = [
    BookmarkGroup(
      id: firstGroupId,
      name: 'First',
      bookmarkIds: const {1, 3},
    ),
    BookmarkGroup(
      id: secondGroupId,
      name: 'Second',
      bookmarkIds: const {3},
    ),
  ];

  BookmarkLibraryState createState({BookmarkTarget? activeTarget}) {
    return BookmarkLibraryState(
      bookmarks: bookmarks,
      groups: groups,
      activeTarget: activeTarget ?? BookmarkTarget.group(firstGroupId),
    );
  }

  final viewCases = [
    (view: const BookmarkView.all(), expected: [1, 2, 3]),
    (view: const BookmarkView.ungrouped(), expected: [2]),
    (view: BookmarkView.group(firstGroupId), expected: [1, 3]),
    (view: BookmarkView.group(secondGroupId), expected: [3]),
  ];
  for (final testCase in viewCases) {
    test('selects ${testCase.expected} for ${testCase.view}', () {
      final selected = selectBookmarks(
        state: createState(),
        view: testCase.view,
        selectedTags: const [],
        sortType: BookmarkSortType.oldest,
      );

      expect(selected.map((bookmark) => bookmark.id), testCase.expected);
    });
  }

  test('applies group, source, tag, and sort filters together', () {
    final selected = selectBookmarks(
      state: createState(),
      view: BookmarkView.group(firstGroupId),
      selectedTags: const ['red'],
      sortType: BookmarkSortType.newest,
      selectedBooruUrl: 'one.example',
    );

    expect(selected.map((bookmark) => bookmark.id), [3, 1]);
  });

  test('uses the first four sorted bookmarks for previews', () {
    final state = BookmarkLibraryState(
      bookmarks: List.generate(
        6,
        (index) => Bookmark.empty.copyWith(
          id: index + 1,
          originalUrl: 'https://example.com/$index.jpg',
          createdAt: DateTime.utc(2026, 1, index + 1),
        ),
      ),
      groups: [
        BookmarkGroup(
          id: firstGroupId,
          name: 'First',
          bookmarkIds: const {1, 2, 3, 4, 5, 6},
        ),
      ],
      activeTarget: BookmarkTarget.group(firstGroupId),
    );

    expect(
      selectBookmarkPreviews(
        state: state,
        view: BookmarkView.group(firstGroupId),
        sortType: BookmarkSortType.oldest,
      ).map((bookmark) => bookmark.id),
      [1, 2, 3, 4],
    );
  });

  test('falls back to No Group when the persisted target is missing', () {
    final state = BookmarkLibraryState(
      bookmarks: bookmarks,
      groups: groups,
      activeTarget: BookmarkTarget.group(
        'b7b44fc8-f16c-4189-a0eb-2f255202e2fa',
      ),
    );

    expect(state.activeTarget, const BookmarkTarget.ungrouped());
  });

  test('reports active membership and total named memberships', () {
    final presentation = selectBookmarkMembershipPresentation(
      createState(),
      bookmarks[2].uniqueId,
    );

    expect(presentation.isBookmarked, isTrue);
    expect(presentation.isInActiveTarget, isTrue);
    expect(presentation.namedGroupCount, 2);
  });

  test('reports mixed aggregate membership counts from unique selections', () {
    final counts = selectBulkMembershipCounts(
      createState(),
      [
        bookmarks[0].uniqueId,
        bookmarks[2].uniqueId,
        bookmarks[2].uniqueId,
      ],
    );

    expect(counts.selectedCount, 2);
    expect(counts.byGroupId, {firstGroupId: 2, secondGroupId: 1});
    expect(counts.ungroupedCount, 0);
  });
}
