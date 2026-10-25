import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bookmarks/src/types/pool_bookmark.dart';
import '../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/configs/manage/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/router.dart';
import '../client_provider.dart';
import 'pool/src/data/parser.dart';
import 'pool/types.dart';

RemoteBookmarkPool danbooruBookmarkPool(DanbooruPool pool) =>
    RemoteBookmarkPool(
      id: pool.id,
      title: pool.name ?? '',
      total: pool.postCount,
      category: switch (pool.category) {
        DanbooruPoolCategory.series => BookmarkedPoolCategory.series,
        DanbooruPoolCategory.collection => BookmarkedPoolCategory.collection,
        _ => BookmarkedPoolCategory.unknown,
      },
      supportsUploadOrder: true,
    );

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
    return pool == null ? null : danbooruBookmarkPool(pool);
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
        .getPoolsFromPostIds(postIds: requested.toList(), limit: 100);
    final result = <int, List<RemoteBookmarkPool>>{};
    for (final dto in dtos) {
      final pool = poolDtoToDanbooruPool(dto);
      if (pool == null || pool.category != DanbooruPoolCategory.series)
        continue;
      final summary = danbooruBookmarkPool(pool);
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
