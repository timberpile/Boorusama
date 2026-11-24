import '../types/content_group_bookmark.dart' show RelatedBookmark;
import '../services/bookmark_presentation_covers.dart';
import '../../../content/groups/group_visibility.dart';
import '../../../content/types.dart';
import '../../../http/client/coordination.dart';
import '../../../posts/related/related_posts_order_value.dart';

import 'package:dio/dio.dart';

import 'bookmark_read_access.dart';
import '../types/pool_bookmark_cover.dart';

import 'dart:convert';
import 'dart:async';

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
import '../types/legacy_group_bookmark.dart';
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

/// Diagnostic selection-policy fingerprint; cover identity survives policy changes.
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

      final blacklist = pool.cachedMembers.isEmpty
          ? null
          : ref.read(blacklistTagsProvider(config.filter)).asData?.value;
      final cover = blacklist == null
          ? null
          : eligiblePoolCover(
              config,
              blacklist,
              pool.cachedMembers,
            )?.withMemberOrder(pool.memberOrderDigest);
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
      final cover = eligiblePoolCover(config, blacklist, index.members);
      final digest = pool.memberOrderDigest;
      final freshCover = cover?.withMemberOrder(digest);
      final oldCover = existing?.cover;
      final chosenCover =
          oldCover != null &&
              (oldCover.memberOrderDigest == null ||
                  digest == null ||
                  oldCover.memberOrderDigest == digest)
          ? oldCover
          : freshCover ?? oldCover;
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
        coverUrl: chosenCover?.thumbnail,
        cover: chosenCover,
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

/// Saved hints are provenance only; callers supply persisted presentation order.
BooruConfig? resolvePoolBookmarkProfile(
  CollectionBookmark pool,
  List<BooruConfig> configs,
) => pool.sourceTypeId != pool.origin.booruType.id
    ? null
    : selectBookmarkReadProfile(
        BookmarkReaderRequest(
          pool.origin,
          site: pool.sourceSite,
          kind: ContentKind.group,
        ),
        configs,
      );

BooruConfig? resolveBookmarkOriginProfile(
  PostOrigin origin,
  List<BooruConfig> configs,
) => selectBookmarkReadProfile(BookmarkReaderRequest(origin), configs);

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
            poolCoverAllowsRating(config, post.rating) &&
            !(post.status?.matches('deleted') ?? false) &&
            !(post.status?.matches('banned') ?? false) &&
            PoolBookmarkCover.isStatic(post.thumbnailImageUrl),
      );
  return eligible.isEmpty ? null : PoolBookmarkCover.fromPost(eligible.first);
}

String poolMemberOrderDigest(Iterable<Post> posts) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          for (final post in posts.take(40))
            [post.origin.booruType.id, post.origin.sourceHost, post.id],
        ]),
      ),
    )
    .toString();

bool bookmarkCoverAllowed(
  PoolBookmarkCover cover,
  BooruConfig config,
  Set<String> blacklist,
) {
  final facts = cover.visibility;
  if (facts == null ||
      facts.tagCoverage != MetadataCoverage.complete ||
      facts.deleted ||
      facts.banned ||
      !PoolBookmarkCover.isStatic(cover.thumbnail)) {
    return false;
  }
  final rating = Rating.parse(facts.rating);
  return poolCoverAllowsRating(config, rating) &&
      groupCoverPassesBlacklist(facts, blacklist, postId: cover.postId);
}

/// One source-ordered metadata page; no count/date crawl or permanent negative.
Future<PoolBookmarkCover?> discoverBookmarkCover(
  Ref ref,
  BooruConfig config,
  CollectionBookmark pool, {
  RelatedPostsOrder? order,
}) async {
  final blacklist = await ref.read(blacklistTagsProvider(config.filter).future);
  final query = pool.family == null
      ? 'pool:${pool.referenceId}'
      : '${pool.family!.query} ${(order ?? RelatedPostsOrder.oldest).queryOrder}';
  final result = await ref
      .read(originAwarePostRepoProvider(config))
      .getPosts(query, 1, limit: 40, options: PostFetchOptions.raw)
      .run();
  final data = result.fold((error) => throw error, (data) => data);
  final members = data.posts
      .take(40)
      .where((post) => pool.family?.contains(post) ?? true)
      .toList();
  return eligiblePoolCover(
    config,
    blacklist,
    members,
  )?.withMemberOrder(
    pool.family == null ? null : poolMemberOrderDigest(members),
  );
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
      final cancellation = CancelToken();
      var current = true;
      ref.onDispose(() {
        current = false;
        cancellation.cancel('Bookmark cover reader changed');
      });
      try {
        final (config, pool) = request;
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
        if (!saved.needsCoverFacts) return saved;
        final target = BookmarkReaderRequest(
          pool.origin,
          site: pool.sourceSite,
          kind: ContentKind.group,
        );
        final blacklist = await ref.watch(
          blacklistTagsProvider(config.filter).future,
        );
        if (!current) return null;
        final access = ref.watch(bookmarkReadAccessProvider(target));
        if (access == null || access.config != config) return null;
        final policy = poolCoverPolicy(config, blacklist);
        bool allowed() {
          if (!current) return false;
          final next = ref.read(bookmarkProvider).asData?.value;
          return next != null &&
              (
                    next.byId[pool.bookmarkId],
                    next.mirrors.epoch,
                    next.localBookmarkIds.contains(pool.bookmarkId),
                  ) ==
                  signature &&
              next.pools.any(
                (p) => p.localId == pool.localId && p.identity == pool.identity,
              ) &&
              (ref
                      .read(contentAccessContextProvider(access.key))
                      ?.hasSameAuthorization(access) ??
                  false) &&
              (ref
                      .read(bookmarkReadAccessProvider(target))
                      ?.hasSameAuthorization(access) ??
                  false);
        }

        final presentationOnly = poolCoverHasReceivedMembership(library, saved);
        final choiceKey = bookmarkPresentationCoverKey(library, saved);
        BookmarkPresentationCovers? choices;
        if (presentationOnly) {
          choices = ref.read(bookmarkPresentationCoversProvider);
          final selected = choices!.selected(choiceKey);
          if (selected != null) {
            return saved.copyWith(
              cover: selected,
              coverUrl: selected.thumbnail,
            );
          }
        }
        final record = library.byId[saved.bookmarkId];
        final order = switch (record) {
          RelatedBookmark(:final preferredOrder) => preferredOrder,
          LegacyRelatedGroupBookmark(:final preferredOrder) => preferredOrder,
          _ => null,
        };
        return await ref.read(poolCoverBackfillQueueProvider).run<
          CollectionBookmark?
        >(
          (access.key, pool.localId, signature, policy),
          () async {
            for (var attempt = 0; attempt < 2 && allowed(); attempt++) {
              try {
                final cover = await runWithApiRequestContext(
                  ApiRequestContext(
                    cancelToken: cancellation,
                    canStart: allowed,
                    canAdmit: allowed,
                  ),
                  () => discoverBookmarkCover(ref, config, saved, order: order),
                );
                if (!allowed() || cover == null) return null;
                final summary = saved.copyWith(
                  cover: cover,
                  coverUrl: cover.thumbnail,
                  coverPolicy: policy,
                );
                if (presentationOnly) {
                  await choices!.remember(choiceKey, cover, current: allowed);
                } else {
                  await ref
                      .read(bookmarkProvider.notifier)
                      .fillMissingPoolCover(summary, canCommit: allowed);
                }
                return allowed() ? summary : null;
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

Future<void> scheduleMissingPoolCover(Ref ref, CollectionBookmark saved) async {
  if (!saved.needsCoverFacts) return;
  final selected = resolvePoolBookmarkProfile(
    saved,
    ref.read(bookmarkReadProfilesProvider),
  );
  if (selected != null) {
    await ref.read(blacklistTagsProvider(selected.filter).future);
  } else {
    await ref.read(globalBlacklistedTagsProvider.future);
  }
  final access = ref.read(
    bookmarkReadAccessProvider(
      BookmarkReaderRequest(
        saved.origin,
        site: saved.sourceSite,
        kind: ContentKind.group,
      ),
    ),
  );
  final config = access?.config;
  if (config == null) return;
  unawaited(
    ref
        .read(missingPoolCoverProvider((config, saved)).future)
        .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
  );
}
