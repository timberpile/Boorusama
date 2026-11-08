import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../configs/manage/providers.dart';
import '../../../../content/content_access.dart';
import '../../../../content/content_access_provider.dart';
import '../../../../content/content_media_access.dart';
import '../../../../bookmarks/src/types/bookmark_identity.dart';
import '../../../../configs/config/types.dart';
import '../../../post/types.dart';

/// Captured before opening a menu/dialog. Execution never reads grid indices.
class PostActionSnapshot {
  PostActionSnapshot(
    Iterable<Post> posts,
    Iterable<BooruConfig> profiles, {
    this.accessRequired = false,
    this.access,
    this.isAccessCurrent,
  }) : posts = List.unmodifiable(uniquePosts(posts)) {
    targets = List.unmodifiable([
      for (final post in this.posts)
        (
          post: post,
          config: accessRequired
              ? _boundConfig(post, access)
              : switch (const PostOriginResolver().resolve(
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

  static PostActionSnapshot watch(WidgetRef ref, Iterable<Post> posts) {
    final required = ref.watch(contentAccessRequiredProvider);
    final key = ref.watch(currentContentAccessKeyProvider);
    final access = key == null
        ? null
        : ref.watch(contentAccessContextProvider(key));
    return PostActionSnapshot(
      posts,
      ref.watch(booruConfigProvider),
      accessRequired: required,
      access: access,
      isAccessCurrent: () =>
          key != null &&
          access != null &&
          identical(ref.read(contentAccessContextProvider(key)), access),
    );
  }

  static BooruConfig? _boundConfig(Post post, ContentAccessContext? access) {
    if (access == null ||
        access.key.profileId == null ||
        post.origin.booruType != access.key.engine ||
        post.origin.sourceHost != access.key.siteNamespace ||
        (post.origin.profileIdHint != null &&
            post.origin.profileIdHint != access.key.profileId))
      return null;
    return access.config;
  }

  final bool accessRequired;
  final ContentAccessContext? access;
  final bool Function()? isAccessCurrent;

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
  bool accountsMatch(Iterable<BooruConfig> profiles) {
    if (accessRequired)
      return (isAccessCurrent?.call() ?? false) &&
          (access?.key.profileId == null || access!.matchesProfiles(profiles));
    return targets.every((target) {
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
}
