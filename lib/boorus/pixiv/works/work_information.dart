import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../../../core/artists/types.dart';
import '../../../core/content/content_access_provider.dart';
import '../../../core/content/content_media_access.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/details/routes.dart';
import '../../../core/posts/details/src/types/viewer_entry.dart';
import '../posts/types.dart';
import 'work_mapper.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details/src/providers/media_group_provider.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details_parts/widgets.dart';

/// Work commentary uses the same artist section as ordinary Post details.
class PixivWorkInformation extends ConsumerWidget {
  const PixivWorkInformation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    if (entry == null) {
      final post = InheritedPost.of(context);
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixivPageParentWork(post: post),
            ArtistSection(
              commentary: ArtistCommentary.description(
                post.detailFacts.description ?? '',
              ),
              artistTags: const {},
              source: post.source,
            ),
          ],
        ),
      );
    }
    final details = ref.watch(mediaGroupProvider(entry)).details;
    return SliverToBoxAdapter(
      child: ArtistSection(
        commentary: ArtistCommentary(
          originalTitle: details?.summary.title ?? entry.summary.title ?? '',
          originalDescription: details?.description?.text ?? '',
          translatedTitle: '',
          translatedDescription: '',
        ),
        artistTags: {
          for (final creator in details?.creators ?? []) creator.displayName,
        },
        source: InheritedPost.of(context).source,
      ),
    );
  }
}

/// A source-bound navigation link. Creating an entry never saves its parent.
class PixivPageParentWork extends ConsumerWidget {
  const PixivPageParentWork({required this.post, super.key});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(currentContentAccessKeyProvider);
    final access = key == null
        ? null
        : ref.watch(contentAccessContextProvider(key));
    final data = post.pixivData;
    if (access == null ||
        data == null ||
        data.illustId <= 0 ||
        data.isUgoira ||
        data.illustType == PixivIllustType.ugoira ||
        access.config == null ||
        access.key.profileId == null ||
        post.origin.booruType != access.key.engine ||
        post.origin.sourceHost != access.key.siteNamespace ||
        (post.origin.profileIdHint != null &&
            post.origin.profileIdHint != access.key.profileId)) {
      return const SizedBox.shrink();
    }
    final summary = ContentGroupSummary(
      reference: pixivWorkReference(access, data.illustId),
      memberCount: data.pageCount > 0 ? data.pageCount : null,
    );
    return TextButton.icon(
      key: const ValueKey('pixiv-page-parent-work'),
      icon: const Icon(Icons.collections_bookmark_outlined),
      label: Text(context.t.content_viewer.parent_work),
      onPressed: () {
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
              summary: summary,
              occurrenceId: Object(),
              source: ViewerSourceBinding(access.config!),
            ),
          ],
        );
      },
    );
  }
}
