import '../../../core/configs/config/types.dart';

import 'dart:async';

import '../../../core/content/groups/owned_read_cache.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/groups/group_envelope_cache.dart';
import '../../../core/content/groups/group_source_provider.dart';
import '../../../core/content/types.dart';
import '../../../core/errors/types.dart';
import '../../../core/posts/pools/src/types/pool_group_members.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/posts/related/related_family.dart';
import '../../../core/posts/related/related_posts_order_value.dart';
import 'pool/types.dart';

/// Danbooru owns Pool manifests and direct Related-family query semantics. The
/// shared contracts carry those values without changing either gallery layout.
final class DanbooruGroupSource extends ContentGroupSource
    implements IndexedGroupMemberSource {
  DanbooruGroupSource({
    required this.access,
    required this.fetchPool,
    required this.postRepository,
    this.defaultLimit = 20,
    this.fetchPoolPosts,
    this.fetchRelatedList,
    this.fetchRelatedCount,
    this.poolAccessibleCount,
    this.consumeMembers,
  }) : _pools = GroupEnvelopeCache(access: access.key) {
    _poolMembers = PoolGroupMembers(
      access: access,
      accessibleTotal: poolAccessibleCount,
      fetchPosts: (ids) async {
        if (fetchPoolPosts != null) return fetchPoolPosts!(ids);
        final result = await posts
            .getPosts(
              'id:${ids.join(',')}',
              1,
              limit: ids.length,
              options: PostFetchOptions.raw,
            )
            .run();
        return result.fold(
          (error) => throw error,
          (result) => result.posts
              .where(
                (post) =>
                    !post.isFlash &&
                    !(access
                            .config!
                            .search
                            .filter
                            .bannedPostVisibility
                            .isHidden &&
                        (post.status?.matches('banned') ?? false)),
              )
              .toList(),
        );
      },
    );
  }

  @override
  final ContentAccessContext access;
  final Future<List<Post>> Function(List<int>)? fetchPoolPosts;
  final Future<PostResult<Post>> Function(String, int, int)? fetchRelatedList;
  final Future<int?> Function(String)? fetchRelatedCount;
  final int? Function(List<int>)? poolAccessibleCount;
  final Future<void> Function(List<Post>)? consumeMembers;
  @override
  void didConsumeMembers(List<Post> posts) {
    final consume = consumeMembers;
    if (consume != null) unawaited(consume(posts));
  }

  final _relatedLists =
      OwnedReadCache<(ContentReference, String, int, int), PostResult<Post>>();
  final _relatedCounts = OwnedReadCache<ContentReference, int?>();
  final _relatedKeys =
      <ContentReference, Set<(ContentReference, String, int, int)>>{};
  final Future<DanbooruPool?> Function(int id) fetchPool;
  final PostRepository<Post> Function() postRepository;
  PostRepository<Post> get posts => postRepository();
  final int defaultLimit;
  final GroupEnvelopeCache<DanbooruPool> _pools;
  late final PoolGroupMembers _poolMembers;
  final _cursorScope = const Uuid().v4();
  var _disposed = false;
  final _cancellation = CancelToken();

  void _require(ContentReference reference) {
    if (_disposed ||
        access.key.engine != BooruType.danbooru ||
        !access.accepts(reference) ||
        reference.kind != ContentKind.group) {
      throw const FormatException('Unavailable Danbooru Group source');
    }
    const BooruContentKeyCodec(BooruType.danbooru)
        .canonicalize(ContentKind.group, reference.sourceKey);
  }

  Future<DanbooruPool> _pool(ContentReference reference) {
    _require(reference);
    if (!reference.sourceKey.startsWith('pool:')) {
      throw const FormatException('Not a Danbooru Pool');
    }
    return _pools.load(reference, () async {
      final id = int.parse(reference.sourceKey.split(':').last);
      final value = await fetchPool(id);
      if (_disposed || value == null || value.id != id) {
        throw StateError('Pool unavailable');
      }
      return value;
    });
  }

  void seedPool(ContentReference reference, DanbooruPool pool) {
    _require(reference);
    if (reference.sourceKey != 'pool:${pool.id}') {
      throw const FormatException('Foreign Pool seed');
    }
    _pools.seed(reference, pool);
  }

  ContentGroupSummary _summary(ContentReference reference, DanbooruPool pool) =>
      ContentGroupSummary(
        reference: reference,
        title: pool.name,
        memberCount: poolAccessibleCount == null
            ? pool.postCount
            : (pool.manifestComplete && pool.postIds != null
                  ? poolAccessibleCount!(pool.postIds!)
                  : null),
        displayCategory: switch (pool.category) {
          DanbooruPoolCategory.series => 'series',
          DanbooruPoolCategory.collection => 'collection',
          _ => null,
        },
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
  ) => _read(() async {
    _require(reference);
    if (reference.sourceKey.startsWith('related:')) {
      return ContentGroupSummary(reference: reference);
    }
    return _summary(reference, await _pool(reference));
  });

  @override
  TaskEither<BooruError, ContentGroupDetails> loadDetails(
    ContentReference reference,
  ) => _read(() async {
    _require(reference);
    if (reference.sourceKey.startsWith('related:')) {
      return ContentGroupDetails(
        summary: ContentGroupSummary(reference: reference),
      );
    }
    final pool = await _pool(reference);
    return ContentGroupDetails(
      summary: _summary(reference, pool),
      description: pool.description == null
          ? null
          : GroupDescription(
              text: pool.description!,
              format: GroupTextFormat.dtext,
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
    _require(query.reference);
    if (query.reference.sourceKey.startsWith('pool:')) {
      final pool = await _pool(query.reference);
      return _poolMembers.load(
        query,
        ids: pool.postIds,
        defaultLimit: defaultLimit,
        indexedPage: indexedPage,
        exactTotalAllowed: pool.manifestComplete,
      );
    }
    final order = switch (query.orderKey) {
      null || 'oldest' => RelatedPostsOrder.oldest,
      'newest' => RelatedPostsOrder.newest,
      _ => throw const FormatException('Unsupported Related order'),
    };
    var page = indexedPage ?? 1;
    var limit = (query.requestedLimit ?? defaultLimit).clamp(1, 200);
    if (query.cursor case final cursor?) {
      final value = jsonDecode(cursor.token);
      if (value is! List ||
          value.length != 6 ||
          value[0] != _cursorScope ||
          value[1] != query.reference.sourceKey ||
          value[2] != order.name ||
          value[3] is! int ||
          value[4] is! int ||
          value[5] != 1) {
        throw const FormatException('Invalid Related cursor');
      }
      page = value[3] as int;
      limit = value[4] as int;
      if (page < 2 ||
          limit < 1 ||
          limit > 200 ||
          (query.requestedLimit != null &&
              query.requestedLimit!.clamp(1, 200) != limit)) {
        throw const FormatException('Invalid Related cursor range');
      }
    }
    final family = RelatedFamilyReference(
      origin: PostOrigin.fromSource(
        booruType: BooruType.danbooru,
        booruId: BooruType.danbooru.id,
        source: query.reference.site.toString(),
      ),
      anchorId: int.parse(query.reference.sourceKey.split(':').last),
    );
    final text = '${family.query} ${order.queryOrder}';
    final readList = fetchRelatedList;
    final PostResult<Post> result;
    if (readList == null) {
      result = await posts
          .getPosts(text, page, limit: limit, options: PostFetchOptions.raw)
          .run()
          .then((r) => r.fold((e) => throw e, (r) => r));
    } else {
      final key = (query.reference, order.name, page, limit);
      _relatedKeys.putIfAbsent(query.reference, () => {}).add(key);
      final list = await _relatedLists.load(
        key,
        () => readList(text, page, limit),
      );
      // A thrown count read leaves the list reusable for foreground count-only
      // retry. A completed unknown/invalid count remains a successful result.
      final count =
          list.total ??
          (fetchRelatedCount == null
              ? null
              : await _relatedCounts.load(
                  query.reference,
                  () => fetchRelatedCount!(family.query),
                ));
      final unique =
          list.rawUniquePostCount ?? list.posts.map((p) => p.id).toSet().length;
      result = list.copyWith(
        total: () =>
            count != null && count >= unique && count >= 0 ? count : null,
        hasMore: () => page == 1 && count != null && count == unique
            ? false
            : list.hasMore,
      );
    }
    if (_disposed) throw StateError('Related source disposed');
    final hydrated = <ContentIdentity, PostContentEntry>{};
    for (final post in result.posts.where(family.contains)) {
      final reference = const ContentReferenceCodec().fromPost(
        post,
        site: query.reference.site,
      );
      if (reference != null) {
        hydrated.putIfAbsent(
          reference.identity,
          () => PostContentEntry(reference: reference, post: post),
        );
      }
    }
    final rawCount = result.rawPostCount;
    final countProvesMore =
        page == 1 &&
        result.total != null &&
        rawCount != null &&
        result.total! > rawCount;
    final more =
        result.hasMore ??
        (result.maxPage != null
            ? page < result.maxPage!
            : countProvesMore || (rawCount ?? result.posts.length) >= limit);
    return (
      page: ContentPage(
        items: [
          for (final entry in hydrated.values)
            GroupMember(
              reference: entry.reference,
              memberKey: 'post:${entry.reference.sourceKey}',
              availability: MemberAvailability.available,
            ),
        ],
        total: result.total,
        next: !more
            ? null
            : ContentCursor(
                jsonEncode([
                  _cursorScope,
                  query.reference.sourceKey,
                  order.name,
                  page + 1,
                  limit,
                  1,
                ]),
              ),
      ),
      resolved: hydrated.values.toList(growable: false),
    );
  });

  @override
  void invalidate(ContentReference reference) {
    _require(reference);
    _pools.invalidate(reference);
    _relatedCounts.invalidate(reference);
    (_relatedKeys.remove(reference) ?? {}).forEach(_relatedLists.invalidate);
    _poolMembers.invalidate(reference);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancellation.cancel('Group source disposed');
    _pools.dispose();
    _relatedLists.dispose();
    _relatedCounts.dispose();
    _poolMembers.dispose();
  }
}
