import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';

import 'pool_bookmark_test_utils.dart';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bookmarks = [
    bookmark(1, 100),
    bookmark(2, -10),
    bookmark(3, 0),
    bookmark(4, 100),
    bookmark(5, 5),
  ];
  for (final entry in [
    (sort: BookmarkSortType.scoreDescending, ids: [1, 4, 5, 3, 2]),
    (sort: BookmarkSortType.scoreAscending, ids: [2, 3, 5, 1, 4]),
  ]) {
    test(
      '${entry.sort.name} keeps post order with unscored Pool references',
      () {
        final state = BookmarkLibraryState(
          bookmarks: bookmarks.reversed.toList(),
          pools: [
            testPool(category: BookmarkedPoolCategory.collection),
            testPool(id: 11),
          ],
          groups: const [],
        );
        final entries = selectBookmarkGridEntries(
          state: state,
          view: const BookmarkView.all(),
          selectedTags: const [],
          sortType: entry.sort,
        );
        expect(
          entries.whereType<BookmarkPostEntry>().map((e) => e.bookmark.id),
          entry.ids,
        );
        expect(
          entries.take(bookmarks.length),
          everyElement(isA<BookmarkPostEntry>()),
        );
        expect(
          entries.whereType<BookmarkPoolEntry>().map((e) => e.pool.poolId),
          [10, 11],
        );
      },
    );
    test(
      '${entry.sort.name} has stable ties and the same group cover order',
      () {
        final sorted = filterBookmarks(
          bookmarks: bookmarks.reversed.toList(),
          selectedTags: const [],
          sortType: entry.sort,
        );
        expect(sorted.map((bookmark) => bookmark.id), entry.ids);
        expect(bookmarks.map((bookmark) => bookmark.id), [1, 2, 3, 4, 5]);
        final state = BookmarkLibraryState(
          bookmarks: bookmarks,
          groups: const [],
        );
        expect(
          selectBookmarkPreviews(
            state: state,
            view: const BookmarkView.all(),
            sortType: entry.sort,
          ).map((bookmark) => bookmark.id),
          entry.ids.take(4),
        );
      },
    );
  }
}

Bookmark bookmark(int id, int score) {
  final post = Post(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: 'https://sort.example',
    ),
    core: PostCoreData(
      id: id,
      createdAt: DateTime.utc(2025),
      thumbnailImageUrl: '',
      sampleImageUrl: '',
      originalImageUrl: 'https://sort.example/$id.jpg',
      videoUrl: '',
      videoThumbnailUrl: '',
      width: 100,
      height: 100,
      format: 'jpg',
      md5: '',
      fileSize: 0,
      duration: 0,
      tags: const {},
      rating: Rating.general,
      hasComment: false,
      isTranslated: false,
      hasParentOrChildren: false,
      source: PostSource.none(),
      score: score,
    ),
    booruData: const LegacyPostData(typeKey: 'test', custom: {}),
  );
  return Bookmark.fromSnapshot(
    id: id,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    snapshot: const StoredPostCodec().encode(post),
    post: post,
    postId: id,
    sourceUrl: 'https://sort.example/posts/$id',
  );
}
