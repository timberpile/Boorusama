// Package imports:
import 'package:booru_clients/gelbooru.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/post/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/settings/providers.dart';
import '../../../core/settings/src/types/utils.dart';
import '../client_provider.dart';
import '../tags/providers.dart';
import 'parser.dart';
import 'pagination.dart';

final gelbooruPostRepoProvider =
    Provider.family<PostRepository<Post>, BooruConfigSearch>(
      (ref, config) {
        final client = ref.watch(gelbooruClientProvider(config.auth));
        final tagComposer = ref.watch(gelbooruTagQueryComposerProvider(config));
        final cursors = GelbooruPageCursors();

        return PostRepositoryBuilder(
          tagComposer: tagComposer,
          fetch: (tags, page, {limit, options}) => client.getPostResults(
            tags,
            page,
            limit: limit,
            options: options,
            cursors: cursors,
          ),
          fetchSingle: (id, {options}) async {
            final numericId = id as NumericPostId?;

            if (numericId == null) return Future.value();

            final post = await client.getPost(numericId.value);

            return post != null
                ? gelbooruPostDtoToGelbooruPost(post, null)
                : null;
          },
          getSettings: () async =>
              ref.read(listingSettingsForAuthProvider(config.auth)),
        );
      },
    );

extension GelbooruClientX on GelbooruClient {
  Future<PostResult<Post>> getPostResults(
    List<String> tags,
    int page, {
    int? limit,
    PostFetchOptions? options,
    GelbooruPageCursors? cursors,
  }) async {
    if (page <= 0 || (limit != null && limit <= 0)) {
      throw ArgumentError('Page and limit must be positive');
    }
    final pageSize = effectivePostsPerPage(
      BooruType.gelbooru,
      limit ?? _kGelbooruDefaultLimit,
    );
    final useCursor = options?.useCursor ?? false;
    if ((useCursor, cursors, GelbooruIdPagination.fromTags(tags)) case (
      false,
      final cursors?,
      final pagination?,
    )) {
      return _getDeepPostResults(
        tags,
        page,
        limit: pageSize,
        cursors: cursors,
        pagination: pagination,
      );
    }

    final pagination = useCursor ? GelbooruIdPagination.fromTags(tags) : null;
    final cursor = options?.cursor;
    if (pagination != null && page > 1 && cursor == null) {
      throw const FormatException('Gelbooru cursor missing for continuation');
    }
    final requestTags = pagination != null && cursor != null
        ? pagination.tagsAfter(cursor)
        : tags;

    if (requestTags == null) {
      return <Post>[].toResult();
    }

    final value = await getPosts(
      tags: requestTags,
      page: pagination != null ? 1 : page,
      limit: pageSize,
    );

    final nextCursor = pagination != null ? value.lastId : null;
    if (pagination != null) {
      _validateIds(value, pagination, cursor: cursor);
      if (value.rawIds.isEmpty && (value.count ?? 0) > 0) {
        throw const FormatException(
          'Gelbooru returned no posts for a nonempty cursor page',
        );
      }
    }

    return value.posts
        .map(
          (e) => gelbooruPostDtoToGelbooruPost(
            e,
            PostMetadata(
              page: page,
              search: tags.join(' '),
              limit: pageSize,
            ),
          ),
        )
        .toList()
        .toResult(
          total: value.count,
          pageSize: pageSize,
          nextCursor: nextCursor,
          rawPostCount: value.rawIds.length,
          rawUniquePostCount: value.rawIds.toSet().length,
          hasMore: switch (value.count) {
            null => null,
            final count when pagination != null => value.rawIds.length < count,
            final count => page * pageSize < count,
          },
        );
  }

  Future<PostResult<Post>> _getDeepPostResults(
    List<String> tags,
    int page, {
    required int limit,
    required GelbooruPageCursors cursors,
    required GelbooruIdPagination pagination,
  }) async {
    final target = await cursors.locate(
      tags: tags,
      pagination: pagination,
      page: page,
      limit: limit,
      lastIdOf: (tags, page) async {
        final value = await getPosts(tags: tags, page: page, limit: limit);
        _validateIds(value, GelbooruIdPagination.fromTags(tags)!);
        return value.lastId;
      },
      probe: (tags) async {
        final value = await getPosts(tags: tags, page: 1, limit: 1);
        return (
          count:
              value.count ??
              (throw const FormatException('Gelbooru count unavailable')),
          firstId: value.lastId,
        );
      },
    );
    if (target == null) return <Post>[].toResult();

    final value = await getPosts(
      tags: target.tags,
      page: target.page,
      limit: limit,
    );
    _validateIds(value, GelbooruIdPagination.fromTags(target.tags)!);
    target.recordBoundary(value.lastId);

    return value.posts
        .map(
          (e) => gelbooruPostDtoToGelbooruPost(
            e,
            PostMetadata(
              page: page,
              search: tags.join(' '),
              limit: limit,
            ),
          ),
        )
        .toList()
        .toResult(
          pageSize: limit,
          rawPostCount: value.rawIds.length,
          rawUniquePostCount: value.rawIds.toSet().length,
          hasMore: value.count == null
              ? null
              : target.page * limit < value.count!,
          total: switch (value.count) {
            final count? => count + target.skipped,
            null => null,
          },
        );
  }
}

const _kGelbooruDefaultLimit = 100;

final gelbooruUploaderQueryProvider = Provider.family<UploaderQuery?, Post>((
  ref,
  post,
) {
  return switch (post.uploaderName) {
    final uploader? => UserColonUploaderQuery(uploader),
    _ => null,
  };
});

void _validateIds(
  GelbooruPosts value,
  GelbooruIdPagination pagination, {
  int? cursor,
}) {
  var previous = cursor;
  for (final id in value.rawIds) {
    final upper = pagination.upperBound;
    if (id == null ||
        id < pagination.lowerBound ||
        (upper != null && id > upper) ||
        (previous != null &&
            (pagination.ascending ? id <= previous : id >= previous))) {
      throw const FormatException('Gelbooru pagination did not advance');
    }
    previous = id;
  }
}
