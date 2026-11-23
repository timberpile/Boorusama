import 'package:boorusama/core/bookmarks/src/types/post_bookmark.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_group_selectors.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_series_projection.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_grid_entry.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_group.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_identity.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_library_state.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_view.dart';
import 'package:boorusama/core/bookmarks/src/types/legacy_group_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pool_bookmark_test_utils.dart';

void main() {
  const rootId = '11111111-1111-4111-8111-111111111111';
  const childId = '22222222-2222-4222-8222-222222222222';

  for (final commonVersion in [1, 2]) {
    test(
      'subtree entries preserve distinct known and unaddressable occurrences '
      'for common snapshot v$commonVersion',
      () {
        final knownSource = testPoolPost(777);
        final known = knownSource.copyWith(id: 7001);
        final legacySnapshot = StoredPostSnapshot(
          origin: knownSource.snapshot.origin,
          common: {
            ...knownSource.snapshot.common,
            'schemaVersion': commonVersion,
          },
          custom: knownSource.snapshot.custom,
          codecVersion: knownSource.snapshot.codecVersion,
        );
        final retainedPost = switch (const StoredPostCodec().decode(
          legacySnapshot,
        )) {
          StoredPostDecodeSuccess(:final post) => post,
          _ => throw StateError('Could not decode v$commonVersion fixture'),
        };
        final unaddressable = PostBookmark.fromSnapshot(
          id: 7002,
          createdAt: DateTime.utc(2021, 1, 1),
          updatedAt: DateTime.utc(2021, 1, 2),
          snapshot: legacySnapshot,
          post: retainedPost,
          postId: null,
        );
        final retainedCollection = LegacyGroupBookmark.fromMetadata(
          id: 7003,
          metadata: PoolBookmark(
            localId: 'unaddressable-collection-7003',
            origin: poolOrigin(
              host: 'legacy.example',
              type: BooruType.unknown,
            ),
            sourceTypeId: 777,
            poolId: 7003,
            category: BookmarkedPoolCategory.series,
            title: 'Retained Collection',
            createdAt: DateTime.utc(2020, 1, 1),
            observedAt: DateTime.utc(2024, 1, 1),
            groupIds: const {},
            tags: const {'retained-collection'},
            coverage: PoolTagCoverage.partial,
            total: 1,
          ),
        );
        final root = BookmarkGroup(
          id: rootId,
          name: 'Root',
          bookmarkIds: {known.id},
          addedAt: {known.id: DateTime.utc(2023, 1, 1)},
        );
        final child = BookmarkGroup(
          id: childId,
          name: 'Child',
          parentGroupId: rootId,
          bookmarkIds: {unaddressable.id, retainedCollection.id},
          addedAt: {
            unaddressable.id: DateTime.utc(2022, 1, 1),
            retainedCollection.id: DateTime.utc(2021, 1, 1),
          },
        );
        final state = BookmarkLibraryState(
          bookmarks: [known, unaddressable],
          records: [known, unaddressable, retainedCollection],
          groups: [root, child],
        );

        expect(unaddressable.postId, isNull);
        expect(identical(known.post, unaddressable.post), isFalse);
        expect(
          BookmarkIdentity.tryFromPost(known.post),
          BookmarkIdentity.tryFromPost(unaddressable.post),
        );
        expect(
          state.storedBookmarkForPost(unaddressable.post)?.id,
          unaddressable.id,
        );

        final entries = selectBookmarkGridEntries(
          state: state,
          view: BookmarkView.subtree(rootId),
          selectedTags: const [],
          sortType: BookmarkSortType.newestUpload,
        );
        final postEntries = entries.whereType<BookmarkPostEntry>().toList();
        expect(postEntries.map((entry) => entry.bookmark.id).toSet(), {
          known.id,
          unaddressable.id,
        });
        expect(postEntries.map((entry) => entry.key).toSet(), hasLength(2));
        expect(
          entries.whereType<BookmarkPoolEntry>().map(
            (entry) => entry.pool.localId,
          ),
          ['7003'],
        );

        final visible = visibleBookmarkGridEntries(entries, [known.post]);
        expect(
          visible.entries.whereType<BookmarkPostEntry>().map(
            (entry) => entry.bookmark.id,
          ),
          [known.id],
        );
        expect(
          visible.entries.whereType<BookmarkPoolEntry>().map(
            (entry) => entry.pool.localId,
          ),
          ['7003'],
        );
      },
    );
  }
}
