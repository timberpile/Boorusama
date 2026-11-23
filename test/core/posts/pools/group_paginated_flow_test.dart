import 'package:boorusama/boorus/danbooru/pools/content_group_source.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/boorus/szurubooru/pools/content_group_source.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/content_access_provider.dart';
import 'package:boorusama/core/content/groups/group_source_provider.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/posts/listing/providers.dart';
import 'package:boorusama/core/posts/listing/types.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/pools/group_post_scope.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:kurumi/material.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';
import '../../search/following_topics/following_topic_test_utils.dart';

void main() {
  for (final kind in ['danbooru', 'szurubooru', 'related']) {
    testWidgets('$kind paginated grid jumps directly to page 3 and last', (
      tester,
    ) async {
      final f = await _Fixture.mount(tester, kind);
      final controller = f.controller(tester);
      expect(controller.pageMode, PageMode.paginated);
      expect(controller.items.map((p) => p.id), f.ids.take(2));
      await _complete(tester, controller.jumpToPage(3));
      expect(controller.errors.value, isNull);
      expect(controller.items.map((p) => p.id), f.ids.skip(4).take(2));
      await _complete(tester, controller.jumpToPage(4));
      expect(controller.errors.value, isNull);
      expect(controller.items.map((p) => p.id), [f.ids.last]);
      expect(controller.hasNextPage(), isFalse);
      await _complete(tester, controller.goToPreviousPage());
      expect(controller.items.map((p) => p.id), f.ids.skip(4).take(2));
      await _complete(tester, controller.goToNextPage());
      expect(controller.items.map((p) => p.id), [f.ids.last]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$kind refresh on page 2 reloads source and Post data', (
      tester,
    ) async {
      final f = await _Fixture.mount(tester, kind);
      final controller = f.controller(tester);
      await _complete(tester, controller.goToNextPage());
      expect(controller.errors.value, isNull);
      expect(controller.items.map((p) => p.id), f.ids.skip(2).take(2));
      f.version = 2;
      if (kind != 'related') f.ids = [1, 2, 8, 9, 5, 6, 7];
      await _complete(tester, controller.refresh(maintainPage: true));
      expect(controller.page, 2);
      expect(controller.errors.value, isNull);
      expect(controller.items.map((p) => p.id), f.ids.skip(2).take(2));
      expect(
        controller.items.every((p) => p.tags.contains('version_2')),
        isTrue,
      );
      if (kind != 'related') expect(f.poolFetches, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _complete(WidgetTester tester, Future<void> future) async {
  var done = false;
  future.whenComplete(() => done = true);
  for (var i = 0; i < 100 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done, isTrue, reason: 'Group grid operation did not complete');
  await future;
}

class _Fixture {
  _Fixture(this.kind, this.config)
    : ids = kind == 'related'
          ? [10, 11, 12, 13, 14, 15, 16]
          : [1, 2, 3, 4, 5, 6, 7];
  final String kind;
  final BooruConfig config;
  late FollowingTopicHarness harness;
  List<int> ids;
  int version = 1;
  int poolFetches = 0;
  late final repo = _Posts(this);
  PostGridController<Post> controller(WidgetTester tester) =>
      tester.widget<PostGrid<Post>>(find.byType(PostGrid<Post>)).controller;
  static Future<_Fixture> mount(WidgetTester tester, String kind) async {
    final engine = kind == 'szurubooru'
        ? BooruType.szurubooru
        : BooruType.danbooru;
    final config = BooruConfig.fromJson({
      ...testProfile.toJson(),
      'booruId': engine.id,
      'booruIdHint': engine.id,
    });
    final f = _Fixture(kind, config);
    final reference = const ContentReferenceCodec().parse(
      engine: engine,
      site: Uri.parse(config.url),
      kind: ContentKind.group,
      sourceKey: kind == 'related' ? 'related:10' : 'pool:1',
    );
    f.harness = FollowingTopicHarness(
      profiles: [config],
      overrides: [
        contentGroupSourceProvider.overrideWith((ref, key) {
          final access = ref.read(contentAccessContextProvider(key))!;
          final ContentGroupSource source = kind == 'szurubooru'
              ? SzurubooruGroupSource(
                  access: access,
                  postRepository: () => f.repo,
                  fetchPool: (_) async {
                    f.poolFetches++;
                    return SzurubooruPool(
                      id: 1,
                      names: const ['Pool'],
                      category: null,
                      description: null,
                      postCount: f.ids.length,
                      postIds: List.of(f.ids),
                      thumbnailUrls: const [],
                      createdAt: null,
                      updatedAt: null,
                    );
                  },
                )
              : DanbooruGroupSource(
                  access: access,
                  postRepository: () => f.repo,
                  fetchPool: (_) async {
                    f.poolFetches++;
                    return DanbooruPool(
                      id: 1,
                      postIds: List.of(f.ids),
                      category: DanbooruPoolCategory.series,
                      description: null,
                      postCount: f.ids.length,
                      name: 'Pool',
                      createdAt: null,
                      updatedAt: null,
                    );
                  },
                );
          ref.onDispose(source.dispose);
          return source;
        }),
        imageListingSettingsProvider.overrideWith(
          (ref) => Settings.defaultSettings.listing.copyWith(
            postsPerPage: 2,
            pageMode: PageMode.paginated,
          ),
        ),
      ],
    );
    addTearDown(f.harness.dispose);
    f.harness.container
        .read(selectedTestProfileProvider.notifier)
        .select(config);
    await f.harness.pump(
      tester,
      Scaffold(
        body: GroupPostScope(
          reference: reference,
          perPage: 2,
          orderKey: kind == 'related' ? 'oldest' : 'order',
          builder: (context, controller) =>
              PostGrid<Post>(controller: controller),
        ),
      ),
    );
    await tester.pump();
    return f;
  }
}

class _Posts implements PostRepository<Post> {
  _Posts(this.f);
  final _Fixture f;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) {
    final requested = tags.startsWith('id:')
        ? tags.substring(3).split(',').map(int.parse).toList()
        : f.ids.skip((page - 1) * (limit ?? 2)).take(limit ?? 2).toList();
    return TaskEither.right(
      PostResult<Post>(
        posts: [
          for (final id in requested) _post(id),
        ],
        total: f.ids.length,
        hasMore: page * (limit ?? 2) < f.ids.length,
      ),
    );
  }

  Post _post(int id) {
    if (f.kind != 'related') {
      return testPoolPost(id, tags: {'version_${f.version}'}).post.copyWith(
        origin: postOriginFromConfig(f.config),
      );
    }
    final original = testRelatedPost(id, parent: id == 10 ? null : 10);
    final snapshot = const StoredPostCodec().encode(
      original,
      dataCodec: const EmptyPostDataCodec('test'),
    );
    final decoded = const StoredPostCodec().decode(
      StoredPostSnapshot(
        origin: postOriginFromConfig(f.config).toSnapshot(),
        common: {
          ...snapshot.common,
          'tags': ['version_${f.version}'],
        },
        custom: snapshot.custom,
        codecVersion: snapshot.codecVersion,
      ),
      dataCodec: const EmptyPostDataCodec('test'),
    );
    return (decoded as StoredPostDecodeSuccess).post;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
