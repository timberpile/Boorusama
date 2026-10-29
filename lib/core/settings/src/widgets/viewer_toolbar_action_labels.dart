import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

import '../types/viewer_toolbar_layout.dart';

String viewerToolbarActionLabel(
  BuildContext context,
  ViewerToolbarAction action,
) => switch (action) {
  ViewerToolbarAction.comments => context.t.comment.comments,
  ViewerToolbarAction.download => context.t.download.download,
  ViewerToolbarAction.bookmark => context.t.post.action.bookmark,
  ViewerToolbarAction.favorite => context.t.post.action.favorite,
  ViewerToolbarAction.share => context.t.post.action.share,
  ViewerToolbarAction.upvote => context.t.post.action.upvote,
  ViewerToolbarAction.downvote => context.t.post.action.downvote,
  ViewerToolbarAction.tags => context.t.post.action.view_tags,
  ViewerToolbarAction.browser => context.t.post.action.view_in_browser,
  ViewerToolbarAction.original => context.t.post.action.load_original,
  ViewerToolbarAction.slideshow => context.t.post.action.slideshow,
  ViewerToolbarAction.favoriteGroup =>
    context.t.post.action.add_to_favorite_group,
  ViewerToolbarAction.tagHistory => context.t.post.action.view_tag_history,
};

IconData viewerToolbarActionIcon(ViewerToolbarAction action) =>
    switch (action) {
      ViewerToolbarAction.comments => Icons.comment_outlined,
      ViewerToolbarAction.download => Icons.download,
      ViewerToolbarAction.bookmark => Icons.bookmark_border,
      ViewerToolbarAction.favorite => Icons.favorite_border,
      ViewerToolbarAction.share => Icons.share,
      ViewerToolbarAction.upvote => Icons.arrow_upward,
      ViewerToolbarAction.downvote => Icons.arrow_downward,
      ViewerToolbarAction.tags => Icons.tag,
      ViewerToolbarAction.browser => Icons.open_in_browser,
      ViewerToolbarAction.original => Icons.fullscreen,
      ViewerToolbarAction.slideshow => Icons.slideshow,
      ViewerToolbarAction.favoriteGroup => Icons.folder_special,
      ViewerToolbarAction.tagHistory => Icons.history,
    };
