import 'dart:convert';

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
    .family<PoolBookmark, (BooruConfig, RemoteBookmarkPool)>((
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
      final visible = filterTags(index.members, blacklist).where(
        (p) =>
            poolCoverAllowsRating(config, p.rating) &&
            !(p.status?.matches('deleted') ?? false) &&
            !(p.status?.matches('banned') ?? false),
      );
      final cover = visible.map((p) => p.thumbnailImageUrl).where((url) {
        final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
        return path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.png') ||
            path.endsWith('.webp');
      }).firstOrNull;
      final now = DateTime.now().toUtc();
      return PoolBookmark(
        localId: existing?.localId ?? const Uuid().v4(),
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
        coverUrl: cover,
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
  PoolBookmark pool,
  List<BooruConfig> configs,
) => pool.sourceTypeId != pool.origin.booruType.id
    ? null
    : resolveBookmarkOriginProfile(pool.origin, configs);

BooruConfig? resolveBookmarkOriginProfile(
  PostOrigin origin,
  List<BooruConfig> configs,
) => switch (const PostOriginResolver().resolve(
  origin,
  origin.profileIdHint == null
      ? configs
      : configs.where((c) => c.id == origin.profileIdHint),
)) {
  ResolvedPostOrigin(:final config) => config,
  _ => null,
};
