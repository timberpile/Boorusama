// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/bookmarks/src/data/bookmark_convert.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  test(
    'a preserving refresh exposes its selection policy only while loading',
    () async {
      late PostGridController<BookmarkPost> controller;
      var preservedDuringFetch = false;
      controller = PostGridController<BookmarkPost>(
        fetcher: (_) {
          preservedDuringFetch = controller.preserveSelectionOnRefresh;
          return TaskEither.right(
            PostResult(
              posts: [Bookmark.empty.toPost()],
              total: 1,
            ),
          );
        },
        blacklistedTagsFetcher: () async => const {},
        mountedChecker: () => true,
        duplicateTracker: PostDuplicateTracker(),
        onError: (_) {},
        debounceDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.refresh(preserveSelection: true);

      expect(preservedDuringFetch, isTrue);
      expect(controller.preserveSelectionOnRefresh, isFalse);
    },
  );
}
