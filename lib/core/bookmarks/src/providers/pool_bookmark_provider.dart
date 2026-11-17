import '../types/pool_bookmark_cover.dart';

import 'dart:convert';
import 'dart:async';

import '../../../boorus/booru/types.dart';
import '../../../configs/manage/providers.dart';
import '../services/pool_cover_backfill_queue.dart';
import '../../../content/content_access_provider.dart';
import '../types/bookmark_library_state.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../blacklists/providers.dart';
import '../../../boorus/engine/providers.dart';
import '../../../configs/config/types.dart';
import '../../../posts/filter/types.dart';
import '../../../posts/post/providers.dart';
import '../../../posts/post/types.dart';
import '../../../posts/rating/types.dart';
import '../services/pool_summary_indexer.dart';
import '../types/pool_bookmark.dart';
import '../types/bookmark_group.dart';
import '../types/pool_bookmark_capability.dart';
import 'bookmark_provider.dart';

final poolBookmarkCapabilityProvider =
    Provider.family<PoolBookmarkCapability?, BooruConfig>(
      (ref, config) => switch (ref
          .watch(booruEngineRegistryProvider)
          .getRepository(config.auth.booruType)) {
        final PoolBookmarkCapability capability => capability,
        _ => null,
      },
    );

/// No credentials are hashed or persisted. A changed visibility policy hides
/// the old cover until an explicit bounded refresh selects a safe new one.
String poolCoverPolicy(BooruConfig config, Set<String> blacklist) {
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'ratingFilter': config.ratingFilter.index,
            'granularRatingFilters': config.granularRatingFilters
                ?.toFilterString(sort: true),
            'alwaysIncludeTags': config.alwaysIncludeTags?.toJsonString(),
            'deletedItemBehavior': config.deletedItemBehavior.index,
            'bannedPostVisibility': config.bannedPostVisibility.index,
            'blacklist': blacklist.toList()..sort(),
          }),
        ),
      )
      .toString();
}

final poolCoverPolicyProvider =
    Provider.family<AsyncValue<String>, BooruConfig>(
      (ref, config) => ref
          .watch(blacklistTagsProvider(config.filter))
          .whenData((tags) => poolCoverPolicy(config, tags)),
    );

final poolBookmarkDraftProvider = FutureProvider.autoDispose
    .family<CollectionBookmark, (BooruConfig, RemoteBookmarkPool)>((
      ref,
      request,
    ) async {
      final (config, pool) = request;
      final library = await ref.read(bookmarkProvider.future);
      final origin = postOriginFromConfig(config);
      final existing = library.pools
          .where(
            (saved) =>
                saved.identity ==
                (origin.booruType.id, origin.sourceHost, pool.id),
          )
          .firstOrNull;
      if (existing != null) return existing;

      final blacklist = ref
          .read(blacklistTagsProvider(config.filter))
          .asData
          ?.value;
      final cover = blacklist == null
          ? null
          : eligiblePoolCover(config, blacklist, pool.cachedMembers);
      final now = DateTime.now().toUtc();
      return PoolBookmark(
        localId: const Uuid().v4(),
        sourceSite: Uri.parse(config.url),
        loadedDetails: pool.loadedDetails,
        origin: origin,
        poolId: pool.id,
        category: pool.category,
        title: pool.title,
        total: pool.total,
        createdAt: now,
        observedAt: now,
        groupIds: const {},
        tags: const {},
        coverage: PoolTagCoverage.unknown,
        cover: cover,
        coverUrl: cover?.thumbnail,
        coverPolicy: cover == null ? null : poolCoverPolicy(config, blacklist!),
      );
    });

final poolBookmarkRefreshProvider = FutureProvider.autoDispose
    .family<CollectionBookmark, (BooruConfig, RemoteBookmarkPool)>((
      ref,
      request,
    ) async {
      final (config, pool) = request;
      final libraryFuture = ref.read(bookmarkProvider.future);
      final repo = ref.read(originAwarePostRepoProvider(config));
      final blacklistFuture = ref.read(
        blacklistTagsProvider(config.filter).future,
      );
      final library = await libraryFuture;
      final origin = postOriginFromConfig(config);
      final existing = library.pools
          .where(
            (p) =>
                p.identity == (origin.booruType.id, origin.sourceHost, pool.id),
          )
          .firstOrNull;
      final index =
          await PoolSummaryIndexer(
            fetch: (query, limit) async {
              final result = await repo.getPosts(query, 1, limit: limit).run();
              return result.fold(
                (_) => throw StateError('Pool metadata unavailable'),
                (r) => r.posts,
              );
            },
          ).index(
            poolId: pool.id,
            total: pool.total,
            supportsUploadOrder: pool.supportsUploadOrder,
          );
      final blacklist = await blacklistFuture;
      // An interrupted refresh cannot replace the last safe persisted summary.
      // Initial references may still be saved with explicitly unknown metadata.
      if (existing != null && index.hasFailedRequests) {
        throw StateError('Pool metadata unavailable');
      }
      final visible = filterTags(index.members, blacklist).where(
        (p) =>
            poolCoverAllowsRating(config, p.rating) &&
            !(p.status?.matches('deleted') ?? false) &&
            !(p.status?.matches('banned') ?? false),
      );
      final coverPost = visible
          .where((p) => PoolBookmarkCover.isStatic(p.thumbnailImageUrl))
          .firstOrNull;
      final cover = coverPost == null
          ? null
          : PoolBookmarkCover.fromPost(coverPost);
      final now = DateTime.now().toUtc();
      return PoolBookmark(
        localId: existing?.localId ?? const Uuid().v4(),
        sourceSite: Uri.parse(config.url),
        loadedDetails: pool.loadedDetails,
        origin: origin,
        poolId: pool.id,
        category: pool.category,
        title: pool.title,
        total: pool.total,
        createdAt: existing?.createdAt ?? now,
        observedAt: now,
        groupIds: existing?.groupIds ?? {defaultBookmarkGroupId},
        tags: index.tags,
        coverage: index.coverage,
        coverUrl: cover?.thumbnail,
        cover: cover,
        coverPolicy: poolCoverPolicy(config, blacklist),
        newestUpload: index.newestUpload,
        oldestUpload: index.oldestUpload,
      );
    });

bool poolCoverAllowsRating(BooruConfig config, Rating rating) =>
    switch (config.ratingFilter) {
      BooruConfigRatingFilter.none => true,
      BooruConfigRatingFilter.hideExplicit =>
        rating != Rating.explicit && rating != Rating.unknown,
      BooruConfigRatingFilter.hideNSFW =>
        rating == Rating.general || rating == Rating.sensitive,
      BooruConfigRatingFilter.custom =>
        config.granularRatingFilters?.ratings.contains(rating) ?? false,
    };

/// A stored hint must resolve to its original profile. Removing that profile
/// never authorizes borrowing the sole remaining account on the same host.
BooruConfig? resolvePoolBookmarkProfile(
  CollectionBookmark pool,
  List<BooruConfig> configs,
) =>
    (pool.isRelated && pool.origin.profileIdHint == null) ||
        pool.sourceTypeId != pool.origin.booruType.id
    ? null
    : switch (const PostOriginResolver().resolve(
        pool.origin,
        configs,
        allowProfileHintFallback: false,
      )) {
        ResolvedPostOrigin(:final config) => config,
        _ => null,
      };

BooruConfig? resolveBookmarkOriginProfile(
  PostOrigin origin,
  List<BooruConfig> configs,
) => switch (const PostOriginResolver().resolve(
  origin,
  configs,
  allowProfileHintFallback: true,
)) {
  ResolvedPostOrigin(:final config) => config,
  _ => null,
};

/// Upgrade fallback for records saved before cover variants were persisted.
/// It is cached for the lifetime of this source-scoped library view.
final legacyPoolBookmarkCoverProvider = FutureProvider.autoDispose
    .family<PoolBookmarkCover?, (BooruConfig, CollectionBookmark)>((
      ref,
      request,
    ) async {
      final (config, pool) = request;
      if (pool.sourceSite != null) return null;
      final capability = ref.read(poolBookmarkCapabilityProvider(config));
      if (pool.isRelated || capability == null) return null;
      final remote = await capability.getBookmarkPool(config, pool.referenceId);
      if (remote == null) return null;
      final draft = await ref.watch(
        poolBookmarkRefreshProvider((config, remote)).future,
      );
      return draft.cover;
    });

PoolBookmarkCover? eligiblePoolCover(
  BooruConfig config,
  Set<String> blacklist,
  Iterable<Post> posts,
) {
  final origin = postOriginFromConfig(config);
  final eligible =
      filterTags(
        posts.take(PoolSummaryIndexer.memberBudget).toList(),
        blacklist,
      ).where(
        (post) =>
            post.origin.booruType == origin.booruType &&
            post.origin.sourceHost == origin.sourceHost &&
            post.origin.profileIdHint == config.id &&
            poolCoverAllowsRating(config, post.rating) &&
            !(post.status?.matches('deleted') ?? false) &&
            !(post.status?.matches('banned') ?? false) &&
            PoolBookmarkCover.isStatic(post.thumbnailImageUrl),
      );
  return eligible.isEmpty ? null : PoolBookmarkCover.fromPost(eligible.first);
}

final poolCoverBackfillQueueProvider = Provider(
  (_) => PoolCoverBackfillQueue(),
);

bool poolCoverHasReceivedMembership(
  BookmarkLibraryState library,
  CollectionBookmark pool,
) => pool.groupIds.any(library.mirrors.isReceived);

/// Received-only results are presentation data, scoped by actor and source
/// revision. They never modify publisher records, digests or read state.
final missingPoolCoverProvider = FutureProvider.autoDispose
    .family<CollectionBookmark?, (BooruConfig, CollectionBookmark)>((
      ref,
      request,
    ) async {
      final keepAlive = ref.keepAlive();
      var current = true;
      ref.onDispose(() => current = false);
      try {
        final (config, pool) = request;
        if (pool.isRelated || config.auth.booruType != BooruType.danbooru)
          return null;
        final signature = ref.watch(
          bookmarkProvider.select((value) {
            final state = value.asData?.value;
            return (
              state?.byId[pool.bookmarkId],
              state?.mirrors.epoch,
              state?.localBookmarkIds.contains(pool.bookmarkId),
            );
          }),
        );
        final library = await ref.read(bookmarkProvider.future);
        if (!current) return null;
        final saved = library.pools
            .where(
              (saved) =>
                  saved.localId == pool.localId &&
                  saved.identity == pool.identity,
            )
            .firstOrNull;
        if (saved == null) return null;
        if (saved.coverUrl != null) return saved;
        final public = config.anonymousReadScope;
        if (public == null) {
          // A native public bookmark must keep its anonymous actor even when
          // a matching private profile is added later.
          if (pool.sourceSite != null && pool.origin.profileIdHint == null)
            return null;
          final owner = resolvePoolBookmarkProfile(
            pool,
            ref.read(booruConfigProvider),
          );
          if (owner?.id != config.id || owner?.auth != config.auth) return null;
        } else if (pool.origin.profileIdHint != null || !public.isCurrent) {
          return null;
        }
        final blacklist = await ref.watch(
          blacklistTagsProvider(config.filter).future,
        );
        if (!current) return null;
        final policy = poolCoverPolicy(config, blacklist);
        final access = public == null
            ? ref.watch(contentProfileAccessProvider(config.id))
            : ref.watch(contentAccessContextProvider(public.key));
        if (access == null ||
            access.config?.auth != config.auth ||
            access.key.engine != pool.origin.booruType ||
            access.key.siteNamespace != pool.origin.sourceHost)
          return null;
        final presentationOnly = poolCoverHasReceivedMembership(library, saved);
        bool allowed() {
          if (!current) return false;
          final next = ref.read(bookmarkProvider).asData?.value;
          if (next == null ||
              (
                    next.byId[pool.bookmarkId],
                    next.mirrors.epoch,
                    next.localBookmarkIds.contains(pool.bookmarkId),
                  ) !=
                  signature ||
              !next.pools.any(
                (p) => p.localId == pool.localId && p.identity == pool.identity,
              ) ||
              ref
                      .read(contentAccessContextProvider(access.key))
                      ?.hasSameAuthorization(access) !=
                  true ||
              ref.read(poolCoverPolicyProvider(config)).asData?.value != policy)
            return false;
          return true;
        }

        return await ref
            .read(poolCoverBackfillQueueProvider)
            .run<CollectionBookmark?>(
              (access.key, pool.localId, signature, policy),
              () async {
                for (var attempt = 0; attempt < 2 && allowed(); attempt++) {
                  try {
                    final remote = RemoteBookmarkPool(
                      id: pool.referenceId,
                      title: pool.title,
                      category: pool.category,
                      total: pool.total,
                      loadedDetails: pool.loadedDetails,
                    );
                    // Two attempts at most; each reads one metadata page of up to 40 members.
                    final summary = await ref.read(
                      poolBookmarkRefreshProvider((config, remote)).future,
                    );
                    if (!allowed() || summary.cover == null) return null;
                    if (!presentationOnly) {
                      await ref
                          .read(bookmarkProvider.notifier)
                          .fillMissingPoolCover(summary, canCommit: allowed);
                    }
                    return summary;
                  } catch (_) {
                    if (attempt == 1) rethrow;
                  }
                }
                return null;
              },
            );
      } finally {
        keepAlive.close();
      }
    });

void scheduleMissingPoolCover(Ref ref, CollectionBookmark saved) {
  if (saved.coverUrl != null ||
      saved.isRelated ||
      (saved.sourceSite != null && saved.origin.profileIdHint == null))
    return;
  final config = resolvePoolBookmarkProfile(
    saved,
    ref.read(booruConfigProvider),
  );
  if (config == null || config.auth.booruType != BooruType.danbooru) return;
  unawaited(
    ref
        .read(missingPoolCoverProvider((config, saved)).future)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );
}
