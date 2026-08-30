// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

// Project imports:
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';

void main() {
  test('exposes selection-preserving refresh state while fetching', () async {
    late PostGridController<DemoPost> controller;
    var preserveSelectionDuringFetch = false;

    controller = PostGridController<DemoPost>(
      fetcher: (_) {
        preserveSelectionDuringFetch = controller.preserveSelectionOnRefresh;
        return TaskEither.right(PostResult<DemoPost>.empty());
      },
      blacklistedTagsFetcher: () async => {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker<DemoPost>(),
      onError: (_) {},
    );
    addTearDown(controller.dispose);

    await controller.refresh(preserveSelection: true);

    expect(preserveSelectionDuringFetch, isTrue);
    expect(controller.preserveSelectionOnRefresh, isFalse);
  });
}
