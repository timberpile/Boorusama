import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bookmarks/src/types/pool_bookmark.dart';
import '../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/configs/manage/providers.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/router.dart';
import '../posts/post_data.dart';
import 'providers.dart';
import 'types.dart';

RemoteBookmarkPool szurubooruBookmarkPool(SzurubooruPool pool) =>
    RemoteBookmarkPool(
      id: pool.id,
      title: pool.name ?? '',
      total: pool.postCount,
      category: switch (pool.category?.toLowerCase()) {
        'series' => BookmarkedPoolCategory.series,
        'collection' => BookmarkedPoolCategory.collection,
        _ => BookmarkedPoolCategory.unknown,
      },
    );

final class SzurubooruPoolBookmarks implements PoolBookmarkCapability {
  const SzurubooruPoolBookmarks(this.ref);
  final Ref ref;

  @override
  Future<RemoteBookmarkPool?> getBookmarkPool(
    BooruConfig config,
    int id,
  ) async {
    final pool = await ref
        .read(szurubooruPoolRepoProvider(config.auth))
        .getPool(id);
    return pool == null ? null : szurubooruBookmarkPool(pool);
  }

  @override
  Future<Map<int, List<RemoteBookmarkPool>>> getBookmarkSeries(
    BooruConfig config,
    List<Post> posts,
  ) async => {
    for (final post in posts)
      post.id: [
        for (final pool in post.szurubooruData?.pools ?? <SzurubooruPool>[])
          if (pool.category?.toLowerCase() == 'series')
            szurubooruBookmarkPool(pool),
      ],
  };

  @override
  Future<void> openBookmarkPool(
    WidgetRef target,
    BooruConfig config,
    int id,
  ) async {
    final pool = await ref
        .read(szurubooruPoolRepoProvider(config.auth))
        .getPool(id);
    if (!target.context.mounted) return;
    if (!target.read(booruConfigProvider).contains(config))
      throw StateError('Pool profile changed');
    if (pool == null) throw StateError('Pool unavailable');
    target.pushRoute(
      '/szurubooru/pools/$id',
      extra: (pool: pool, config: config),
    );
  }
}
