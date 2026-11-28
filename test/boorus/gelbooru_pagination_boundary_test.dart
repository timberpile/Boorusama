import 'dart:async';

import 'package:booru_clients/gelbooru.dart' as gel;
import 'package:boorusama/boorus/gelbooru/posts/pagination.dart';
import 'package:boorusama/boorus/gelbooru/posts/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a pre-refresh boundary response cannot replace a newer cursor',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final client = _GatedClient(started, release);
      final cursors = GelbooruPageCursors();
      Future<void> read(int page) async {
        await client.getPostResults(
          ['cat'],
          page,
          limit: 1000,
          cursors: cursors,
        );
      }

      final stale = read(11);
      await started.future;
      await read(1);
      await read(11);
      release.complete();
      await stale;
      await read(12);
      expect(client.lastTags, ['cat', 'id:<1200']);
      expect(client.lastLimit, 100);
    },
  );

  test('an empty filtered page retains source continuation', () async {
    final result = await _Client(25).getPostResults([], 1, limit: 10);
    expect(result.posts, isEmpty);
    expect(result.hasMore, isTrue);
  });

  test('a later terminal page ends before the search-depth cap', () async {
    final result = await _Client(25).getPostResults([], 3, limit: 10);
    expect(result.hasMore, isFalse);
    expect(result.rawPostCount, 0);
  });

  test('zero total is terminal despite a larger cap', () async {
    final result = await _Client(0).getPostResults([], 1, limit: 10);
    expect(result.hasMore, isFalse);
  });

  test(
    'unknown source totals do not manufacture continuation metadata',
    () async {
      final result = await _Client(null).getPostResults([], 2, limit: 10);
      expect(result.hasMore, isNull);
    },
  );
}

class _Client extends gel.GelbooruClient {
  _Client(this.count) : super(baseUrl: 'https://example.invalid/');
  final int? count;

  @override
  Future<gel.GelbooruPosts> getPosts({
    int? page,
    int? limit,
    List<String>? tags,
  }) async =>
      (posts: <gel.PostDto>[], count: count, lastId: null, rawIds: <int?>[]);
}

class _GatedClient extends gel.GelbooruClient {
  _GatedClient(this.started, this.release);
  final Completer<void> started;
  final Completer<void> release;
  List<String>? lastTags;
  int? lastLimit;
  final ids = [1100, 2200, 1200, 1000].iterator;

  @override
  Future<gel.GelbooruPosts> getPosts({
    int? page,
    int? limit,
    List<String>? tags,
  }) async {
    lastTags = tags;
    lastLimit = limit;
    expect(ids.moveNext(), isTrue);
    final id = ids.current;
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return (posts: <gel.PostDto>[], count: 3000, rawIds: [id], lastId: id);
  }
}
