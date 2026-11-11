import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/groups/group_envelope_cache.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/errors/types.dart';
import '../../../core/posts/pools/src/types/pool_group_members.dart';
import '../../../core/posts/post/types.dart';
import 'types.dart';

/// Uses Szurubooru's actual Pool envelope and ordered member IDs. It does not
/// infer Danbooru category semantics from a Szurubooru category name.
final class SzurubooruGroupSource extends ContentGroupSource
    implements IndexedGroupMemberSource {
  SzurubooruGroupSource({
    required this.access,
    required this.fetchPool,
    required this.postRepository,
    this.defaultLimit = 20,
  }) : _pools = GroupEnvelopeCache(access: access.key) {
    _members = PoolGroupMembers(
      access: access,
      fetchPosts: (ids) async {
        final result = await posts
            .getPosts('id:${ids.join(',')}', 1, limit: ids.length)
            .run();
        return result.fold((error) => throw error, (result) => result.posts);
      },
    );
  }

  @override
  final ContentAccessContext access;
  final Future<SzurubooruPool?> Function(int id) fetchPool;
  final PostRepository<Post> Function() postRepository;
  PostRepository<Post> get posts => postRepository();
  final int defaultLimit;
  final GroupEnvelopeCache<SzurubooruPool> _pools;
  late final PoolGroupMembers _members;
  var _disposed = false;
  final _cancellation = CancelToken();

  void _require(ContentReference reference) {
    if (_disposed ||
        access.key.engine != BooruType.szurubooru ||
        !access.accepts(reference) ||
        reference.kind != ContentKind.group) {
      throw const FormatException('Unavailable Szurubooru Group source');
    }
    const BooruContentKeyCodec(BooruType.szurubooru)
        .canonicalize(ContentKind.group, reference.sourceKey);
  }

  Future<SzurubooruPool> _pool(ContentReference reference) {
    _require(reference);
    return _pools.load(reference, () async {
      final id = int.parse(reference.sourceKey.split(':').last);
      final pool = await fetchPool(id);
      if (_disposed || pool == null || pool.id != id) {
        throw StateError('Pool unavailable');
      }
      return pool;
    });
  }

  void seedPool(ContentReference reference, SzurubooruPool pool) {
    _require(reference);
    if (reference.sourceKey != 'pool:${pool.id}') {
      throw const FormatException('Foreign Pool seed');
    }
    _pools.seed(reference, pool);
  }

  ContentGroupSummary _summary(
    ContentReference reference,
    SzurubooruPool pool,
  ) => ContentGroupSummary(
    reference: reference,
    title: pool.name,
    memberCount: pool.postCount,
    displayCategory: pool.category,
  );

  BooruError _error(Object error, StackTrace _) => error is BooruError
      ? error
      : UnknownError(error: error, message: 'Unable to load Group');

  TaskEither<BooruError, T> _read<T>(Future<T> Function() read) =>
      TaskEither.tryCatch(
        () => runGroupRead(
          this,
          () => TaskEither.tryCatch(read, _error),
          token: _cancellation,
          current: () => !_disposed,
        ),
        _error,
      );

  @override
  TaskEither<BooruError, ContentGroupSummary> loadSummary(
    ContentReference reference,
  ) => _read(() async => _summary(reference, await _pool(reference)));

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => _read(() async {
    final pool = await _pool(reference);
    return ContentGroupDetails(
      summary: _summary(reference, pool),
      description: pool.description == null
          ? null
          : GroupDescription(
              text: pool.description!,
              format: GroupTextFormat.plainText,
            ),
      sourceDates: GroupSourceDates(
        createdAt: pool.createdAt,
        updatedAt: pool.updatedAt,
      ),
    );
  });

  @override
  TaskEither<BooruError, GroupMemberBatch> loadMembers(
    GroupMemberQuery query,
  ) => _loadMembers(query);

  @override
  TaskEither<BooruError, GroupMemberBatch> loadMemberPage(
    GroupMemberQuery query, {
    required int page,
  }) => _loadMembers(query, indexedPage: page);

  TaskEither<BooruError, GroupMemberBatch> _loadMembers(
    GroupMemberQuery query, {
    int? indexedPage,
  }) => _read(() async {
    if (indexedPage != null && (indexedPage < 1 || query.cursor != null)) {
      throw const FormatException('Invalid indexed Group page');
    }
    final pool = await _pool(query.reference);
    return _members.load(
      query,
      ids: pool.postIds,
      defaultLimit: defaultLimit,
      indexedPage: indexedPage,
    );
  });

  @override
  void invalidate(ContentReference reference) {
    _require(reference);
    _pools.invalidate(reference);
    _members.invalidate(reference);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancellation.cancel('Group source disposed');
    _pools.dispose();
    _members.dispose();
  }
}
