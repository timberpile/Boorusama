import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/configs/config/types.dart';
import '../../../core/content/capabilities.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details/src/widgets/viewer_entry_navigation_header.dart';
import '../../../core/posts/pools/group_summary_card.dart';
import '../../../core/posts/pools/pool_grid_item.dart';
import '../../../core/posts/post/providers.dart';
import '../posts/providers.dart';
import 'content_group_source.dart';
import 'providers.dart';
import 'src/pool_detail_page.dart';
import 'types.dart';

BooruGroupCapability createSzurubooruGroupCapability(
  Ref ref,
) => BooruGroupCapability(
  engine: BooruType.szurubooru,
  keyCodec: const BooruContentKeyCodec(BooruType.szurubooru),
  createSource: (ref, access) {
    final config = access.config;
    if (config == null) {
      throw StateError('Group source has no authorized configuration');
    }
    return SzurubooruGroupSource(
      access: access,
      fetchPool: (id) =>
          ref.read(szurubooruPoolRepoProvider(config.auth)).getPool(id),
      // Resolve the native repository through the caller's authorized scope.
      postRepository: () => OriginAwarePostRepository.fromConfig(
        delegate: ref.read(szurubooruPostRepoProvider(config.search)),
        config: config,
      ),
    );
  },
  presentation: const SzurubooruGroupPresentation(),
);

class SzurubooruGroupPresentation implements BooruGroupPresentation {
  const SzurubooruGroupPresentation();

  @override
  bool supports(ContentGroupSummary summary) =>
      summary.reference.engine == BooruType.szurubooru &&
      summary.reference.sourceKey.startsWith('pool:');

  @override
  GroupLayout layoutFor(ContentGroupSummary summary) => GroupLayout.memberGrid;

  @override
  String memberLabel(BuildContext context, ContentGroupSummary summary) =>
      context.t.artist_page.posts;

  @override
  Widget buildCard(BuildContext context, ContentGroupSummary summary) =>
      GroupSummaryCard(
        summary: summary,
        kind: PoolGridItemKind.collection,
      );

  @override
  Widget buildDetails(BuildContext context, ContentGroupDetails details) {
    final scope = GroupViewerScope.maybeOf(context);
    final entry = scope?.entry;
    final summary = details.summary;
    final sourceKey = summary.reference.sourceKey;
    final poolId = sourceKey.startsWith('pool:')
        ? int.tryParse(sourceKey.substring('pool:'.length))
        : null;
    if (scope == null ||
        entry == null ||
        entry.summary.reference != summary.reference ||
        poolId == null) {
      return ViewerEntryNavigationStatus(
        child: Text(context.t.bookmark.pool_unavailable),
      );
    }

    return SzurubooruPoolDetailContent(
      pool: SzurubooruPool(
        id: poolId,
        names: summary.title == null ? const [] : [summary.title!],
        category: summary.displayCategory,
        description: details.description?.text,
        postCount: summary.memberCount,
        postIds: null,
        thumbnailUrls: const [],
        createdAt: details.sourceDates?.createdAt,
        updatedAt: details.sourceDates?.updatedAt,
      ),
      embedded: scope.embedded,
      storageId: entry.occurrenceId,
    );
  }
}
