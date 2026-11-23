import 'dart:async';

import 'package:boorusama/boorus/danbooru/pools/content_group_source.dart';
import 'package:boorusama/boorus/danbooru/pools/pool/types.dart';
import 'package:boorusama/boorus/szurubooru/pools/content_group_source.dart';
import 'package:boorusama/boorus/szurubooru/pools/types.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../support/fakes/test_post.dart';

void main() {
  for (final engine in [BooruType.danbooru, BooruType.szurubooru]) {
    test(
      '$engine Pool refresh leaves unrelated pending members valid',
      () async {
        final config = BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': '00000000-0000-4000-8000-000000000001',
          'url': 'https://site.test',
          'booruId': engine.id,
          'booruIdHint': engine.id,
        });
        final access = ContentAccessContext.profile(
          config: config,
          authEpoch: 1,
          policyEpoch: 1,
        );
        ContentReference group(int id) => const ContentReferenceCodec().parse(
          engine: engine,
          site: Uri.parse(config.url),
          kind: ContentKind.group,
          sourceKey: 'pool:$id',
        );
        final posts = _Posts();
        final ContentGroupSource source = engine == BooruType.danbooru
            ? DanbooruGroupSource(
                access: access,
                fetchPool: (id) async => DanbooruPool.empty().copyWith(
                  id: id,
                  postIds: [id],
                ),
                postRepository: () => posts,
              )
            : SzurubooruGroupSource(
                access: access,
                fetchPool: (id) async => SzurubooruPool(
                  id: id,
                  names: const [],
                  category: null,
                  description: null,
                  postCount: 1,
                  postIds: [id],
                  thumbnailUrls: const [],
                  createdAt: null,
                  updatedAt: null,
                ),
                postRepository: () => posts,
              );
        addTearDown(source.dispose);
        final a = source
            .loadMembers(GroupMemberQuery(reference: group(1)))
            .run();
        final b = source
            .loadMembers(GroupMemberQuery(reference: group(2)))
            .run();
        await Future.wait(posts.started.values.map((signal) => signal.future));
        source.invalidate(group(1));
        for (final id in [1, 2]) {
          posts.gates['id:$id']!.complete(
            PostResult(
              total: 1,
              posts: [TestPost(id: id, origin: postOriginFromConfig(config))],
            ),
          );
        }
        expect((await a).fold((_) => true, (_) => false), isTrue);
        final batch = (await b).fold((error) => throw error, (value) => value);
        expect(batch.page.items.single.reference.sourceKey, 'id:2');
        expect((batch.resolved.single as PostContentEntry).post.id, 2);

        final cached = await source
            .loadMembers(GroupMemberQuery(reference: group(2)))
            .run();
        expect(cached.fold((_) => false, (_) => true), isTrue);
        expect(posts.requests, {'id:1': 1, 'id:2': 1});
      },
    );
  }
}

class _Posts implements PostRepository<Post> {
  final gates = {
    for (final id in [1, 2]) 'id:$id': Completer<PostResult<Post>>(),
  };
  final started = {
    for (final id in [1, 2]) 'id:$id': Completer<void>(),
  };
  final requests = <String, int>{};

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.tryCatch(
    () async {
      requests.update(tags, (count) => count + 1, ifAbsent: () => 1);
      if (!started[tags]!.isCompleted) started[tags]!.complete();
      return gates[tags]!.future;
    },
    (error, _) => UnknownError(error: error, message: 'Test Post fetch failed'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
