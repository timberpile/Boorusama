import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/content/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/pools/src/types/group_post_pager.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';

final _group = _reference(ContentKind.group, 'pool:42');
ContentReference _reference(ContentKind kind, String key) =>
    const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: Uri.parse('https://example.test'),
      kind: kind,
      sourceKey: key,
    );

void main() {
  test('raw cursor advances over unresolved page and projects duplicate occurrences', () async {
    final source = _Source();
    final pager = _pager(source);
    addTearDown(pager.dispose);
    final first = pager.fetch(1);
    final r1 = await source.request(0);
    expect(r1.query.cursor, isNull);
    expect(r1.query.requestedLimit, 2);
    expect(r1.query.orderKey, 'order');
    r1.complete(_batch([_member(2, '0')], next: 'page2', total: 3));
    final empty = await first;
    expect(empty.posts, isEmpty);
    expect(empty.hasMore, isTrue);
    final next = pager.fetch(2);
    final r2 = await source.request(1);
    expect(r2.query.cursor?.token, 'page2');
    final post = _post(3);
    r2.complete(
      _batch([_member(3, '1'), _member(3, '2')], posts: [post], total: 3),
    );
    final result = await next;
    expect(result.posts, [same(post), same(post)]);
    expect(result.hasMore, isFalse);
    expect(result.total, 3);
    final exhausted = await pager.fetch(3);
    expect(exhausted.posts, isEmpty);
    expect(exhausted.hasMore, isFalse);
    expect(source.requests, hasLength(2));
  });

  test('overlapping member keys are skipped, distinct occurrences and selection survive', () async {
    final source = _Source();
    final pager = _pager(source);
    addTearDown(pager.dispose);
    final post = _post(3);
    final first = pager.fetch(1);
    (await source.request(0)).complete(
      _batch(
        [_member(3, 'a'), _member(3, 'b')],
        posts: [post],
        next: 'next',
      ),
    );
    final firstResult = await first;
    final firstKeys = pager.selectionKeys(firstResult.posts);
    expect(firstKeys.toSet(), hasLength(2));
    final next = pager.fetch(2);
    (await source.request(1)).complete(
      _batch(
        [_member(3, 'b'), _member(3, 'c')],
        posts: [post],
      ),
    );
    final secondResult = await next;
    expect(secondResult.posts, [same(post)]);
    final keys = pager.selectionKeys([
      ...firstResult.posts,
      ...secondResult.posts,
    ]);
    expect(keys.take(2), firstKeys);
    expect(keys.toSet(), hasLength(3));
  });

  test('missing preceding cursor rejects without requesting source', () async {
    final source = _Source();
    final pager = _pager(source);
    addTearDown(pager.dispose);
    await expectLater(pager.fetch(2), throwsStateError);
    expect(source.requests, isEmpty);
  });

  test(
    'cursor cycle fails while replaying same page and token is allowed',
    () async {
      final source = _Source();
      final pager = _pager(source);
      addTearDown(pager.dispose);
      final p1 = pager.fetch(1);
      (await source.request(0)).complete(_batch([], next: 'a'));
      await p1;
      final p2 = pager.fetch(2);
      (await source.request(1)).complete(_batch([], next: 'b'));
      await p2;
      final replay = pager.fetch(2);
      (await source.request(2)).complete(_batch([], next: 'b'));
      expect((await replay).hasMore, isTrue);
      final p3 = pager.fetch(3);
      (await source.request(3)).complete(_batch([], next: 'a'));
      await expectLater(p3, throwsStateError);
    },
  );

  test(
    'refresh cancels old read, invalidates source and rejects late result',
    () async {
      final source = _Source();
      final pager = _pager(source);
      addTearDown(pager.dispose);
      final initial = pager.fetch(1);
      (await source.request(0)).complete(_batch([], next: 'a'));
      await initial;
      final old = pager.fetch(2);
      final pending = await source.request(1);
      final oldFailure = expectLater(
        old,
        throwsA(isA<RequestCancelledError>()),
      );
      pager.refresh();
      final refresh = pager.fetch(1);
      final fresh = await source.request(2);
      expect(source.invalidations, 1);
      expect(pending.context.cancelToken?.isCancelled, isTrue);
      expect(pending.context.canStart?.call(), isFalse);
      pending.complete(_batch([_member(9, 'stale')], posts: [_post(9)]));
      fresh.complete(_batch([]));
      await oldFailure;
      expect((await refresh).posts, isEmpty);
    },
  );

  test('dispose cancels pending read and rejects late result', () async {
    final source = _Source();
    final pager = _pager(source);
    final pendingFuture = pager.fetch(1);
    final pending = await source.request(0);
    final failure = expectLater(
      pendingFuture,
      throwsA(isA<RequestCancelledError>()),
    );
    pager.dispose();
    await pending.context.cancelToken!.whenCancel;
    expect(pending.context.cancelToken?.isCancelled, isTrue);
    expect(pending.context.canStart?.call(), isFalse);
    pending.complete(_batch([_member(1, 'late')], posts: [_post(1)]));
    await failure;
    await expectLater(pager.fetch(1), throwsA(isA<RequestCancelledError>()));
  });
}

GroupPostPager _pager(_Source source) => GroupPostPager(
  source: source,
  reference: _group,
  perPage: 2,
  orderKey: 'order',
  isCurrent: () => true,
);
GroupMember _member(int id, String key) => GroupMember(
  reference: _reference(ContentKind.post, 'id:$id'),
  memberKey: key,
);
Post _post(int id) => testPoolPost(id).post.copyWith(
  origin: PostOrigin.fromSource(
    booruType: BooruType.danbooru,
    booruId: BooruType.danbooru.id,
    source: 'https://example.test',
  ),
);
GroupMemberBatch _batch(
  List<GroupMember> members, {
  String? next,
  int? total,
  List<Post> posts = const [],
}) => (
  page: ContentPage(
    items: members,
    next: next == null ? null : ContentCursor(next),
    total: total,
  ),
  resolved: <ContentEntry>[
    for (final post in posts)
      PostContentEntry(
        reference: _reference(ContentKind.post, 'id:${post.id}'),
        post: post,
      ),
  ],
);

class _Pending {
  _Pending(this.query, this.context);
  final GroupMemberQuery query;
  final ApiRequestContext context;
  final result = Completer<GroupMemberBatch>();
  void complete(GroupMemberBatch batch) => result.complete(batch);
}

class _Source extends ContentGroupSource {
  @override
  final access = ContentAccessContext.profile(
    config: BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000001',
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': 'https://example.test',
    }),
    authEpoch: 1,
    policyEpoch: 1,
  );
  final requests = <_Pending>[];
  final _signals = <int, Completer<_Pending>>{};
  int invalidations = 0;
  Future<_Pending> request(int index) => index < requests.length
      ? Future.value(requests[index])
      : (_signals[index] ??= Completer<_Pending>()).future;
  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => TaskEither(() async {
    final pending = _Pending(query, ApiRequestContext.current());
    final index = requests.length;
    requests.add(pending);
    _signals.remove(index)?.complete(pending);
    return right(await pending.result.future);
  });
  @override
  void invalidate(ContentReference reference) {
    expect(reference, _group);
    invalidations++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
