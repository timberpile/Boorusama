// Package imports:
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../data/providers.dart';
import '../types/bookmark.dart';
import '../types/bookmark_group_browser.dart';
import '../types/bookmark_repository.dart';
import 'bookmark_group_providers.dart';
import 'bookmark_provider.dart';
import 'bookmark_shuffle_provider.dart';
import 'local_providers.dart';

final bookmarkGroupBrowserItemsProvider = FutureProvider.autoDispose
    .family<List<BookmarkGroupBrowserItem>, BookmarkSortType>((
      ref,
      sortType,
    ) async {
      ref.watch(bookmarkProvider);
      final groups = await ref.watch(bookmarkGroupsProvider.future);
      final shuffleState = ref.watch(bookmarkShuffleProvider);
      final bookmarks = await (await ref.read(bookmarkRepoProvider.future))
          .getAllBookmarksOrEmpty(
            imageUrlResolver: (booruId) =>
                ref.read(bookmarkUrlResolverProvider(booruId)),
          );
      final membershipsByBookmark = await (await ref.read(
        bookmarkGroupRepoProvider.future,
      )).getMembershipsByBookmark();

      Bookmark? previewFor(int? groupId) {
        return filterBookmarks(
          bookmarks: bookmarks,
          selectedTags: const [],
          sortType: sortType,
          membershipsByBookmark: membershipsByBookmark,
          selectedBookmarkGroupId: groupId,
          shuffleState: shuffleState,
        ).firstOrNull;
      }

      return [
        BookmarkGroupBrowserItem(
          groupId: null,
          group: null,
          preview: previewFor(null),
        ),
        BookmarkGroupBrowserItem(
          groupId: kUngroupedBookmarkGroupId,
          group: null,
          preview: previewFor(kUngroupedBookmarkGroupId),
        ),
        ...groups.map(
          (group) => BookmarkGroupBrowserItem(
            groupId: group.id,
            group: group,
            preview: previewFor(group.id),
          ),
        ),
      ];
    });
