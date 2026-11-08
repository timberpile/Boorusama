import 'dart:async';

import 'package:booru_clients/szurubooru.dart';
import 'package:boorusama/boorus/szurubooru/client_provider.dart';
import 'package:boorusama/boorus/szurubooru/szurubooru.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../bookmarks/pool_bookmark_test_utils.dart';

final _ref = Provider<Ref>((ref) => ref);

void main() {
  test(
    'native envelope shared by metadata and ordered partial duplicate members',
    () async {
      final f = _Fixture(
        posts: [
          {'id': 3},
          {'id': 2},
          {'id': 3},
          {'id': 1},
        ],
        category: 'series',
        count: 4,
        names: ['Native name'],
        description: 'Description',
      );
      addTearDown(f.dispose);
      final post3 = f.post(3);
      f.repo.responses['id:3,2'] = [post3];
      f.repo.responses['id:1'] = [f.post(1)];
      final summary = (await f.source.loadSummary(f.group).run()).fold(
        (e) => throw e,
        (v) => v,
      );
      final details = (await f.source.loadDetails(f.group).run()).fold(
        (e) => throw e,
        (v) => v,
      );
      expect(summary.reference.sourceKey, 'pool:42');
      expect(summary.displayCategory, 'series');
      expect(summary.title, 'Native name');
      expect(summary.memberCount, 4);
      expect(details.description?.text, 'Description');
      expect(
        f.repo.queries,
        isEmpty,
        reason: 'metadata must not hydrate members',
      );
      final first = await f.members(limit: 2);
      expect(first.page.items.map((m) => m.reference.sourceKey), [
        'id:3',
        'id:2',
      ]);
      expect(first.page.items.map((m) => m.sourcePosition), [0, 1]);
      expect(first.page.items[1].availability, MemberAvailability.unknown);
      expect(first.resolved, hasLength(1));
      final second = await f.members(limit: 2, cursor: first.page.next);
      expect(second.page.items.map((m) => m.reference.sourceKey), [
        'id:3',
        'id:1',
      ]);
      expect(second.page.items.map((m) => m.sourcePosition), [2, 3]);
      expect(
        [
          ...first.page.items,
          ...second.page.items,
        ].map((m) => m.memberKey).toSet(),
        hasLength(4),
      );
      expect(second.resolved, hasLength(2));
      expect((second.resolved.first as PostContentEntry).post, same(post3));
      expect(f.repo.queries, ['id:3,2', 'id:1']);
      expect(f.requests, 1);
    },
  );

  test(
    'unknown native metadata remains unknown, empty manifest is known empty',
    () async {
      final unknown = _Fixture();
      final empty = _Fixture(posts: [], count: 0);
      addTearDown(unknown.dispose);
      addTearDown(empty.dispose);
      final summary = (await unknown.source.loadSummary(unknown.group).run())
          .fold((e) => throw e, (v) => v);
      final details = (await unknown.source.loadDetails(unknown.group).run())
          .fold((e) => throw e, (v) => v);
      expect(summary.memberCount, isNull);
      expect(summary.displayCategory, isNull);
      expect(summary.title, isNull);
      expect(details.description, isNull);
      expect(
        (await unknown.source
                .loadMembers(GroupMemberQuery(reference: unknown.group))
                .run())
            .fold((_) => true, (_) => false),
        isTrue,
      );
      final batch = await empty.members();
      expect(batch.page.items, isEmpty);
      expect(batch.page.total, 0);
      expect(batch.page.next, isNull);
      expect(unknown.repo.queries, isEmpty);
      expect(empty.repo.queries, isEmpty);
    },
  );

  test('one descriptor without an ID leaves manifest unknown', () async {
    final f = _Fixture(
      posts: [
        {'id': 3},
        <String, Object?>{},
      ],
    );
    addTearDown(f.dispose);
    final result = await f.source
        .loadMembers(GroupMemberQuery(reference: f.group))
        .run();
    expect(result.fold((_) => true, (_) => false), isTrue);
    expect(f.repo.queries, isEmpty);
  });

  test('unresolved first page keeps raw continuation', () async {
    final f = _Fixture(
      posts: [
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ],
    );
    addTearDown(f.dispose);
    f.repo.responses['id:3'] = [f.post(3)];
    final first = await f.members(limit: 2);
    expect(first.resolved, isEmpty);
    expect(first.page.next, isNotNull);
    final second = await f.members(limit: 2, cursor: first.page.next);
    expect(second.page.items.single.sourcePosition, 2);
    expect(second.resolved, hasLength(1));
    expect(second.page.next, isNull);
  });

  test('same IDs stay isolated by host and account', () async {
    final a = _Fixture(
      posts: [
        {'id': 1},
      ],
    );
    final b = _Fixture(
      posts: [
        {'id': 2},
      ],
      profileId: '00000000-0000-4000-8000-000000000002',
    );
    final c = _Fixture(
      posts: [
        {'id': 3},
      ],
      host: 'other.example',
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    addTearDown(c.dispose);
    expect((await a.members()).page.items.single.reference.sourceKey, 'id:1');
    expect((await b.members()).page.items.single.reference.sourceKey, 'id:2');
    expect((await c.members()).page.items.single.reference.sourceKey, 'id:3');
    expect(a.group.identity, b.group.identity);
    expect(a.source.access.key, isNot(b.source.access.key));
    expect(a.group.identity, isNot(c.group.identity));
    final rejected = await a.source
        .loadMembers(GroupMemberQuery(reference: c.group))
        .run();
    expect(rejected.fold((_) => true, (_) => false), isTrue);
    expect(a.requests, 1);
  });

  test(
    'dispose cancels pending member read without closing borrowed client',
    () async {
      final f = _Fixture(
        posts: [
          {'id': 1},
        ],
      );
      addTearDown(f.dispose);
      final gate = Completer<PostResult<Post>>();
      f.repo.gate = gate;
      final pending = f.source
          .loadMembers(GroupMemberQuery(reference: f.group))
          .run();
      final context = await f.repo.started.future;
      f.source.dispose();
      await context.cancelToken!.whenCancel;
      expect(context.canStart?.call(), isFalse);
      final result = await pending;
      expect(result.fold((_) => true, (_) => false), isTrue);
      gate.complete(PostResult<Post>(posts: [f.post(1)], total: null));
      final response = await f.dio.get('/api/pool/42');
      expect(response.statusCode, 200);
    },
  );
}

class _Fixture {
  _Fixture({
    List<Map<String, Object?>>? posts,
    String? category,
    int? count,
    List<String>? names,
    String? description,
    String host = 'szuru.example',
    String profileId = '00000000-0000-4000-8000-000000000001',
  }) {
    config = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': profileId,
      'booruId': BooruType.szurubooru.id,
      'booruIdHint': BooruType.szurubooru.id,
      'url': 'https://$host',
      'login': 'fixture',
      'apiKey': 'fixture-secret',
    });
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            expect(options.path, '/api/pool/42');
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 42,
                  'posts': posts,
                  'names': names,
                  'category': category,
                  'postCount': count,
                  'description': description,
                },
              ),
            );
          },
        ),
      );
    container = ProviderContainer(
      overrides: [
        szurubooruClientProvider(config.auth)
            .overrideWithValue(SzurubooruClient(dio: dio, baseUrl: config.url)),
        originAwarePostRepoProvider(config).overrideWithValue(repo),
      ],
    );
    final capability = createSzurubooru().createGroupCapability!(
      container.read(_ref),
    );
    source = capability.createSource(
      ContentAccessContext.profile(
        config: config,
        authEpoch: 1,
        policyEpoch: 1,
      ),
    );
    expect(requests, 0);
  }
  late final BooruConfig config;
  late final Dio dio;
  late final ProviderContainer container;
  late final ContentGroupSource source;
  final repo = _Posts();
  int requests = 0;
  ContentReference get group => const ContentReferenceCodec().parse(
    engine: BooruType.szurubooru,
    site: Uri.parse(config.url),
    kind: ContentKind.group,
    sourceKey: 'pool:42',
  );
  Post post(int id) =>
      testPoolPost(id).post.copyWith(origin: postOriginFromConfig(config));
  Future<GroupMemberBatch> members({int? limit, ContentCursor? cursor}) async =>
      (await source
              .loadMembers(
                GroupMemberQuery(
                  reference: group,
                  requestedLimit: limit,
                  cursor: cursor,
                ),
              )
              .run())
          .fold((e) => throw e, (v) => v);
  void dispose() {
    source.dispose();
    container.dispose();
    dio.close(force: true);
  }
}

class _Posts implements PostRepository<Post> {
  final responses = <String, List<Post>>{};
  final queries = <String>[];
  final started = Completer<ApiRequestContext>();
  Completer<PostResult<Post>>? gate;
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.tryCatch(() async {
    queries.add(tags);
    if (gate case final pending?) {
      if (!started.isCompleted) started.complete(ApiRequestContext.current());
      return pending.future;
    }
    return PostResult<Post>(posts: responses[tags] ?? [], total: null);
  }, (e, _) => UnknownError(error: e, message: e.toString()));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
