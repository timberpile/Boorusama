import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  test('mixed source filtering compares exact hosts and preserves group/tag constraints', () {
    final sources = [
      'https://booru.example/post/1',
      'https://notbooru.example/post/1',
      'https://sub.booru.example/post/1',
      'https://other.example/booru.example',
      'https://BOORU.EXAMPLE:444/post/1',
      'http://booru.example/post/1',
    ];
    final posts = [
      for (final (index, source) in sources.indexed)
        _bookmark(index + 1, source),
    ];
    final state = BookmarkLibraryState(
      bookmarks: posts,
      pools: [
        testPool(id: 10, host: 'booru.example', tags: {'allowed'}),
        testPool(id: 11, host: 'notbooru.example', tags: {'allowed'}),
        testPool(id: 12, host: 'sub.booru.example', tags: {'allowed'}),
        testPool(
          id: 13,
          host: 'other.example/booru.example',
          tags: {'allowed'},
        ),
        testPool(id: 14, host: 'BOORU.EXAMPLE:444/path', tags: {'allowed'}),
        testPool(id: 15, host: 'booru.example', tags: {'blocked'}),
      ],
      groups: [
        BookmarkGroup(
          id: poolGroupA,
          name: 'A',
          bookmarkIds: posts.map((p) => p.id).toSet(),
        ),
      ],
    );
    for (final selected in ['booru.example', 'BOORU.EXAMPLE']) {
      final entries = selectBookmarkGridEntries(
        state: state,
        view: BookmarkView.group(poolGroupA),
        selectedTags: ['allowed'],
        sortType: BookmarkSortType.oldest,
        selectedBooruUrl: selected,
      );
      expect(entries.whereType<BookmarkPostEntry>().map((e) => e.bookmark.id), [
        1,
        5,
        6,
      ]);
      expect(entries.whereType<BookmarkPoolEntry>().map((e) => e.pool.poolId), [
        10,
        14,
      ]);
    }
    final all = selectBookmarkGridEntries(
      state: state,
      view: const BookmarkView.all(),
      selectedTags: [],
      sortType: BookmarkSortType.oldest,
    );
    expect(all, hasLength(posts.length + state.pools.length));
    expect(
      selectBookmarkGridEntries(
        state: state,
        view: BookmarkView.group(poolGroupB),
        selectedTags: [],
        sortType: BookmarkSortType.oldest,
        selectedBooruUrl: 'booru.example',
      ),
      isEmpty,
    );
  });
}

Bookmark _bookmark(int id, String source) {
  final base = testPoolPost(id, tags: {'allowed'});
  return Bookmark.fromSnapshot(
    id: base.id,
    createdAt: base.createdAt,
    updatedAt: base.updatedAt,
    postId: base.postId,
    snapshot: base.snapshot,
    post: base.post,
    sourceUrl: source,
  );
}
