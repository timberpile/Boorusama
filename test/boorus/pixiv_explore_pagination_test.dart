import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/explore/feed.dart';
import 'package:boorusama/boorus/pixiv/explore/providers.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_duplicate_checker.dart';
import 'package:boorusama/core/posts/listing/src/widgets/post_grid_controller.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final feeds = [
    (
      name: 'Ranking',
      feed: PixivRankingFeed(
        mode: PixivRankingMode.day,
        date: DateTime.utc(2024, 3, 9),
      ),
    ),
    (
      name: 'Following',
      feed: const PixivFollowingFeed(restrict: PixivFollowRestrict.private),
    ),
    (name: 'Recommended', feed: const PixivRecommendedFeed()),
  ];

  for (final entry in feeds) {
    for (final filtered in [false, true]) {
      test(
        '${entry.name}: empty page retains continuation ($filtered)',
        () async {
          final harness = _Harness([
            _Reply.page(
              illusts: filtered ? [_illust(1, visible: false)] : [],
              more: true,
            ),
            _Reply.page(illusts: [_illust(2)], more: false),
          ]);
          final controller = harness.controller(entry.feed);

          await controller.refresh();
          expect(controller.errors.value, isNull);
          expect(controller.items, isEmpty);
          expect(controller.hasMore, isTrue);

          await controller.fetchMore();
          expect(controller.items.map((post) => post.id), [2000]);
          expect(controller.items.single.origin, _origin);
          expect(controller.hasMore, isFalse);
          await controller.fetchMore();
          expect(harness.adapter.offsets, [0, 30]);
        },
      );
    }

    test('${entry.name}: a nonempty terminal page stops requests', () async {
      final harness = _Harness([
        _Reply.page(illusts: [_illust(1)], more: false),
      ]);
      final controller = harness.controller(entry.feed);

      await controller.refresh();
      expect(controller.items, hasLength(1));
      expect(controller.hasMore, isFalse);
      await controller.fetchMore();
      expect(harness.adapter.offsets, [0]);
    });

    test(
      '${entry.name}: refresh can extend a previously exhausted feed',
      () async {
        final harness = _Harness([
          _Reply.page(illusts: [_illust(1)], more: false),
          _Reply.page(illusts: [_illust(10)], more: true),
          _Reply.page(illusts: [_illust(11)], more: false),
        ]);
        final controller = harness.controller(entry.feed);

        await controller.refresh();
        expect(controller.hasMore, isFalse);
        await controller.refresh();
        expect(controller.hasMore, isTrue);
        await controller.fetchMore();
        expect(controller.items.map((post) => post.id), [10000, 11000]);
        expect(controller.hasMore, isFalse);
        expect(harness.adapter.offsets, [0, 0, 30]);
      },
    );

    test('${entry.name}: a failed page retries its original offset', () async {
      final harness = _Harness([
        _Reply.page(illusts: [_illust(1)], more: true),
        _Reply.failure(),
        _Reply.page(illusts: [_illust(2)], more: false),
      ]);
      final controller = harness.controller(entry.feed);

      await controller.refresh();
      await controller.fetchMore();
      expect(controller.errors.value, isNotNull);
      expect(controller.page, 1);
      expect(controller.hasMore, isTrue);
      await controller.fetchMore();
      expect(controller.errors.value, isNull);
      expect(controller.items.map((post) => post.id), [1000, 2000]);
      expect(harness.adapter.offsets, [0, 30, 30]);
    });
  }

  test('a stale terminal reply cannot poison a new feed session', () async {
    final old = _Reply();
    final harness = _Harness([
      old,
      _Reply.page(illusts: [_illust(10)], more: true),
      _Reply.page(illusts: [_illust(11)], more: false),
    ]);
    const feed = PixivRecommendedFeed();
    final stale = harness.fetch(feed, 1);
    await old.started.future;

    final current = await harness.fetch(feed, 1);
    expect(current.hasMore, isTrue);
    old.complete(illusts: [_illust(1)], more: false);
    await stale;
    final next = await harness.fetch(feed, 2);
    expect(next.posts.map((post) => post.id), [11000]);
    expect(harness.adapter.offsets, [0, 0, 30]);
  });

  test('independent feeds retain their own continuation signals', () async {
    final harness = _Harness([
      _Reply.page(illusts: [_illust(1)], more: false),
      _Reply.page(illusts: [], more: true),
      _Reply.page(illusts: [_illust(2)], more: false),
    ]);
    final recommended = harness.controller(const PixivRecommendedFeed());
    final following = harness.controller(const PixivFollowingFeed());

    await recommended.refresh();
    await following.refresh();
    expect(recommended.hasMore, isFalse);
    expect(following.hasMore, isTrue);
    await following.fetchMore();
    expect(following.items.map((post) => post.id), [2000]);
    expect(recommended.items.map((post) => post.id), [1000]);
  });
}

final _origin = PostOrigin.fromSource(
  booruType: BooruType.pixiv,
  booruId: BooruType.pixiv.id,
  source: 'https://pixiv.example',
  profileIdHint: '00000000-0000-4000-8000-00000000002a',
);

Map<String, Object?> _illust(int id, {bool visible = true}) => {
  'id': id,
  'type': 'illust',
  'visible': visible,
  'user': {'id': 7},
  'page_count': 1,
  'meta_single_page': {
    'original_image_url': 'https://i.pximg.net/img-original/${id}_p0.jpg',
  },
  'create_date': '2024-03-09T12:00:00+09:00',
};

class _Harness {
  _Harness(List<_Reply> replies) : adapter = _Adapter(replies) {
    final dio = Dio(BaseOptions(baseUrl: 'https://app-api.pixiv.net'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    repo = PixivExploreRepository(
      client: PixivClient(dio: dio, accessToken: 'synthetic-token'),
      origin: _origin,
    );
  }

  final _Adapter adapter;
  late final PixivExploreRepository repo;

  PostGridController<Post> controller(PixivExploreFeed feed) {
    final controller = PostGridController<Post>(
      fetcher: (page) => repo.getPosts(
        feed: feed,
        page: page,
        now: DateTime.utc(2024, 3, 10, 12),
      ),
      blacklistedTagsFetcher: () async => {},
      mountedChecker: () => true,
      duplicateTracker: PostDuplicateTracker<Post>(),
      onError: (_) {},
      debounceDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<PostResult<Post>> fetch(PixivExploreFeed feed, int page) async =>
      (await repo.getPosts(feed: feed, page: page).run()).fold(
        (error) => throw StateError('Unexpected error: $error'),
        (value) => value,
      );
}

class _Reply {
  _Reply();

  _Reply.page({
    required List<Map<String, Object?>> illusts,
    required bool more,
  }) {
    complete(illusts: illusts, more: more);
  }

  _Reply.failure() {
    response.complete(ResponseBody.fromString('{}', 503));
  }

  final started = Completer<void>();
  final response = Completer<ResponseBody>();

  void complete({
    required List<Map<String, Object?>> illusts,
    required bool more,
  }) {
    response.complete(
      ResponseBody.fromString(
        jsonEncode({
          'illusts': illusts,
          'next_url': more
              ? 'https://app-api.pixiv.net/v1/illust/recommended?offset=30'
              : null,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(Iterable<_Reply> replies) : replies = Queue.of(replies);

  final Queue<_Reply> replies;
  final requests = <RequestOptions>[];
  List<Object?> get offsets => [
    for (final request in requests) request.queryParameters['offset'],
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    if (replies.isEmpty) throw StateError('Unexpected extra page request');
    final reply = replies.removeFirst();
    reply.started.complete();
    return reply.response.future;
  }

  @override
  void close({bool force = false}) {}
}
