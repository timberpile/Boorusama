import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/errors/types.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/posts/rating/types.dart';
import 'package:boorusama/core/posts/sources/types.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:foundation/foundation.dart';
import 'package:hive_ce/hive.dart';

HiveSearchSubscriptionRepository memorySubscriptionRepository() =>
    HiveSearchSubscriptionRepository(
      box: MemorySubscriptionBox(),
      organizationBox: MemoryBox<dynamic>(),
    );

class MemorySubscriptionBox extends MemoryBox<SearchSubscriptionHiveObject> {}

class MemoryBox<T> implements Box<T> {
  final _items = <dynamic, T>{};

  @override
  Iterable<T> get values => _items.values;

  @override
  T? get(
    dynamic key, {
    T? defaultValue,
  }) => _items[key] ?? defaultValue;

  @override
  bool containsKey(dynamic key) => _items.containsKey(key);

  @override
  Future<void> put(dynamic key, T value) async {
    _items[key] = value;
  }

  @override
  Future<void> putAll(
    Map<dynamic, T> entries,
  ) async {
    for (final entry in entries.entries) {
      _items[entry.key] = entry.value;
    }
  }

  @override
  Future<void> delete(dynamic key) async {
    _items.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    keys.toList().forEach(_items.remove);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestSearchPostRepository extends PostRepository<Post> {
  TestSearchPostRepository(this.fetch);

  final Future<Either<BooruError, PostResult<Post>>> Function(
    String query,
    int page,
    int? limit,
  )
  fetch;

  @override
  PostsOrError<Post> getPosts(
    String tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
  }) => TaskEither(() => fetch(tags, page, limit));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Post TestSearchPost(int id, DateTime? createdAt) => Post(
  origin: PostOrigin.forBooruType(BooruType.unknown),
  core: PostCoreData(
    id: id,
    createdAt: createdAt,
    thumbnailImageUrl: 'https://example.com/$id-thumb.jpg',
    sampleImageUrl: 'https://example.com/$id.jpg',
    originalImageUrl: '',
    tags: const {},
    rating: Rating.general,
    hasComment: false,
    isTranslated: false,
    hasParentOrChildren: false,
    source: PostSource.none(),
    score: 0,
    duration: 0,
    fileSize: 0,
    format: 'jpg',
    hasSound: null,
    height: 0,
    md5: '',
    videoThumbnailUrl: '',
    videoUrl: '',
    width: 0,
    uploaderId: null,
    metadata: null,
  ),
  booruData: const LegacyPostData(typeKey: 'test_search', custom: {}),
);
