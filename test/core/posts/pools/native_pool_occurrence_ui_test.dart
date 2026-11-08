import 'package:booru_clients/szurubooru.dart' as szuru;
import 'package:boorusama/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart';
import 'package:boorusama/boorus/danbooru/pools/group_capability.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';
import 'package:boorusama/boorus/szurubooru/pools/group_capability.dart';
import 'package:boorusama/boorus/szurubooru/pools/providers.dart';
import 'package:boorusama/boorus/szurubooru/pools/src/pool_detail_page.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/boorus/szurubooru/posts/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/posts/details/src/routes/viewer_navigation_scope.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

const _ids = [3, 2, 3, 1];
const _szuruPool = SzurubooruPool(
  id: 1,
  names: ['Pool'],
  category: null,
  description: null,
  postCount: 4,
  postIds: _ids,
  thumbnailUrls: [],
  createdAt: null,
  updatedAt: null,
);

void main() {
  for (final engine in [BooruType.danbooru, BooruType.szurubooru]) {
    for (final embedded in [false, true]) {
      testWidgets(
        '$engine Pool repeated occurrence opens its own index without Heroes (embedded=$embedded)',
        (tester) async {
          final config = BooruConfig.fromJson({
            ...testProfile.toJson(),
            'booruId': engine.id,
            'booruIdHint': engine.id,
          });
          final repo = _Posts();
          int? opened;
          final harness = FollowingTopicHarness(
            profiles: [config],
            overrides: [
              danbooruPostRepoProvider.overrideWith((_, _) => repo),
              szurubooruPostRepoProvider.overrideWith((_, _) => repo),
              szurubooruPoolRepoProvider(config.auth)
                  .overrideWithValue(_SzuruRepository()),
              booruGroupCapabilityProvider.overrideWith(
                (ref, type) => switch (type) {
                  BooruType.danbooru => createDanbooruGroupCapability(ref),
                  BooruType.szurubooru => createSzurubooruGroupCapability(ref),
                  _ => null,
                },
              ),
              imageListingSettingsProvider.overrideWith(
                (ref) =>
                    Settings.defaultSettings.listing.copyWith(postsPerPage: 4),
              ),
            ],
          );
          addTearDown(harness.dispose);
          harness.container
              .read(selectedTestProfileProvider.notifier)
              .select(config);
          await harness.pump(
            tester,
            Scaffold(
              body: ViewerNavigationScope(
                open: (index, _) => opened = index,
                child: engine == BooruType.danbooru
                    ? DanbooruInfinitePostIdList(
                        pool: DanbooruPool.empty().copyWith(
                          id: 1,
                          postIds: _ids,
                        ),
                      )
                    : SzurubooruPoolDetailContent(
                        pool: _szuruPool,
                        embedded: embedded,
                        storageId: 'occurrence',
                      ),
              ),
            ),
          );
          final grid = tester.widget<PostGrid<Post>>(
            find.byType(PostGrid<Post>),
          );
          for (var i = 0; i < 50 && grid.controller.items.length != 4; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(grid.controller.items.map((p) => p.id), _ids);
          await tester.pump();
          final items = tester
              .widgetList<PostGridItem>(find.byType(PostGridItem))
              .toList();
          expect(items.map((item) => item.post.id), _ids);
          expect(items.every((item) => !item.useHero), isTrue);
          expect(
            find.descendant(
              of: find.byType(PostGridItem),
              matching: find.byType(Hero),
            ),
            findsNothing,
          );
          await tester.tap(find.byType(PostGridItem).at(2));
          expect(opened, 2);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

class _Posts implements PostRepository<Post> {
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.right(
    PostResult<Post>(
      posts: [
        for (final id in [1, 2, 3]) testPoolPost(id).post,
      ],
      total: null,
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SzuruRepository extends SzurubooruPoolRepository {
  _SzuruRepository()
    : super(szuru.SzurubooruClient(baseUrl: 'https://active.example'));
  @override
  Future<SzurubooruPool?> getPool(int id) async => _szuruPool;
}
