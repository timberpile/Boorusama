import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_prefetch.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../../support/fakes/test_post.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final customButton in [false, true]) {
    testWidgets('one prefetch host with custom scroll control $customButton', (
      tester,
    ) async {
      final harness = FollowingTopicHarness();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        harness.dispose();
      });
      final pages = <int>[];
      late PostGridController<Post> controller;
      await harness.pump(
        tester,
        Scaffold(
          body: PostScope<Post>(
            fetcher: (page) {
              pages.add(page);
              return TaskEither.of(
                PostResult<Post>(
                  posts: page == 1 ? [] : [TestPost(id: 2)],
                  total: null,
                  hasMore: page == 1,
                ),
              );
            },
            builder: (context, value) {
              controller = value;
              return PostGrid<Post>(
                controller: controller,
                header: const SizedBox.shrink(),
                scrollToTopButton: customButton
                    ? const SizedBox.shrink()
                    : null,
                itemBuilder: (_, index, scroll, hero) => Text('Post $index'),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(controller.debounceDuration);
      await tester.pump();
      expect(find.byType(PostGridPrefetch), findsOneWidget);
      expect(pages, [1, 2]);
      expect(controller.items.map((post) => post.id), [2]);
      expect(controller.hasMore, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
