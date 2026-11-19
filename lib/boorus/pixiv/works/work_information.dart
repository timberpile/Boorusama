import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

import '../../../core/artists/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details/src/providers/media_group_provider.dart';
import '../../../core/posts/details/src/widgets/group_viewer_scope.dart';
import '../../../core/posts/details_parts/widgets.dart';
import 'work_creator_avatar.dart';

/// Work commentary uses the same artist section as ordinary Post details.
class PixivWorkInformation extends ConsumerWidget {
  const PixivWorkInformation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = GroupViewerScope.maybeEntryOf(context);
    if (entry == null) {
      final post = InheritedPost.of(context);
      return SliverToBoxAdapter(
        child: ArtistSection(
          commentary: ArtistCommentary.description(
            post.detailFacts.description ?? '',
          ),
          artistTags: const {},
          source: post.source,
        ),
      );
    }
    final state = ref.watch(mediaGroupProvider(entry));
    final details = state.details ?? entry.storedDetails;
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
        artistAvatarBuilder: pixivWorkCreatorAvatarBuilder(
          creators: details?.creators ?? const [],
          access: state.access,
        ),
      ),
    );
  }
}
