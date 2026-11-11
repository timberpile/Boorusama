import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/pools/src/widgets/group_gallery_checkpoint.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';

void main() {
  for (final offset in [0.0, 20.0]) {
    testWidgets(
      'paginated checkpoint restores page 3 at offset $offset after eviction',
      (tester) async {
        final bucket = PageStorageBucket();
        final calls = <int>[];
        PostGridController<Post> controller() => PostGridController<Post>(
          fetcher: (page) => TaskEither.right(
            PostResult(posts: [TestPost(id: page)], total: 10, maxPage: 5),
          ),
          blacklistedTagsFetcher: () async => {},
          mountedChecker: () => true,
          duplicateTracker: PostDuplicateTracker(mode: DuplicateCheckMode.id),
          onError: (_) {},
          pageMode: PageMode.paginated,
        );
        final first = controller();
        final scroll1 = ScrollController();
        final scroll2 = ScrollController();
        addTearDown(first.dispose);
        addTearDown(scroll1.dispose);
        addTearDown(scroll2.dispose);
        Widget view(PostGridController<Post> c, ScrollController scroll) =>
            MaterialApp(
              home: PageStorage(
                bucket: bucket,
                child: Builder(
                  builder: (context) => PoolGalleryCheckpoint(
                    identity: 'occurrence-a',
                    controller: c,
                    scrollController: scroll,
                    perPage: 2,
                    child: ListView(
                      controller: scroll,
                      children: [const SizedBox(height: 1000)],
                    ),
                  ),
                ),
              ),
            );
        await tester.pumpWidget(view(first, scroll1));
        await first.jumpToPage(3);
        scroll1.jumpTo(offset);
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        final second = PostGridController<Post>(
          fetcher: (page) {
            calls.add(page);
            return TaskEither.right(
              PostResult(posts: [TestPost(id: page)], total: 10, maxPage: 5),
            );
          },
          blacklistedTagsFetcher: () async => {},
          mountedChecker: () => true,
          duplicateTracker: PostDuplicateTracker(mode: DuplicateCheckMode.id),
          onError: (_) {},
          pageMode: PageMode.paginated,
        );
        addTearDown(second.dispose);
        await second.refresh();
        await tester.pumpWidget(view(second, scroll2));
        await tester.pumpAndSettle();
        expect(second.page, 3);
        expect(calls, [1, 3]);
        expect(scroll2.offset, offset);
      },
    );
  }
}
