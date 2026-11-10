import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../types/bookmark_library_state.dart';
import '../types/bookmark_view.dart';
import 'bookmark_group_selectors.dart';
import 'bookmark_provider.dart';
import 'pool_bookmark_provider.dart';

/// A local presentation projection, never a request permission or storage filter.
/// Existing source/profile binding and cover policy still govern media actions.
class BookmarkProfileAvailability {
  BookmarkProfileAvailability(
    BookmarkLibraryState library,
    List<BooruConfig> profiles,
  ) : postIds = Set.unmodifiable({
        for (final bookmark in library.items)
          if (resolveBookmarkOriginProfile(bookmark.post.origin, profiles) !=
              null)
            bookmark.id,
      }),
      collectionIds = Set.unmodifiable({
        for (final collection in library.pools)
          if (resolvePoolBookmarkProfile(collection, profiles) != null)
            collection.localId,
      }) {
    recordIds = Set.unmodifiable({
      ...postIds,
      for (final collection in library.pools)
        if (collectionIds.contains(collection.localId) &&
            collection.bookmarkId != null)
          collection.bookmarkId!,
    });
  }

  final Set<int> postIds;
  final Set<String> collectionIds;
  late final Set<int> recordIds;

  /// Count saved Posts in the current timeline scope, before availability hides
  /// them. Shared subgroup memberships count each saved record only once.
  Map<String, int> unavailablePostsBySite({
    required BookmarkLibraryState library,
    required BookmarkView view,
    required List<String> selectedTags,
    String? selectedBooruUrl,
  }) {
    final ids = view.kind == BookmarkViewKind.all
        ? null
        : library.bookmarkIdsForView(view);
    final matches = matchingBookmarks(
      bookmarks: library.items.where(
        (bookmark) =>
            !postIds.contains(bookmark.id) &&
            (ids == null || ids.contains(bookmark.id)),
      ),
      selectedTags: selectedTags,
      selectedBooruUrl: selectedBooruUrl,
    );
    final seen = <int>{};
    final counts = <String, int>{};
    for (final bookmark in matches) {
      if (!seen.add(bookmark.id)) continue;
      final host = bookmarkSourceHost(bookmark) ?? '';
      counts.update(host, (count) => count + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(counts);
  }
}

final bookmarkProfileAvailabilityProvider =
    Provider.autoDispose<BookmarkProfileAvailability?>((ref) {
      final library = ref.watch(bookmarkProvider).valueOrNull;
      final profiles = ref.watch(booruConfigProvider);
      return library == null
          ? null
          : BookmarkProfileAvailability(library, profiles);
    }, dependencies: [bookmarkProvider, booruConfigProvider]);
