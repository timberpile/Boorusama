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
    this.menuItem = false,
    super.key,
  });

  final bool menuItem;
  final VoteState voteState;
  final void Function() onUpvote;
  final void Function()? onRemoveUpvote;

  @override
  Widget build(BuildContext context) {
    final onPressed = voteState.isUpvoted ? onRemoveUpvote : onUpvote;
    final icon = Icon(
      Symbols.arrow_upward,
      color: voteState.isUpvoted ? context.colors.upvoteColor : null,
    );
    if (menuItem) {
      return Semantics(
        toggled: voteState.isUpvoted,
        child: KurumiPopupMenuItem(
          title: Text(context.t.post.action.upvote),
          icon: icon,
          onTap: onPressed,
        ),
      );
    }
    return KurumiTooltip(
      message: context.t.post.action.upvote,
      child: IconButton(
        icon: icon,
        splashRadius: 16,
        onPressed: onPressed,
      ),
    );
  }
}

class DownvotePostButton extends StatelessWidget {
  const DownvotePostButton({
    required this.voteState,
    required this.onDownvote,
    required this.onRemoveDownvote,
    this.menuItem = false,
    super.key,
  });

  final bool menuItem;
  final VoteState voteState;
  final void Function() onDownvote;
  final void Function()? onRemoveDownvote;

  @override
  Widget build(BuildContext context) {
    final onPressed = voteState.isDownvoted ? onRemoveDownvote : onDownvote;
    final icon = Icon(
      Symbols.arrow_downward,
      color: voteState.isDownvoted ? context.colors.downvoteColor : null,
    );
    if (menuItem) {
      return Semantics(
        toggled: voteState.isDownvoted,
        child: KurumiPopupMenuItem(
          title: Text(context.t.post.action.downvote),
          icon: icon,
          onTap: onPressed,
        ),
      );
    }
    return KurumiTooltip(
      message: context.t.post.action.downvote,
      child: IconButton(
        icon: icon,
        splashRadius: 16,
        onPressed: onPressed,
      ),
    );
  }
}
