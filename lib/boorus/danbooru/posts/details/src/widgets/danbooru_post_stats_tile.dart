// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../../../../../../core/posts/details_parts/widgets.dart';
import '../../../../../../core/posts/post/types.dart';
import '../../../../../../core/router.dart';
import '../../../../users/user/routes.dart';
import '../../../post/types.dart';

class DanbooruPostStatsTile extends ConsumerWidget {
  const DanbooruPostStatsTile({
    required this.post,
    required this.data,
    required this.commentCount,
    super.key,
  });

  final Post post;
  final DanbooruPostData? data;
  final int? commentCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SimplePostStatsTile(
      score: post.score,
      favCount: data?.favCount ?? 0,
      totalComments: commentCount ?? 0,
      votePercentText: _generatePercentText(data),
      onScoreTap: () => goToPostVotesDetails(ref, post),
      onFavCountTap: () => goToPostFavoritesDetails(ref, post),
      onTotalCommentsTap: () => goToCommentPage(context, ref, post),
    );
  }

  String _generatePercentText(DanbooruPostData? data) {
    final totalVote = (data?.upScore ?? 0) + (data?.downScore ?? 0).abs();
    return totalVote > 0
        ? '(${(((data?.upScore ?? 0) / totalVote) * 100).toInt()}% upvoted)'
        : '';
  }
}
