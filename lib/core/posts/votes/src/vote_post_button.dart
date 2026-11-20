// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../../../themes/theme/types.dart';
import 'post_vote.dart';

class UpvotePostButton extends StatelessWidget {
  const UpvotePostButton({
    required this.voteState,
    required this.onUpvote,
    required this.onRemoveUpvote,
    super.key,
  });

  final VoteState voteState;
  final void Function() onUpvote;
  final void Function()? onRemoveUpvote;

  VoidCallback? get action => switch (voteState) {
    VoteState.upvoted => onRemoveUpvote,
    _ => onUpvote,
  };

  @override
  Widget build(BuildContext context) {
    return KurumiTooltip(
      message: context.t.post.action.upvote,
      child: IconButton(
        icon: Icon(
          Symbols.arrow_upward,
          color: voteState.isUpvoted ? context.colors.upvoteColor : null,
        ),
        splashRadius: 16,
        onPressed: action,
      ),
    );
  }
}

class DownvotePostButton extends StatelessWidget {
  const DownvotePostButton({
    required this.voteState,
    required this.onDownvote,
    required this.onRemoveDownvote,
    super.key,
  });

  final VoteState voteState;
  final void Function() onDownvote;
  final void Function()? onRemoveDownvote;

  VoidCallback? get action => switch (voteState) {
    VoteState.downvoted => onRemoveDownvote,
    _ => onDownvote,
  };

  @override
  Widget build(BuildContext context) {
    return KurumiTooltip(
      message: context.t.post.action.downvote,
      child: IconButton(
        icon: Icon(
          Symbols.arrow_downward,
          color: voteState.isDownvoted ? context.colors.downvoteColor : null,
        ),
        splashRadius: 16,
        onPressed: action,
      ),
    );
  }
}
