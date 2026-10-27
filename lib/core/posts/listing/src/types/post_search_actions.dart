import 'package:flutter/widgets.dart';

import '../../../post/types.dart';

enum PostIdSearchDirection { fromHere, untilHere }

/// A route-local capability belonging to one live search and one profile.
/// Never store this callback in snapshots, search history or a saved Topic.
class PostSearchActions {
  const PostSearchActions({
    required this.profileId,
    required this.isActive,
    required this.apply,
  });

  final String profileId;
  final bool Function() isActive;
  final bool Function(Post, PostIdSearchDirection) apply;

  bool availableFor(Post post, String? targetProfileId) =>
      post.id > 0 && targetProfileId == profileId && isActive();
}

class PostSearchActionsScope extends InheritedWidget {
  const PostSearchActionsScope({
    required this.actions,
    required super.child,
    super.key,
  });

  final PostSearchActions actions;

  static PostSearchActions? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PostSearchActionsScope>()
      ?.actions;

  @override
  bool updateShouldNotify(PostSearchActionsScope oldWidget) =>
      actions != oldWidget.actions;
}
