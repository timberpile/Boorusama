import 'package:booru_clients/gelbooru.dart' as gel;
import 'package:boorusama/boorus/gelbooru/posts/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty filtered page retains source continuation', () async {
    final result = await _Client(25).getPostResults([], 1, limit: 10);
    expect(result.posts, isEmpty);
    expect(result.hasMore, isTrue);
  });

  test('a later terminal page ends before the search-depth cap', () async {
    final result = await _Client(25).getPostResults([], 3, limit: 10);
    expect(result.hasMore, isFalse);
    expect(result.maxPage, greaterThan(3));
  });

  test('zero total is terminal despite a larger cap', () async {
    final result = await _Client(0).getPostResults([], 1, limit: 10);
    expect(result.hasMore, isFalse);
  });

  test('the accessible search cap still bounds a larger total', () async {
    final result = await _Client(100000).getPostResults([], 3999, limit: 10);
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
  }) async => (posts: <gel.PostDto>[], count: count);
}
