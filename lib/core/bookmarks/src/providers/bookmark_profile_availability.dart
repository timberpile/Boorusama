import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configs/config/types.dart';
import '../../../configs/manage/providers.dart';
import '../types/bookmark_library_state.dart';
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
}

final bookmarkProfileAvailabilityProvider =
    Provider.autoDispose<BookmarkProfileAvailability?>((ref) {
      final library = ref.watch(bookmarkProvider).valueOrNull;
      final profiles = ref.watch(booruConfigProvider);
      return library == null
          ? null
          : BookmarkProfileAvailability(library, profiles);
    }, dependencies: [bookmarkProvider, booruConfigProvider]);
