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
import '../posts/post_data.dart';
import 'providers.dart';
import 'types.dart';

RemoteBookmarkPool szurubooruBookmarkPool(
  SzurubooruPool pool, {
  Uri? site,
}) {
  final title = pool.name ?? '';
  final category = switch (pool.category?.toLowerCase()) {
    'series' => BookmarkedPoolCategory.series,
    'collection' => BookmarkedPoolCategory.collection,
    _ => BookmarkedPoolCategory.unknown,
  };
  ContentGroupDetails? loadedDetails;
  if (site != null) {
    final reference = const ContentReferenceCodec().parse(
      engine: BooruType.szurubooru,
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
              // Retain raw Markdown as literal text within the shared formats.
              format: GroupTextFormat.plainText,
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
  );
}

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
    return pool == null
        ? null
        : szurubooruBookmarkPool(pool, site: Uri.parse(config.url));
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
            szurubooruBookmarkPool(pool, site: Uri.parse(config.url)),
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
