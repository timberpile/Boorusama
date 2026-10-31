import 'dart:async';

import 'package:boorusama/boorus/danbooru/posts/search/src/widgets/search_series_grid.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark.dart';
import 'package:boorusama/core/bookmarks/src/types/pool_bookmark_capability.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/post/providers.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../bookmarks/pool_bookmark_test_utils.dart';

void main() {
  final config = BooruConfig.fromJson({
    ...BooruConfig.empty.toJson(),
    'id': poolProfile,
    'url': 'https://danbooru.donmai.us',
    'booruIdHint': poolOrigin().booruType.id,
  });
  List<Post> posts(int count) => [
    for (var id = 1; id <= count; id++)
      testPoolPost(id).post.copyWith(origin: postOriginFromConfig(config)),
  ];

  test('overlapping admissions coalesce and respect source, account and forty-post budget', () async {
    final index = SearchSeriesIndex();
    addTearDown(index.dispose);
    final capability = _Capability();
    final items = posts(90);
    final first = index.load(config, items, capability);
    final second = index.load(config, items.take(20).toList(), capability);
    expect(capability.calls, hasLength(1));
    expect(capability.calls.single, hasLength(40));
    capability.gate.complete({
      for (final post in items.take(40)) post.id: [_series, _collection],
    });
    await Future.wait([first, second]);
    expect(index.pools(config, items.first), [_series]);
    expect(index.pools(config, items.last), isEmpty);
    expect(
      index.pools(
        BooruConfig.fromJson({...config.toJson(), 'id': poolGroupB}),
        items.first,
      ),
      isEmpty,
    );
    expect(
      index.pools(
        config,
        items.first.copyWith(origin: poolOrigin(host: 'other.example')),
      ),
      isEmpty,
    );
    await index.load(config, items.take(20).toList(), capability);
    expect(capability.calls, hasLength(1));
  });

  test(
    'failed metadata stays ungrouped and a subsequent admission can retry',
    () async {
      final index = SearchSeriesIndex();
      addTearDown(index.dispose);
      final capability = _Capability();
      final items = posts(2);
      final failed = index.load(config, items, capability);
      capability.gate.completeError(StateError('offline'));
      await failed;
      expect(index.pools(config, items.first), isEmpty);
      capability.gate = Completer();
      final retry = index.load(config, items, capability);
      capability.gate.complete({
        1: [_series],
        2: [_series],
      });
      await retry;
      expect(index.pools(config, items.first), [_series]);
      expect(capability.calls, hasLength(2));
    },
  );

  test(
    'a disposed search rejects delayed metadata without notifying a new view',
    () async {
      final index = SearchSeriesIndex();
      final capability = _Capability();
      var notifications = 0;
      index.addListener(() => notifications++);
      final items = posts(2);
      final pending = index.load(config, items, capability);
      index.dispose();
      capability.gate.complete({
        1: [_series],
        2: [_series],
      });
      await pending;
      expect(notifications, 0);
      expect(index.pools(config, items.first), isEmpty);
    },
  );
}

const _series = RemoteBookmarkPool(
  id: 10,
  title: 'Confirmed Series',
  category: BookmarkedPoolCategory.series,
  total: 20,
);
const _collection = RemoteBookmarkPool(
  id: 11,
  title: 'Collection',
  category: BookmarkedPoolCategory.collection,
  total: 200,
);

class _Capability implements PoolBookmarkCapability {
  final calls = <List<Post>>[];
  Completer<Map<int, List<RemoteBookmarkPool>>> gate = Completer();
  @override
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  ) {
    calls.add(posts);
    return gate.future;
  }

  @override
  Future<RemoteBookmarkPool?> getBookmarkPool(
    BooruConfig config,
    int id,
  ) async => _series;
  @override
  Future<void> openBookmarkPool(
    WidgetRef ref,
    BooruConfig config,
    int id,
  ) async {}
}
