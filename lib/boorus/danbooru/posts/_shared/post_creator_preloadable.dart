// Package imports:
import 'package:equatable/equatable.dart';

// Project imports:
import '../post/types.dart';

class PostCreatorsPreloadable extends Equatable {
  factory PostCreatorsPreloadable.fromPosts(List<Post> posts) {
    final ids = posts
        .expand(
          (post) => [
            ?post.uploaderId,
            ?post.approverId,
          ],
        )
        .toSet()
        .toList();

    return PostCreatorsPreloadable._(ids);
  }

  factory PostCreatorsPreloadable.fromPost(Post post) {
    final data = post.booruData;
    final approverId = switch (data) {
      DanbooruPostData(:final approverId) => approverId,
      _ => null,
    };

    return PostCreatorsPreloadable._([
      ?post.uploaderId,
      ?approverId,
    ]);
  }
  PostCreatorsPreloadable._(Iterable<int> userIds)
    : userIds = (userIds.toSet().toList()..sort()).toList(growable: false);

  final List<int> userIds;

  @override
  List<Object?> get props => [userIds];
}
