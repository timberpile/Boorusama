import 'package:booru_clients/pixiv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../router.dart';
import 'related_source.dart';
import 'work_preview.dart';

class PixivRelatedWorksSection extends ConsumerWidget {
  const PixivRelatedWorksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = watchPixivPreviewAccess(ref);
    if (access == null) return const SliverToBoxAdapter();
    final work = GroupViewerScope.maybeEntryOf(context)?.summary.reference;
    final illustId = switch (work) {
      final work?
          when access.accepts(work) && work.sourceKey.startsWith('work:') =>
        int.tryParse(work.sourceKey.substring('work:'.length)),
      null => pixivPreviewPostData(context, access)?.illustId,
      _ => null,
    };
    if (illustId == null || illustId <= 0) return const SliverToBoxAdapter();
    final query = (access: access.key, illustId: illustId);

    return PixivWorksPreview(
      key: ValueKey(query),
      access: access,
      provider: pixivRelatedFirstPageProvider(query),
      title: context.t.post.detail.related_works,
      listing: (page) => PixivIllustListResult(
        illusts: page.illusts,
        hasMore: page.nextCursor != null,
      ),
      onShowAll: (ref, page) =>
          goToPixivRelatedPage(ref, query: query, firstPage: page),
    );
  }
}
