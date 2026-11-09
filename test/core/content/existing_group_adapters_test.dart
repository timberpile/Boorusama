import 'package:boorusama/boorus/danbooru/posts/post/providers.dart';
import 'package:booru_clients/danbooru.dart';
import 'package:boorusama/boorus/danbooru/client_provider.dart';
import 'package:boorusama/boorus/danbooru/danbooru.dart';
import 'package:boorusama/boorus/szurubooru/szurubooru.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../bookmarks/pool_bookmark_test_utils.dart';

final _ref = Provider<Ref>((ref) => ref);

void main() {
  test('production engines register Group capabilities', () {
    expect(
      createDanbooru().createGroupCapability,
      isNotNull,
      reason: 'Danbooru must expose its registered Group capability',
    );
    expect(
      createSzurubooru().createGroupCapability,
      isNotNull,
      reason: 'Szurubooru must expose its registered Group capability',
    );
  });

  test(
    'manifest positions survive shuffled partial batches and duplicates',
    () async {
      final f = _Fixture(postIds: [3, 2, 3, 1]);
      addTearDown(f.dispose);
      f.repo.responses['id:3,2'] = [f.post(3)];
      f.repo.responses['id:1'] = [f.post(1)];
      final first = await f.members(limit: 2);
      expect(first.page.items.map((m) => m.reference.sourceKey), [
        'id:3',
        'id:2',
      ]);
      expect(first.page.items.map((m) => m.sourcePosition), [0, 1]);
      expect(first.page.items[1].availability, MemberAvailability.unknown);
      expect(first.resolved, hasLength(1));
      expect(first.page.next, isNotNull);
      final second = await f.members(limit: 2, cursor: first.page.next);
      expect(second.page.items.map((m) => m.reference.sourceKey), [
        'id:3',
        'id:1',
      ]);
      expect(second.page.items.map((m) => m.sourcePosition), [2, 3]);
      expect(
        {
          ...first.page.items,
          ...second.page.items,
        }.map((m) => m.memberKey).toSet(),
        hasLength(4),
      );
      expect(second.resolved, hasLength(2));
      expect(second.page.next, isNull);
      expect(f.repo.queries, ['id:3,2', 'id:1']);
      expect(
        (second.resolved.first as PostContentEntry).post,
        same((first.resolved.single as PostContentEntry).post),
      );
    },
  );

  test(
    'empty resolved first batch continues; duplicate hydration is unique',
    () async {
      final f = _Fixture(postIds: [2, 2, 3, 3]);
      addTearDown(f.dispose);
      f.repo.responses['id:3'] = [f.post(3)];
      final first = await f.members(limit: 2);
      expect(first.resolved, isEmpty);
      expect(first.page.next, isNotNull);
      final second = await f.members(limit: 2, cursor: first.page.next);
      expect(second.page.items, hasLength(2));
      expect(second.page.items.map((m) => m.memberKey).toSet(), hasLength(2));
      expect(second.resolved, hasLength(1));
    },
  );

  for (final order in ['order', 'oldest', 'latest']) {
    test('Pool $order preserves original source positions', () async {
      final f = _Fixture(postIds: [3, 1, 2]);
      addTearDown(f.dispose);
      final ids = switch (order) {
        'oldest' => [1, 2, 3],
        'latest' => [3, 2, 1],
        _ => [3, 1, 2],
      };
      final positions = switch (order) {
        'oldest' => [1, 2, 0],
        'latest' => [0, 2, 1],
        _ => [0, 1, 2],
      };
      f.repo.responses['id:${ids.join(',')}'] = ids.map(f.post).toList();
      final batch = await f.members(order: order, limit: 3);
      expect(
        batch.page.items.map((m) => m.reference.sourceKey),
        ids.map((id) => 'id:$id'),
      );
      expect(batch.page.items.map((m) => m.sourcePosition), positions);
    });
  }

  test('same group ID remains isolated across accounts', () async {
    final first = _Fixture(postIds: [1]);
    final second = _Fixture(
      postIds: [2],
      profileId: '00000000-0000-4000-8000-000000000002',
    );
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final a = await first.members();
    final b = await second.members();
    expect(first.group.identity, second.group.identity);
    expect(first.source.access.key, isNot(second.source.access.key));
    expect(a.page.items.single.reference.sourceKey, 'id:1');
    expect(b.page.items.single.reference.sourceKey, 'id:2');
    expect(first.poolRequests, 1);
    expect(second.poolRequests, 1);
  });

  test('unknown manifest is an error while known empty is exhausted', () async {
    final unknown = _Fixture();
    final empty = _Fixture(postIds: []);
    addTearDown(unknown.dispose);
    addTearDown(empty.dispose);
    final failure = await unknown.source
        .loadMembers(GroupMemberQuery(reference: unknown.group))
        .run();
    expect(failure.fold((_) => true, (_) => false), isTrue);
    final batch = await empty.members();
    expect(batch.page.items, isEmpty);
    expect(batch.page.next, isNull);
    expect(batch.page.total, 0);
    expect(empty.repo.queries, isEmpty);
  });

  test(
    'summary and details share envelope and preserve native metadata',
    () async {
      final f = _Fixture(postIds: [1], category: 'series');
      addTearDown(f.dispose);
      final values = await Future.wait([
        f.source.loadSummary(f.group).run(),
        f.source.loadDetails(f.group).run(),
      ]);
      final summary =
          values[0].fold((e) => throw e, (v) => v) as ContentGroupSummary;
      final details =
          values[1].fold((e) => throw e, (v) => v) as ContentGroupDetails;
      expect(f.poolRequests, 1);
      expect(summary.memberCount, isNull);
      expect(summary.displayCategory, 'series');
      expect(summary.reference, f.group);
      expect(details.description?.text, 'description');
      final other = _Fixture(postIds: [1], category: 'collection');
      addTearDown(other.dispose);
      final changed = (await other.source.loadSummary(other.group).run()).fold(
        (e) => throw e,
        (v) => v,
      );
      expect(changed.reference.identity, summary.reference.identity);
      expect(changed.displayCategory, 'collection');
    },
  );

  for (final order in ['oldest', 'newest']) {
    test(
      'Related $order uses direct family query and no source positions',
      () async {
        final f = _Fixture();
        addTearDown(f.dispose);
        final query =
            'parent:10 order:id_${order == 'oldest' ? 'asc' : 'desc'}';
        f.repo.responses[query] = [
          f.related(10),
          f.related(11, parent: 10),
          f.related(99, parent: 42),
        ];
        final batch = await f.members(
          reference: f.reference('related:10'),
          order: order,
        );
        expect(f.repo.queries, [query]);
        expect(batch.page.items.map((m) => m.reference.sourceKey), [
          'id:10',
          'id:11',
        ]);
        expect(
          batch.page.items.map((m) => m.sourcePosition),
          everyElement(isNull),
        );
        expect(batch.resolved, hasLength(2));
      },
    );
  }

  test('rejects foreign site and malformed cursor without fetching', () async {
    final f = _Fixture(postIds: [1]);
    addTearDown(f.dispose);
    final foreign = f.reference('pool:42', host: 'other.test');
    final foreignResult = await f.source
        .loadMembers(GroupMemberQuery(reference: foreign))
        .run();
    expect(foreignResult.fold((_) => true, (_) => false), isTrue);
    final invalid = await f.source
        .loadMembers(
          GroupMemberQuery(
            reference: f.group,
            cursor: ContentCursor('invalid-cursor'),
          ),
        )
        .run();
    expect(invalid.fold((_) => true, (_) => false), isTrue);
    expect(f.repo.queries, isEmpty);
  });
}

class _Fixture {
  _Fixture({
    List<int>? postIds,
    String category = 'series',
    String profileId = '00000000-0000-4000-8000-000000000001',
  }) {
    config = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': profileId,
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': 'https://example.test',
      'login': 'fixture',
      'apiKey': 'fixture-secret',
    });
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            poolRequests++;
            expect(options.path, '/pools/42.json');
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'id': 42,
                  'name': 'Fixture',
                  'description': 'description',
                  'category': category,
                  'post_count': null,
                  'post_ids': postIds,
                },
              ),
            );
          },
        ),
      );
    container = ProviderContainer(
      overrides: [
        danbooruClientProvider(config.auth)
            .overrideWithValue(DanbooruClient(baseUrl: config.url, dio: dio)),
        originAwarePostRepoProvider(config).overrideWithValue(repo),
        danbooruPostRepoProvider(config.search).overrideWithValue(repo),
      ],
    );
    final capability = createDanbooru().createGroupCapability!(
      container.read(_ref),
    );
    expect(poolRequests, 0, reason: 'capability factory must be lazy');
    source = capability.createSource(
      container.read(_ref),
      ContentAccessContext.profile(
        config: config,
        authEpoch: 1,
        policyEpoch: 1,
      ),
    );
    expect(poolRequests, 0, reason: 'source factory must be lazy');
  }
  late final BooruConfig config;
  late final Dio dio;
  late final ProviderContainer container;
  late final ContentGroupSource source;
  final repo = _Posts();
  int poolRequests = 0;
  ContentReference get group => reference('pool:42');
  ContentReference reference(String key, {String host = 'example.test'}) =>
      const ContentReferenceCodec().parse(
        engine: BooruType.danbooru,
        site: Uri.parse('https://$host'),
        kind: ContentKind.group,
        sourceKey: key,
      );
  Post post(int id) =>
      testPoolPost(id).post.copyWith(origin: postOriginFromConfig(config));
  Post related(int id, {int? parent}) => testRelatedPost(
    id,
    parent: parent,
  ).copyWith(origin: postOriginFromConfig(config));
  Future<GroupMemberBatch> members({
    ContentReference? reference,
    String? order,
    int? limit,
    ContentCursor? cursor,
  }) async =>
      (await source
              .loadMembers(
                GroupMemberQuery(
                  reference: reference ?? group,
                  orderKey: order,
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
  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither.tryCatch(() async {
    queries.add(tags);
    return PostResult<Post>(posts: responses[tags] ?? [], total: null);
  }, (e, _) => UnknownError(error: e, message: e.toString()));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
