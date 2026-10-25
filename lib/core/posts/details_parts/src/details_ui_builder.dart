// Flutter imports:
import 'package:flutter/widgets.dart';

// Project imports:
import 'details_part.dart';
import '../../details/types.dart';
import '../../post/types.dart';
import 'simple_post_stats_tile.dart';
import 'artist_section.dart';
import '../../../artists/types.dart';

const kDefaultPostDetailsPreviewPart = {
  DetailsPart.info,
  DetailsPart.toolbar,
};

const kDefaultPostDetailsBuildablePreviewPart = {
  DetailsPart.info,
  DetailsPart.toolbar,
  DetailsPart.fileDetails,
};

// Shared default order follows Danbooru; source-only sections occupy the
// corresponding slots. Explicit saved layouts are resolved by the page first.
const _defaultFullDetailsOrder = [
  DetailsPart.info,
  DetailsPart.toolbar,
  DetailsPart.artistInfo,
  DetailsPart.stats,
  DetailsPart.source,
  DetailsPart.tags,
  DetailsPart.fileDetails,
  DetailsPart.comments,
  DetailsPart.artistPosts,
  DetailsPart.uploaderPosts,
  DetailsPart.pool,
  DetailsPart.relatedPosts,
  DetailsPart.characterList,
];

class PostDetailsUIBuilder {
  const PostDetailsUIBuilder({
    this.preview = const {},
    this.full = const {},
    this.previewAllowedParts = const {
      DetailsPart.fileDetails,
      DetailsPart.source,
    },
  });

  final Set<DetailsPart> previewAllowedParts;

  final Map<DetailsPart, Widget Function(BuildContext context)> preview;
  final Map<DetailsPart, Widget Function(BuildContext context)> full;

  Set<DetailsPart> get buildablePreviewParts {
    // use full widgets, except for the ones that are not allowed
    return {
      ...previewAllowedParts.intersection(full.keys.toSet()),
      ...kDefaultPostDetailsBuildablePreviewPart,
      ...preview.keys.toSet(),
    };
  }

  Set<DetailsPart> get buildableFullParts {
    final available = {...full.keys, DetailsPart.stats, DetailsPart.artistInfo};
    return {
      for (final part in _defaultFullDetailsOrder)
        if (available.contains(part)) part,
      ...available,
    };
  }

  Widget? buildPart(BuildContext context, DetailsPart part) {
    final builder = full[part];
    if (builder != null) {
      return builder(context);
    }

    if (part == DetailsPart.artistInfo) {
      final post = InheritedPost.of<Post>(context);
      final description = post.detailFacts.description;
      return SliverToBoxAdapter(
        child: description == null
            ? const SizedBox.shrink()
            : ArtistSection(
                commentary: ArtistCommentary.description(description),
                artistTags: const {},
                source: post.source,
              ),
      );
    }
    if (part == DetailsPart.stats) {
      final facts = InheritedPost.of<Post>(context).detailFacts;
      return SliverToBoxAdapter(
        child: SimplePostStatsTile(
          score: facts.score,
          favCount: facts.favoriteCount,
          totalComments: facts.commentCount,
        ),
      );
    }
    return null;
  }
}
