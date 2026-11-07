import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/bookmarks/src/types/pool_bookmark.dart';
import '../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/content_reference.dart';
import '../../../core/content/groups/group_details.dart';
import '../../../core/content/groups/group_metadata.dart';
import '../../../core/content/groups/group_summary.dart';
import '../../../core/configs/manage/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/router.dart';
import '../client_provider.dart';
import 'pool/src/data/parser.dart';
import 'pool/types.dart';

RemoteBookmarkPool danbooruBookmarkPool(
  DanbooruPool pool, {
  Uri? site,
}) {
  final title = pool.name ?? '';
  final category = switch (pool.category) {
    DanbooruPoolCategory.series => BookmarkedPoolCategory.series,
    DanbooruPoolCategory.collection => BookmarkedPoolCategory.collection,
    _ => BookmarkedPoolCategory.unknown,
  };
  ContentGroupDetails? loadedDetails;
  if (site != null) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.danbooru,
      site: site,
      kind: ContentKind.group,
      sourceKey: 'pool:${pool.id}',
    );
    final summary = ContentGroupSummary(
      reference: reference,
      title: title,
      memberCount: pool.postCount,
      displayCategory: category == BookmarkedPoolCategory.unknown
          ? null
          : category.name,
    );
    loadedDetails = ContentGroupDetails(
      summary: summary,
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
  }
  return RemoteBookmarkPool(
    id: pool.id,
    title: title,
    total: pool.postCount,
    category: category,
    loadedDetails: loadedDetails,
    supportsUploadOrder: true,
  );
}

final class DanbooruPoolBookmarks implements PoolBookmarkCapability {
  const DanbooruPoolBookmarks(this.ref);
  final Ref ref;

  Future<DanbooruPool?> _pool(BooruConfig config, int id) async =>
      poolDtoToDanbooruPool(
        await ref.read(danbooruClientProvider(config.auth)).getPool(id),
      );

  @override
  Future<RemoteBookmarkPool?> getBookmarkPool(
    BooruConfig config,
    int id,
  ) async {
    final pool = await _pool(config, id);
    return pool == null
        ? null
        : danbooruBookmarkPool(pool, site: Uri.parse(config.url));
  }

  @override
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  ) async {
    final requested = posts
        .take(PoolBookmarkCapability.membershipBudget)
        .map((p) => p.id)
        .toSet();
    if (requested.isEmpty) return {};
    final dtos = await ref
        .read(danbooruClientProvider(config.auth))
        .getPoolsFromPostIds(postIds: requested.toList(), limit: 1000);
    // A full response may be truncated. Do not cache incomplete membership as
    // authoritative absence; Search keeps the raw posts visible and retryable.
    if (dtos.length >= 1000) {
      throw StateError('Series membership response reached the Pool limit');
    }
    final result = <int, List<RemoteBookmarkPool>>{};
    for (final dto in dtos) {
      final pool = poolDtoToDanbooruPool(dto);
      if (pool == null || pool.category != DanbooruPoolCategory.series)
        continue;
      final summary = danbooruBookmarkPool(
        pool,
        site: Uri.parse(config.url),
      );
      for (final member in pool.postIds ?? <int>[]) {
        if (requested.contains(member)) (result[member] ??= []).add(summary);
      }
    }
    return result;
  }

  @override
  Future<void> openBookmarkPool(
    WidgetRef target,
    BooruConfig config,
    int id,
  ) async {
    final pool = await _pool(config, id);
    if (!target.context.mounted) return;
    if (!target.read(booruConfigProvider).contains(config))
      throw StateError('Pool profile changed');
    if (pool == null) throw StateError('Pool unavailable');
    target.pushRoute(
      '/danbooru/pools/$id',
      extra: (pool: pool, config: config),
    );
  }
}
