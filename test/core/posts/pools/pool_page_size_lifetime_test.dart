import 'package:booru_clients/danbooru.dart';
import 'package:booru_clients/szurubooru.dart' as szuru;
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/group_capability.dart';
import 'package:boorusama/boorus/szurubooru/pools/group_capability.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:dio/dio.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/providers/filter_provider.dart';
import 'package:boorusama/boorus/danbooru/pools/details/src/widgets/danbooru_infinite_post_id_list.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/boorus/szurubooru/pools/providers.dart';
import 'package:boorusama/boorus/szurubooru/pools/src/pool_detail_page.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/pools/widgets.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../search/following_topics/following_topic_test_utils.dart';

final _pageSize = StateProvider<int>((ref) => 2);
const _ids = [1, 2, 3, 4, 5, 6, 7];
const _szuruPool = SzurubooruPool(
  id: 1,
  names: ['Pool'],
  category: null,
  description: null,
  postCount: 7,
  postIds: _ids,
  thumbnailUrls: [],
  createdAt: null,
  updatedAt: null,
);

void main() {
  for (final danbooru in [true, false]) {
    testWidgets('Pool rebuild replaces its captured page size ($danbooru)', (
      tester,
    ) async {
      final repository = _Repository();
      final type = danbooru ? BooruType.danbooru : BooruType.szurubooru;
      final config = BooruConfig.fromJson({
        ...testProfile.toJson(),
        'booruId': type.id,
        'booruIdHint': type.id,
      });
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: request,
                  data: {
                    'id': 1,
                    'post_ids': _ids,
                    'post_count': 7,
                    'name': 'Pool',
                  },
                ),
              );
            },
          ),
        );
      addTearDown(() => dio.close(force: true));
      final harness = FollowingTopicHarness(
        profiles: [config],
        overrides: [
          originAwarePostRepoProvider.overrideWith((ref, config) => repository),
          imageListingSettingsProvider.overrideWith(
            (ref) => Settings.defaultSettings.listing.copyWith(
              postsPerPage: ref.watch(_pageSize),
            ),
          ),
          booruGroupCapabilityProvider.overrideWith(
            (ref, engine) => switch (engine) {
              BooruType.danbooru => createDanbooruGroupCapability(ref),
              BooruType.szurubooru => createSzurubooruGroupCapability(ref),
              _ => null,
            },
          ),
          danbooruClientProvider(config.auth).overrideWithValue(
            DanbooruClient(baseUrl: config.url, dio: dio),
          ),
          szurubooruPoolRepoProvider(config.auth)
              .overrideWithValue(_SzuruRepository()),
        ],
      );
      addTearDown(harness.dispose);
      harness.container
          .read(selectedTestProfileProvider.notifier)
          .select(config);
      await harness.pump(
        tester,
        Scaffold(
          body: danbooru
              ? DanbooruInfinitePostIdList(
                  pool: DanbooruPool.empty().copyWith(id: 1, postIds: _ids),
                )
              : const SzurubooruPoolDetailPage(
                  poolId: 1,
                  initialPool: _szuruPool,
                ),
        ),
      );
      PostGridController<Post> controller() =>
          tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller;
      final original = controller();
      expect(repository.queries, ['id:1,2']);
      expect(original.hasMore, isTrue);

      harness.container.read(_pageSize.notifier).state = 3;
      await tester.pump();
      await tester.pump();
      final resized = controller();
      expect(resized, isNot(same(original)));
      expect(repository.queries.last, 'id:1,2,3');
      final refresh = resized.refresh();
      await _complete(tester, refresh);
      expect(repository.queries.last, 'id:1,2,3');
      final load = resized.fetchMore();
      await _complete(tester, load);
      expect(repository.queries.last, 'id:4,5,6');

      if (danbooru) {
        harness.container
            .read(poolFilterProvider.notifier)
            .setOrder(PoolDetailsOrder.latest);
      } else {
        tester
            .widget<PoolOrderToggle>(find.byType(PoolOrderToggle))
            .onChanged(PoolDetailsOrder.latest);
      }
      await tester.pump();
      await tester.pump();
      expect(controller(), isNot(same(resized)));
      expect(repository.queries.last, 'id:7,6,5');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _complete(WidgetTester tester, Future<void> future) async {
  var complete = false;
  future.whenComplete(() => complete = true);
  for (var i = 0; i < 100 && !complete; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(complete, isTrue, reason: 'Pool request did not complete');
  await future;
}

class _Repository implements PostRepository<Post> {
  final queries = <String>[];

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    queries.add(tags);
    // Missing/restricted IDs must keep the remaining source slices loadable.
    return TaskEither.right(const PostResult(posts: [], total: null));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SzuruRepository extends SzurubooruPoolRepository {
  _SzuruRepository()
    : super(szuru.SzurubooruClient(baseUrl: 'https://active.example'));
  @override
  Future<SzurubooruPool?> getPool(int id) async => _szuruPool;
}
