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

class PhilomenaStatsTileSection extends ConsumerWidget {
  const PhilomenaStatsTileSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final data = InheritedPost.presentationOf(
      context,
    ).data<PhilomenaPostData>();

    return SliverToBoxAdapter(
      child: SimplePostStatsTile(
        totalComments: data?.commentCount ?? 0,
        favCount: data?.favCount ?? 0,
        score: post.score,
        votePercentText: _generatePercentText(post, data),
      ),
    );
  }

  String _generatePercentText(Post post, PhilomenaPostData? data) {
    final percent = post.score > 0 ? ((data?.upvotes ?? 0) / post.score) : 0;
    return post.score > 0 ? '(${(percent * 100).toInt()}% upvoted)' : '';
  }
}

class PhilomenaArtistInfoSection extends ConsumerWidget {
  const PhilomenaArtistInfoSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final data = InheritedPost.presentationOf(
      context,
    ).data<PhilomenaPostData>();

    return SliverToBoxAdapter(
      child: ArtistSection(
        commentary: ArtistCommentary.description(data?.description ?? ''),
        artistTags: post.artistTags ?? {},
        source: post.source,
      ),
    );
  }
}

class PhilomenaUploaderFileDetailTile extends ConsumerWidget {
  const PhilomenaUploaderFileDetailTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);
    final uploaderName = post.uploaderName;

    return switch (uploaderName) {
      null => const SizedBox.shrink(),
      final name => UploaderFileDetailTile(
        uploaderName: name,
        onSearch: switch (ref.watch(philomenaUploaderQueryProvider(post))) {
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

class PhilomenaUploaderPostsSection extends ConsumerWidget {
  const PhilomenaUploaderPostsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = InheritedPost.of<Post>(context);

    return UploaderPostsSection<Post>(
      query: ref.watch(
        philomenaUploaderQueryProvider(post),
      ),
    );
  }
}

final kPhilomenaPostDetailsUIBuilder = PostDetailsUIBuilder(
  preview: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<Post>(),
  },
  full: {
    DetailsPart.info: (context) =>
        const DefaultInheritedInformationSection<Post>(),
    DetailsPart.toolbar: (context) =>
        const DefaultInheritedPostActionToolbar<Post>(),
    DetailsPart.artistInfo: (context) => const PhilomenaArtistInfoSection(),
    DetailsPart.stats: (context) => const PhilomenaStatsTileSection(),
    DetailsPart.source: (context) =>
        const DefaultInheritedSourceSection<Post>(),
    DetailsPart.tags: (context) => const DefaultInheritedBasicTagsTile<Post>(),
    DetailsPart.fileDetails: (context) =>
        const DefaultInheritedFileDetailsSection<Post>(
          uploader: PhilomenaUploaderFileDetailTile(),
        ),
    DetailsPart.uploaderPosts: (context) =>
        const PhilomenaUploaderPostsSection(),
  },
);
