import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_target.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('equal bookmark dates retain insertion order in both directions', () {
    final sameDate = DateTime.utc(2026);
    final bookmarks = [
      for (final id in [3, 1, 4, 2])
        _bookmark(
          localId: id,
          postId: 100 - id,
          site: 'alpha.example',
          bookmarkedAt: sameDate,
        ),
    ];
    expect(_ids(bookmarks, BookmarkSortType.newest), [4, 3, 2, 1]);
    expect(_ids(bookmarks, BookmarkSortType.oldest), [1, 2, 3, 4]);
  });

  test('upload and bookmark sort use their respective dates', () {
    final bookmarks = [
      _bookmark(
        localId: 1,
        postId: 10,
        site: 'alpha.example',
        uploadedAt: DateTime.utc(2024),
        bookmarkedAt: DateTime.utc(2026, 1, 3),
      ),
      _bookmark(
        localId: 2,
        postId: 50,
        site: 'beta.example',
        uploadedAt: DateTime.utc(2025),
        bookmarkedAt: DateTime.utc(2026, 1, 1),
      ),
      _bookmark(
        localId: 3,
        postId: 5,
        site: 'alpha.example',
        uploadedAt: DateTime.utc(2023),
        bookmarkedAt: DateTime.utc(2026, 1, 2),
      ),
    ];

    expect(_ids(bookmarks, BookmarkSortType.newestUpload), [2, 1, 3]);
    expect(_ids(bookmarks, BookmarkSortType.oldestUpload), [3, 1, 2]);
    expect(_ids(bookmarks, BookmarkSortType.newest), [1, 3, 2]);
    expect(_ids(bookmarks, BookmarkSortType.oldest), [2, 3, 1]);
  });

  test('missing upload dates use site-scoped numeric post IDs', () {
    final bookmarks = [
      _bookmark(localId: 1, postId: 9, site: 'alpha.example'),
      _bookmark(localId: 2, postId: 100, site: 'alpha.example'),
      _bookmark(localId: 3, postId: 1, site: 'beta.example'),
      _bookmark(
        localId: 4,
        postId: 5,
        site: 'beta.example',
        uploadedAt: DateTime.utc(2020),
      ),
    ];

    // Known dates come first, even for the oldest-upload direction. Undated
    // posts are grouped by site; a larger ID on another site means nothing.
    expect(_ids(bookmarks, BookmarkSortType.newestUpload), [4, 3, 2, 1]);
    expect(_ids(bookmarks, BookmarkSortType.oldestUpload), [4, 1, 2, 3]);
    expect(
      _ids(bookmarks.reversed.toList(), BookmarkSortType.newestUpload),
      [4, 3, 2, 1],
    );
  });

  test('equal upload dates have a stable site and ID tie-breaker', () {
    final sameDate = DateTime.utc(2025, 1, 1);
    final bookmarks = [
      _bookmark(
        localId: 1,
        postId: 9,
        site: 'alpha.example',
        uploadedAt: sameDate,
      ),
      _bookmark(
        localId: 2,
        postId: 10,
        site: 'alpha.example',
        uploadedAt: sameDate,
      ),
      _bookmark(
        localId: 3,
        postId: 1,
        site: 'beta.example',
        uploadedAt: sameDate,
      ),
    ];
    expect(_ids(bookmarks, BookmarkSortType.newestUpload), [3, 2, 1]);
    expect(_ids(bookmarks, BookmarkSortType.oldestUpload), [1, 2, 3]);
    expect(
      _ids(bookmarks.reversed.toList(), BookmarkSortType.oldestUpload),
      [1, 2, 3],
    );
  });

  test('group lists and preview images share upload-date sorting', () {
    const groupId = '550e8400-e29b-41d4-a716-446655440000';
    final bookmarks = [
      _bookmark(
        localId: 1,
        postId: 10,
        site: 'alpha.example',
        uploadedAt: DateTime.utc(2021),
      ),
      _bookmark(
        localId: 2,
        postId: 20,
        site: 'beta.example',
        uploadedAt: DateTime.utc(2024),
      ),
      _bookmark(
        localId: 3,
        postId: 30,
        site: 'alpha.example',
        uploadedAt: DateTime.utc(2023),
      ),
      _bookmark(localId: 4, postId: 40, site: 'beta.example'),
    ];
    final state = BookmarkLibraryState(
      bookmarks: bookmarks,
      groups: [
        BookmarkGroup(
          id: groupId,
          name: 'Mixed',
          bookmarkIds: const {1, 2, 4},
        ),
      ],
      activeTarget: const BookmarkTarget.defaultGroup(),
    );

    final groupView = BookmarkView.group(groupId);
    expect(
      selectBookmarks(
        state: state,
        view: groupView,
        selectedTags: const [],
        sortType: BookmarkSortType.newestUpload,
      ).map((bookmark) => bookmark.id),
      [2, 1, 4],
    );
    expect(
      selectBookmarkPreviews(
        state: state,
        view: groupView,
        sortType: BookmarkSortType.newestUpload,
      ).map((bookmark) => bookmark.id),
      [2, 1, 4],
    );
    expect(
      selectBookmarks(
        state: state,
        view: const BookmarkView.all(),
        selectedTags: const [],
        sortType: BookmarkSortType.newestUpload,
      ).map((bookmark) => bookmark.id),
      [2, 3, 1, 4],
    );
  });
}

List<int> _ids(List<Bookmark> bookmarks, BookmarkSortType sort) =>
    filterBookmarks(
      bookmarks: bookmarks,
      selectedTags: const [],
      sortType: sort,
    ).map((bookmark) => bookmark.id).toList();

Bookmark _bookmark({
  required int localId,
  required int postId,
  required String site,
  DateTime? uploadedAt,
  DateTime? bookmarkedAt,
}) {
  final post = Post(
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: BooruType.danbooru.id,
      source: 'https://$site',
    ),
    core: PostCoreData(
      id: postId,
      createdAt: uploadedAt,
      thumbnailImageUrl: '',
      sampleImageUrl: '',
      originalImageUrl: 'https://$site/images/$postId.jpg',
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
      score: 0,
    ),
    booruData: const LegacyPostData(typeKey: 'test', custom: {}),
  );
  final markedAt = bookmarkedAt ?? DateTime.utc(2026, 1);
  return Bookmark.fromSnapshot(
    id: localId,
    createdAt: markedAt,
    updatedAt: markedAt,
    snapshot: const StoredPostCodec().encode(post),
    post: post,
    postId: postId,
    sourceUrl: 'https://$site/posts/$postId',
  );
}
