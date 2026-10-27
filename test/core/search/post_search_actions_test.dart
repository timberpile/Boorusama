import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/posts/listing/src/types/post_search_actions.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/search/src/routes/params.dart';
import 'package:boorusama/core/search/search/src/widgets/search_controller.dart';
import 'package:boorusama/core/search/search/src/widgets/search_page_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../support/fakes/test_post.dart';
import 'following_topics/following_topic_test_utils.dart';

void main() {
  final profile = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.danbooru,
      url: 'https://active.example',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': testProfile.id,
  });
  final post = TestPost(
    id: 42,
    origin: PostOrigin.fromSource(
      booruType: BooruType.danbooru,
      booruId: profile.booruId,
      source: profile.url,
      profileIdHint: profile.id,
    ),
  );

  for (final pending in ['text', 'chip edit', 'composition', 'none']) {
    testWidgets('search ID actions preserve pending $pending input', (
      tester,
    ) async {
      final harness = FollowingTopicHarness(profiles: [profile]);
      addTearDown(harness.dispose);
      late SearchPageController editor;
      late PostSearchActions actions;
      await harness.pump(
        tester,
        CurrentBooruConfigScope(
          config: profile,
          child: SearchPageScaffold<Post>(
            params: const SearchParams(query: 'cat order:score id:<100'),
            fetcher: (_, _) =>
                TaskEither.of(const PostResult(posts: <Post>[], total: 0)),
            searchRegionBuilder: (_, controller) {
              editor = controller;
              return Builder(
                builder: (context) {
                  actions = PostSearchActionsScope.maybeOf(context)!;
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      );
      expect(actions.availableFor(post, profile.id), isTrue);
      switch (pending) {
        case 'text':
          editor.textController.text = 'pending';
        case 'chip edit':
          editor.editTag(editor.tagsController.tags.single);
        case 'composition':
          editor.textController.value = const TextEditingValue(
            text: 'x',
            composing: TextRange(start: 0, end: 1),
          );
        case 'none':
          break;
      }
      final draft = editor.inputDraft;
      final query = editor.tagString.value;
      if (pending != 'none') {
        expect(actions.availableFor(post, profile.id), isFalse);
        expect(actions.apply(post, PostIdSearchDirection.fromHere), isFalse);
        expect(editor.tagString.value, query);
        expect(editor.inputDraft, draft);
      } else {
        expect(actions.apply(post, PostIdSearchDirection.fromHere), isTrue);
        expect(editor.tagString.value, 'cat order:score id:>=42');
        expect(actions.apply(post, PostIdSearchDirection.untilHere), isTrue);
        expect(editor.tagString.value, 'cat order:score id:<=42');
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
