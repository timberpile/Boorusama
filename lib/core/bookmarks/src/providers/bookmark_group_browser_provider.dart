// Package imports:
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

List<Bookmark> getBookmarkGroupPreviews({
  required List<Bookmark> bookmarks,
  required BookmarkSortType sortType,
  required Map<int, Set<int>> membershipsByBookmark,
  required int? selectedBookmarkGroupId,
  BookmarkShuffleState? shuffleState,
}) {
  return filterBookmarks(
    bookmarks: bookmarks,
    selectedTags: const [],
    sortType: sortType,
    membershipsByBookmark: membershipsByBookmark,
    selectedBookmarkGroupId: selectedBookmarkGroupId,
    shuffleState: shuffleState,
  ).take(4).toList();
}

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

      return [
        BookmarkGroupBrowserItem(
          groupId: null,
          group: null,
          previews: getBookmarkGroupPreviews(
            bookmarks: bookmarks,
            sortType: sortType,
            membershipsByBookmark: membershipsByBookmark,
            selectedBookmarkGroupId: null,
            shuffleState: shuffleState,
          ),
        ),
        BookmarkGroupBrowserItem(
          groupId: kUngroupedBookmarkGroupId,
          group: null,
          previews: getBookmarkGroupPreviews(
            bookmarks: bookmarks,
            sortType: sortType,
            membershipsByBookmark: membershipsByBookmark,
            selectedBookmarkGroupId: kUngroupedBookmarkGroupId,
            shuffleState: shuffleState,
          ),
        ),
        ...groups.map(
          (group) => BookmarkGroupBrowserItem(
            groupId: group.id,
            group: group,
            previews: getBookmarkGroupPreviews(
              bookmarks: bookmarks,
              sortType: sortType,
              membershipsByBookmark: membershipsByBookmark,
              selectedBookmarkGroupId: group.id,
              shuffleState: shuffleState,
            ),
          ),
        ),
      ];
    });
