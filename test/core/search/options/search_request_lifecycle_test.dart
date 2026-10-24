import 'dart:async';

import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/routes/params.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';
import 'package:kurumi/kurumi.dart';

import '../../../support/fakes/test_post.dart';
import '../following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets(
    'changing a restored page resets pagination even when returning to the initial query',
    (tester) async {
      final search = _SearchHarness(
        params: const SearchParams(query: 'cat', page: 5),
      );
      await search.pump(tester);
      expect(search.queries, ['cat|5']);
      search.complete(0, []);
      await drain(tester);
      search.input.submit('dog');
      await drain(tester);
      expect(search.queries.last, 'cat dog|1');
      search.complete(1, []);
      await drain(tester);
      search.input.tagsController.removeTag(
        search.input.tagsController.tags.last,
      );
      await drain(tester);
      expect(search.queries.last, 'cat|1');
      search.complete(2, []);
      await drain(tester);
    },
  );

  testWidgets('confirming an emptied chip through the search bar removes it', (
    tester,
  ) async {
    final search = _SearchHarness(interactive: true);
    await search.pump(tester);
    search.input.submit('cat');
    await drain(tester);
    search.complete(0, []);
    await drain(tester);
    search.input.editTag(search.input.tagsController.tags.single);
    await drain(tester);
    await tester.enterText(find.byType(EditableText), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await drain(tester);
    expect(search.input.tagsController.tags, isEmpty);
    expect(search.queries, ['cat|1', '|1']);
    search.complete(1, []);
    await drain(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed changes start once and typing leaves results alone', (
    tester,
  ) async {
    final search = _SearchHarness();
    await search.pump(tester);
    search.input.updateQuery('unfinished');
    await drain(tester);
    expect(search.requests, isEmpty);
    search.input.submit('cat');
    await drain(tester);
    expect(search.queries, ['cat|1']);
    search.complete(0, []);
    await drain(tester);
    search.input.submit('dog');
    search.input.submit('bird');
    await drain(tester);
    expect(search.queries, ['cat|1', 'cat dog bird|1']);
    search.complete(1, []);
    await drain(tester);
    search.input.tagsController.clear();
    await drain(tester);
    expect(search.queries.last, '|1');
    search.complete(2, []);
    await drain(tester);
    final refresh = search.posts.value!.refresh();
    search.complete(3, []);
    await refresh;
    expect(search.queries, ['cat|1', 'cat dog bird|1', '|1', '|1']);
  });

  testWidgets('a new query completes without waiting for an obsolete request', (
    tester,
  ) async {
    final search = _SearchHarness();
    await search.pump(tester);
    search.input.submit('cat');
    await drain(tester);
    search.input.submit('dog');
    await drain(tester);
    expect(search.queries, ['cat|1', 'cat dog|1']);
    search.complete(1, [TestPost(id: 2)]);
    await drain(tester);
    expect(search.posts.value!.allItems.map((post) => post.id), [2]);
    search.complete(0, [TestPost(id: 1)]);
    await drain(tester);
    expect(search.posts.value!.allItems.map((post) => post.id), [2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late pagination cannot append old-query posts after a change', (
    tester,
  ) async {
    final search = _SearchHarness();
    await search.pump(tester);
    search.input.submit('cat');
    await drain(tester);
    search.complete(0, [TestPost(id: 1)]);
    await drain(tester);
    final oldPosts = search.posts.value!;
    final more = oldPosts.fetchMore();
    await tester.pump(oldPosts.debounceDuration);
    await drain(tester);
    expect(search.queries, ['cat|1', 'cat|2']);
    search.input.submit('dog');
    await drain(tester);
    expect(search.queries.last, 'cat dog|1');
    search.complete(2, [TestPost(id: 3)]);
    await drain(tester);
    search.complete(1, [TestPost(id: 2)]);
    await more;
    await drain(tester);
    expect(search.posts.value!.allItems.map((post) => post.id), [3]);
    expect(search.posts.value!.page, 1);
    expect(tester.takeException(), isNull);
  });
}

class _SearchHarness {
  _SearchHarness({
    this.interactive = false,
    this.params = const SearchParams(),
  });
  final bool interactive;
  final SearchParams params;
  final harness = FollowingTopicHarness();
  late SearchPageController input;
  late ValueNotifier<PostGridController<Post>?> posts;
  final requests =
      <
        ({
          String query,
          int page,
          Completer<Either<BooruError, PostResult<Post>>> result,
        })
      >[];
  List<String> get queries => [
    for (final request in requests) '${request.query}|${request.page}',
  ];

  Future<void> pump(WidgetTester tester) async {
    addTearDown(harness.dispose);
    await harness.pump(
      tester,
      KurumiTheme(
        data: KurumiThemeData.fromMaterial(
          ThemeData(extensions: const [KurumiExtendedColorScheme()]),
        ),
        child: Scaffold(
          body: SearchPageScaffold<Post>(
            params: params,
            fetcher: (page, tags) {
              final result = Completer<Either<BooruError, PostResult<Post>>>();
              requests.add((
                query: tags.rawTagsString,
                page: page,
                result: result,
              ));
              return TaskEither(() => result.future);
            },
            landingViewBuilder: (_) => const SizedBox.expand(),
            searchRegionBuilder: (postController, controller) {
              input = controller;
              posts = postController;
              return interactive
                  ? DefaultSearchRegion(
                      controller: controller,
                      postController: postController,
                    )
                  : const SizedBox.shrink();
            },
            itemBuilder: (_, index, _, _, _) => Text('Post $index'),
          ),
        ),
      ),
    );
  }

  void complete(int index, List<Post> result) =>
      requests[index].result.complete(Either.of(testPostResult(result)));
}
