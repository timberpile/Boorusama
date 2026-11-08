import '../../../../bookmarks/src/types/bookmark_identity.dart';
import '../../../../configs/config/types.dart';
import '../../../post/types.dart';

/// Captured before opening a menu/dialog. Execution never reads grid indices.
class PostActionSnapshot {
  PostActionSnapshot(Iterable<Post> posts, Iterable<BooruConfig> profiles)
    : posts = List.unmodifiable(uniquePosts(posts)) {
    targets = List.unmodifiable([
      for (final post in this.posts)
        (
          post: post,
          config: switch (const PostOriginResolver().resolve(
            post.origin,
            profiles,
            allowProfileHintFallback: false,
          )) {
            ResolvedPostOrigin(:final config) => config,
            _ => null,
          },
        ),
    ]);
  }

  /// Bulk actions target content once even when several memberships are selected.
  static List<T> uniquePosts<T extends Post>(Iterable<T> posts) {
    final seen = <Object>{};
    final result = <T>[];
    for (final post in posts) {
      final identity = BookmarkIdentity.tryFromPost(post);
      if (identity == null || seen.add((post.origin.booruType, identity))) {
        result.add(post);
      }
    }
    return result;
  }

  final List<Post> posts;
  late final List<({Post post, BooruConfig? config})> targets;
  bool get isSingle => posts.length == 1;
  bool get hasTargets => posts.isNotEmpty;
  bool get allResolved => hasTargets && targets.every((t) => t.config != null);
  bool get canBookmark =>
      hasTargets && posts.every((p) => BookmarkIdentity.tryFromPost(p) != null);
  BooruConfig? get commonConfig =>
      allResolved && targets.every((t) => t.config == targets.first.config)
      ? targets.first.config
      : null;

  /// A changed/deleted account must not silently redirect a queued action.
  bool accountsMatch(Iterable<BooruConfig> profiles) => targets.every((target) {
    final resolved = const PostOriginResolver().resolve(
      target.post.origin,
      profiles,
      allowProfileHintFallback: false,
    );
    return switch (resolved) {
      ResolvedPostOrigin(:final config) => config == target.config,
      _ => target.config == null,
    };
  });
}
