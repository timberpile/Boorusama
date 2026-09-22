// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/artists/types.dart';
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/search/routes.dart';
import 'providers.dart';
import 'post_data.dart';

class E621ArtistSection extends ConsumerWidget {
  const E621ArtistSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<UnifiedPost>(context);
    final data = InheritedPost.presentationOf(context).data<E621PostData>();

    final commentary = data?.description ?? '';

    return SliverToBoxAdapter(
      child: ArtistSection(
        commentary: ArtistCommentary.description(commentary),
        artistTags: post.artistTags ?? const {},
        source: post.source,
      ),
    );
  }
}

class E621UploaderFileDetailTile extends ConsumerWidget {
  const E621UploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<UnifiedPost>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(e621UploaderQueryProvider(post))) {
          final query? => () => goToSearchPage(
            ref,
            tag: query.resolveTag(),
          ),
          _ => null,
        },
      ),
    };
  }
}

class E621UploaderPostsSection extends ConsumerWidget {
  const E621UploaderPostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<UnifiedPost>(context);

    return UploaderPostsSection<UnifiedPost>(
      query: ref.watch(
        e621UploaderQueryProvider(post),
      ),
    );
  }
}

final kE621PostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<UnifiedPost>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<UnifiedPost>(),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<UnifiedPost>(
          showSource: true,
        ),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<UnifiedPost>(),
    DetailsPart.artistInfo: (context) => const E621ArtistSection(),
    DetailsPart.tags: (context) =>
        const DefaultInheritedTagsTile<UnifiedPost>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<UnifiedPost>(
          uploader: E621UploaderFileDetailTile(),
        ),
    DetailsPart.artistPosts: (context) =>
        const DefaultInheritedArtistPostsSection<UnifiedPost>(),
    DetailsPart.uploaderPosts: (context) => const E621UploaderPostsSection(),
    DetailsPart.characterList: (context) =>
        const DefaultInheritedCharacterPostsSection<UnifiedPost>(),
  },
);
