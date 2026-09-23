// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../core/posts/details/types.dart';
import '../../../core/posts/details_parts/types.dart';
import '../../../core/posts/details_parts/widgets.dart';
import '../../../core/posts/post/types.dart';
import '../../../core/search/search/routes.dart';
import 'providers.dart';

class GelbooruUploaderFileDetailTile extends ConsumerWidget {
  const GelbooruUploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(gelbooruUploaderQueryProvider(post))) {
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

class GelbooruUploaderPostsSection extends ConsumerWidget {
  const GelbooruUploaderPostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);

    return UploaderPostsSection<Post>(
      query: ref.watch(
        gelbooruUploaderQueryProvider(post),
      ),
    );
  }
}

final kGelbooruPostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<Post>(),
  },
  full: {
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<Post>(),
    DetailsPart.source: (context) =>
        const DefaultInheritedSourceSection<Post>(),
    DetailsPart.tags: (context) => const DefaultInheritedTagsTile<Post>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(
          uploader: GelbooruUploaderFileDetailTile(),
        ),
    DetailsPart.artistPosts: (context) =>
        const DefaultInheritedArtistPostsSection<Post>(),
    DetailsPart.uploaderPosts: (context) =>
        const GelbooruUploaderPostsSection(),
    DetailsPart.characterList: (context) =>
        const DefaultInheritedCharacterPostsSection<Post>(),
  },
);
