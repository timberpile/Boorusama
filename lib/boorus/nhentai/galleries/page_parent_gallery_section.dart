import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/boorus/booru/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_access.dart';
import '../../../core/content/types.dart';
import '../../../core/navigation/destination_activity.dart';
import '../../../core/posts/details/src/types/inherited_post.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/pools/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../posts/data.dart';
import 'mapper.dart';
import 'open.dart';

/// The saved Page already identifies its Gallery before any metadata is loaded.
class NhentaiPageParentGallerySection extends ConsumerWidget {
  const NhentaiPageParentGallerySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.maybeOf<Post>(context);
    final data = post?.booruData;
    if (GroupViewerScope.maybeEntryOf(context) != null ||
        post == null ||
        post.origin.booruType != BooruType.nhentai ||
        data is! NhentaiPostData) {
      return const SliverToBoxAdapter();
    }
    final key = ref.watch(currentContentAccessKeyProvider);
    final access = key == null
        ? null
        : ref.watch(contentAccessContextProvider(key));
    if (access == null ||
        access.config == null ||
        access.key.engine != BooruType.nhentai ||
        access.key.siteNamespace != 'nhentai.net' ||
        post.origin.sourceHost != access.key.siteNamespace) {
      return const SliverToBoxAdapter();
    }

    final gallery = ContentGroupSummary(
      reference: nhentaiGalleryReference(access, data.galleryId),
    );
    final strings = context.t.content_viewer;
    return SliverToBoxAdapter(
      child: PoolTileList(
        title: strings.gallery,
        pools: [gallery],
        name: (_) => strings.gallery_number(id: data.galleryId),
        postCount: (summary) => summary.memberCount,
        onTap: (ref, summary) {
          if (!NavigationActivity.of(ref.context)) return;
          final current = ref.read(contentAccessContextProvider(access.key));
          if (current == null || !access.hasSameAuthorization(current)) return;
          openNhentaiGalleries(ref, current, [summary], 0);
        },
      ),
    );
  }
}
