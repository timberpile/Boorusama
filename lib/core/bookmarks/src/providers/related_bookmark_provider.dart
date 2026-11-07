import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../blacklists/providers.dart';
import '../../../configs/config/types.dart';
import '../../../http/client/coordination.dart';
import '../../../posts/filter/types.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import '../../../posts/related/related_family.dart';
import '../types/bookmark_group.dart';
import '../types/pool_bookmark.dart';
import '../types/pool_bookmark_cover.dart';
import 'bookmark_provider.dart';
import 'pool_bookmark_provider.dart';

/// Resolves local membership first and otherwise creates a summary-only draft.
final relatedBookmarkDraftProvider = FutureProvider.autoDispose
    .family<CollectionBookmark, (BooruConfig, RelatedFamilyReference)>((
      ref,
      request,
    ) async {
      final (config, family) = request;
      final origin = postOriginFromConfig(config);
      if (origin.sourceHost != family.origin.sourceHost ||
          config.auth.booruType != family.origin.booruType) {
        throw StateError('Related source mismatch');
      }
      final library = await ref.read(bookmarkProvider.future);
      final existing = library.pools
          .where((saved) => saved.identity == family.identity)
          .firstOrNull;
      if (existing != null) return existing;

      final now = DateTime.now().toUtc();
      return RelatedCollectionBookmark(
        family: RelatedFamilyReference(
          origin: origin,
          anchorId: family.anchorId,
        ),
        localId: const Uuid().v4(),
        sourceSite: Uri.parse(config.url),
        createdAt: now,
        observedAt: now,
        groupIds: const {},
        tags: const {},
        coverage: PoolTagCoverage.unknown,
      );
    });

/// One bounded producer request (plus its existing exact-count request). The
/// provider coalesces requests for the same family and authorization context.
final relatedBookmarkRefreshProvider = FutureProvider.autoDispose
    .family<CollectionBookmark, (BooruConfig, RelatedFamilyReference)>((
      ref,
      request,
    ) async {
      final (config, family) = request;
      if (postOriginFromConfig(config).sourceHost != family.origin.sourceHost ||
          config.auth.booruType != family.origin.booruType)
        throw StateError('Related source mismatch');
      final cancellation = CancelToken();
      ref.onDispose(cancellation.cancel);
      final repo = ref.watch(originAwarePostRepoProvider(config));
      final libraryFuture = ref.read(bookmarkProvider.future);
      final blacklist = await ref.watch(
        blacklistTagsProvider(config.filter).future,
      );
      final library = await libraryFuture;
      final existing = library.pools
          .where((p) => p.identity == family.identity)
          .firstOrNull;
      final result = await runWithApiRequestContext(
        ApiRequestContext(cancelToken: cancellation),
        () => repo
            .getPosts(family.query, 1, limit: 40, options: PostFetchOptions.raw)
            .run(),
      );
      final data = result.fold((_) => null, (value) => value);
      if (cancellation.isCancelled)
        throw StateError('Related request cancelled');
      if (data == null && existing != null)
        throw StateError('Related metadata unavailable');
      final now = DateTime.now().toUtc();
      final members =
          data?.posts.take(40).where(family.contains).toList() ?? <Post>[];
      final visible = filterTags(members, blacklist)
          .where(
            (p) =>
                poolCoverAllowsRating(config, p.rating) &&
                !(p.status?.matches('deleted') ?? false) &&
                !(p.status?.matches('banned') ?? false),
          )
          .toList();
      final complete =
          data?.total != null &&
          data!.total == members.length &&
          members.length == visible.length;
      final coverPost = visible
          .where((p) => PoolBookmarkCover.isStatic(p.thumbnailImageUrl))
          .firstOrNull;
      final dates = visible.map((p) => p.createdAt).nonNulls.toList()..sort();
      return RelatedCollectionBookmark(
        family: RelatedFamilyReference(
          origin: postOriginFromConfig(config),
          anchorId: family.anchorId,
        ),
        localId: existing?.localId ?? const Uuid().v4(),
        sourceSite: Uri.parse(config.url),
        createdAt: existing?.createdAt ?? now,
        observedAt: now,
        groupIds: existing?.groupIds ?? {defaultBookmarkGroupId},
        tags: {for (final post in visible) ...post.tags},
        coverage: data == null
            ? PoolTagCoverage.unknown
            : complete
            ? PoolTagCoverage.complete
            : PoolTagCoverage.partial,
        total: data?.total,
        cover: coverPost == null ? null : PoolBookmarkCover.fromPost(coverPost),
        coverPolicy: poolCoverPolicy(config, blacklist),
        newestUpload:
            complete && dates.length == visible.length && dates.isNotEmpty
            ? dates.last
            : null,
        oldestUpload:
            complete && dates.length == visible.length && dates.isNotEmpty
            ? dates.first
            : null,
      );
    });
