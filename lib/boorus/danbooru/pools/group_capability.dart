import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/bookmarks/src/types/pool_bookmark_capability.dart';
import '../../../core/bookmarks/src/types/pool_bookmark.dart';
import '../../../core/content/capabilities.dart';
import '../../../core/content/types.dart';
import '../../../core/http/client/coordination.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../core/posts/post/providers.dart';
import '../client_provider.dart';
import '../posts/related/related_gallery.dart';
import '../posts/post/providers.dart';
import 'content_group_source.dart';
import 'details/src/pool_detail_page.dart';
import 'details/src/widgets/pool_gallery_header.dart';
import 'pool/src/data/parser.dart';
import 'pool/types.dart';

BooruGroupCapability createDanbooruGroupCapability(Ref ref) =>
    BooruGroupCapability(
      engine: BooruType.danbooru,
      keyCodec: const BooruContentKeyCodec(BooruType.danbooru),
      createSource: (access) {
        final config = access.config;
        if (config == null)
          throw StateError('Group source has no authorized configuration');
        return DanbooruGroupSource(
          access: access,
          fetchPool: (id) async => poolDtoToDanbooruPool(
            await ref
                .read(danbooruClientProvider(config.auth))
                .getPool(
                  id,
                  cancelToken: ApiRequestContext.current().cancelToken,
                ),
          ),
          // The factory's Ref belongs to engine registration. Reading the
          // generic registry-backed repository here would re-enter that same
          // registry. Reuse the native repository and its standard origin bridge.
          postRepository: () => OriginAwarePostRepository.fromConfig(
            delegate: ref.read(danbooruPostRepoProvider(config.search)),
            config: config,
          ),
        );
      },
      presentation: const DanbooruGroupPresentation(),
    );

class DanbooruGroupPresentation
    implements BooruGroupPresentation, BooruGroupStatusPresentation {
  const DanbooruGroupPresentation();
  @override
  List<Widget> buildStatusActions(
    BuildContext context,
    ContentGroupSummary summary,
  ) {
    if (!summary.reference.sourceKey.startsWith('pool:')) return const [];
    final pool = RemoteBookmarkPool(
      id: int.parse(summary.reference.sourceKey.split(':').last),
      title: summary.title ?? '',
      total: summary.memberCount,
      supportsUploadOrder: true,
      category: switch (summary.displayCategory) {
        'series' => BookmarkedPoolCategory.series,
        'collection' => BookmarkedPoolCategory.collection,
        _ => BookmarkedPoolCategory.unknown,
      },
    );
    return [
      Consumer(
        builder: (context, ref, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: poolGalleryActions(ref, pool),
        ),
      ),
    ];
  }

  @override
  bool supports(ContentGroupSummary summary) =>
      summary.reference.engine == BooruType.danbooru &&
      (summary.reference.sourceKey.startsWith('pool:') ||
          summary.reference.sourceKey.startsWith('related:'));
  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.memberGrid;
  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.artist_page.posts;
  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      GroupSummaryCard(
        summary: summary,
        kind: summary.reference.sourceKey.startsWith('related:')
            ? PoolGridItemKind.related
            : summary.displayCategory == 'series'
            ? PoolGridItemKind.series
            : PoolGridItemKind.collection,
      );
  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    if (entry == null || entry.summary.reference != details.summary.reference) {
      return ViewerEntryNavigationStatus(
        child: Text(context.t.bookmark.pool_unavailable),
      );
    }
    if (details.summary.reference.sourceKey.startsWith('related:')) {
      return RelatedGallery(entry: entry);
    }
    final summary = details.summary;
    return PoolDetailContent(
      pool: DanbooruPool(
        id: int.parse(summary.reference.sourceKey.split(':').last),
        postIds: null,
        category: DanbooruPoolCategory.parse(summary.displayCategory),
        description: details.description?.text,
        postCount: summary.memberCount,
        name: summary.title,
        createdAt: details.sourceDates?.createdAt,
        updatedAt: details.sourceDates?.updatedAt,
      ),
      embedded: GroupViewerScope.maybeOf(context)?.embedded ?? true,
      storageId: entry.occurrenceId,
    );
  }
}
