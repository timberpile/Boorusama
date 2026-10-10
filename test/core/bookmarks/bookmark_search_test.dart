import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_search_token.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bookmarks = [
    for (final (index, tags) in [
      {'blue_hair', 'smile'},
      {'blue_hair', 'glasses'},
      {'hat', 'smile'},
      <String>{},
      {'BLUE_HAIR', 'SMILE'},
    ].indexed)
      Bookmark.empty.copyWith(
        id: index + 1,
        postId: () => index + 1,
        sourceUrl:
            'https://${index == 4 ? 'two' : 'one'}.example/posts/${index + 1}',
        tags: tags,
        createdAt: DateTime.utc(2026, 1, index + 1),
      ),
  ];
  final state = BookmarkLibraryState(
    bookmarks: bookmarks,
    groups: [
      BookmarkGroup(
        id: defaultBookmarkGroupId,
        name: 'Default',
        bookmarkIds: const {3, 4, 5},
      ),
      BookmarkGroup(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Group',
        bookmarkIds: const {1, 2},
      ),
    ],
    activeTarget: const BookmarkTarget.defaultGroup(),
  );

  final cases = [
    (tags: ['blue_hair', '-glasses'], ids: [1, 5]),
    (tags: ['blue_hair', 'smile', '-glasses', '-hat'], ids: [1, 5]),
    (tags: ['-glasses', '-hat'], ids: [1, 4, 5]),
    (tags: ['-BLUE_HAIR'], ids: [3, 4]),
    (tags: ['BLUE_HAIR'], ids: [1, 2, 5]),
    (tags: ['-'], ids: [1, 2, 3, 4, 5]),
    (tags: ['blue_hair', '-blue_hair'], ids: <int>[]),
    (tags: ['~blue_hair'], ids: <int>[]),
    (tags: ['blue*'], ids: <int>[]),
    (tags: ['rating:safe'], ids: <int>[]),
  ];
  for (final c in cases) {
    test('matches exact stored tags for ${c.tags}', () {
      expect(
        filterBookmarks(
          bookmarks: bookmarks,
          selectedTags: c.tags,
          sortType: BookmarkSortType.oldest,
        ).map((b) => b.id),
        c.ids,
      );
    });
  }
  for (final view in [
    const BookmarkView.all(),
    BookmarkView.group(defaultBookmarkGroupId),
    BookmarkView.group('550e8400-e29b-41d4-a716-446655440000'),
  ]) {
    for (final source in [null, 'one.example', 'two.example']) {
      test('combines negative search with $view and source $source', () {
        final scoped = selectBookmarks(
          state: state,
          view: view,
          selectedTags: const [],
          sortType: BookmarkSortType.newest,
          selectedBooruUrl: source,
        );
        final result = selectBookmarks(
          state: state,
          view: view,
          selectedTags: const ['-glasses', '-hat'],
          sortType: BookmarkSortType.newest,
          selectedBooruUrl: source,
        );
        expect(result, scoped.where((b) => ![2, 3].contains(b.id)).toList());
      });
    }
  }
  for (final c in [
    (
      text: 'blue_hair -gla',
      suggestion: 'glasses',
      result: 'blue_hair -glasses ',
    ),
    (text: '-GLA', suggestion: 'glasses', result: '-glasses '),
    (text: '-', suggestion: 'glasses', result: '-glasses '),
    (
      text: 'blue_hair\t-gla',
      suggestion: 'glasses',
      result: 'blue_hair -glasses ',
    ),
    (text: 'gla', suggestion: 'glasses', result: 'glasses '),
    (text: 'blue_hair', suggestion: 'glasses', result: 'blue_hair glasses '),
  ]) {
    test('inserts local suggestion for ${c.text}', () {
      expect(insertBookmarkTagSuggestion(c.text, c.suggestion), c.result);
    });
  }
  test(
    'local autocomplete strips only the negative operator and normalizes case',
    () {
      expect(BookmarkSearchToken.current('blue_hair -GLA').tag, 'gla');
      expect(BookmarkSearchToken.current('blue_hair -').tag, isEmpty);
      expect(BookmarkSearchToken.current('~gla').tag, '~gla');
    },
  );
}
