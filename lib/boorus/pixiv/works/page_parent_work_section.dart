import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_access.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/src/types/inherited_post.dart';
import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/pools/widgets.dart';
import '../posts/types.dart';
import 'work_mapper.dart';

/// Parent navigation uses only the saved Page's identity and known count.
/// It neither resolves Work metadata nor looks for a separately saved Work.
class PixivParentWorkSection extends ConsumerWidget {
  const PixivParentWorkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.maybeOf<Post>(context);
    final data = post?.pixivData;
    final key = ref.watch(currentContentAccessKeyProvider);
    final access = key == null
        ? null
        : ref.watch(contentAccessContextProvider(key));
    if (GroupViewerScope.maybeEntryOf(context) != null ||
        post == null ||
        data == null ||
        access == null ||
        access.key.engine != BooruType.pixiv ||
        data.illustId <= 0 ||
        data.isUgoira ||
        data.illustType == PixivIllustType.ugoira ||
        access.config == null ||
        access.key.profileId == null ||
        post.origin.booruType != access.key.engine ||
        post.origin.sourceHost != access.key.siteNamespace ||
        (post.origin.profileIdHint != null &&
            post.origin.profileIdHint != access.key.profileId)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final ContentReference parent;
    try {
      parent = pixivWorkReference(access, data.illustId);
    } on FormatException {
      // Imported snapshots can retain an invalid source ID.
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverToBoxAdapter(
      child: PoolTileList<PixivPostData>(
        key: const ValueKey('pixiv-page-parent-work'),
        title: context.t.content_viewer.parent_work,
        pools: [data],
        name: (page) => context.t.content_viewer.work_number(id: page.illustId),
        postCount: (page) => page.pageCount > 0 ? page.pageCount : null,
        countLabel: (count) => context.t.content_viewer.page_counter(n: count),
        onTap: (ref, page) {
          final current = ref.read(contentAccessContextProvider(access.key));
          if (current == null || !access.hasSameAuthorization(current)) return;
          goToPostDetailsPageCore<Post>(
            ref: ref,
            posts: const [],
            initialIndex: 0,
            hero: false,
            initialThumbnailUrl: null,
            config: access.config,
            entries: [
              GroupViewerEntry(
                summary: ContentGroupSummary(
                  reference: parent,
                  memberCount: page.pageCount > 0 ? page.pageCount : null,
                ),
                occurrenceId: Object(),
                source: ViewerSourceBinding(access.config!),
              ),
            ],
          );
        },
      ),
    );
  }
}
