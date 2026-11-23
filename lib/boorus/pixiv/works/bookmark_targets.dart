import '../../../core/bookmarks/src/types/bookmark.dart';
import '../../../core/bookmarks/src/types/content_group_bookmark.dart';
import '../../../core/bookmarks/src/types/stored_group_snapshot.dart';
import '../../../core/boorus/booru/types.dart';
import '../../../core/content/types.dart';
import '../../../core/posts/post/types.dart';
import '../posts/post_codec.dart';
import '../posts/types.dart';
import 'work_mapper.dart';

/// Frozen whole-Work facts for the existing generic Bookmark mutation path.
/// Building a draft never enumerates Pages, prepares media or changes Favorites.
final class PixivWorkBookmarkTarget {
  PixivWorkBookmarkTarget({
    required this.access,
    required this.summary,
    this.details,
  }) {
    _requireAccess(access);
    final reference = summary.reference;
    if (reference.kind != ContentKind.group || !access.accepts(reference)) {
      throw const FormatException('Foreign Pixiv Work Bookmark target');
    }
    const BooruContentKeyCodec(BooruType.pixiv)
        .canonicalize(ContentKind.group, reference.sourceKey);
    if (details != null) {
      const ContentReferenceCodec().requireCompatible(
        reference,
        details!.summary.reference,
      );
    }
  }

  final ContentAccessContext access;
  final ContentGroupSummary summary;
  final ContentGroupDetails? details;
  ContentIdentity get identity => summary.reference.identity;

  ContentGroupBookmark draft({
    required ContentAccessContext? currentAccess,
    required DateTime at,
  }) {
    _requireCurrent(access, currentAccess);
    final tags = details?.tags ?? summary.previewTags;
    return ContentGroupBookmark(
      // This is a draft only. The existing repository allocates the local ID.
      id: 0,
      snapshot: StoredGroupSnapshot(
        summary: summary,
        details: details,
        index: tags == null
            ? null
            : GroupBookmarkIndex(
                tags: {
                  for (final tag in tags.values) ...[
                    ?tag.name,
                    if (tag.displayName?.isNotEmpty ?? false) tag.displayName!,
                  ],
                },
                basis: GroupTagIndexBasis.sourceGroup,
                coverage: tags.coverage,
              ),
      ),
      createdAt: at,
      observedAt: at,
      sourceProfileHint: access.key.profileId,
    );
  }
}

/// A frozen real Page Post remains independent from the Work and later swipes.
final class PixivPageBookmarkTarget {
  PixivPageBookmarkTarget({required this.access, required this.post}) {
    _requireAccess(access);
    final data = post.pixivData;
    if (data == null ||
        data.isRestricted ||
        post.origin.booruType != BooruType.pixiv ||
        post.origin.sourceHost != access.key.siteNamespace ||
        post.origin.profileIdHint != access.key.profileId) {
      throw const FormatException('Unavailable Pixiv Page Bookmark target');
    }
    reference = pixivPageReference(access, data.illustId, data.pageIndex);
    PostContentEntry(reference: reference, post: post);
  }

  final ContentAccessContext access;
  final Post post;
  late final ContentReference reference;
  ContentIdentity get identity => reference.identity;

  PostBookmark draft({
    required ContentAccessContext? currentAccess,
    required DateTime at,
  }) {
    _requireCurrent(access, currentAccess);
    return PostBookmark.fromSnapshot(
      id: 0,
      createdAt: at,
      updatedAt: at,
      postId: post.id,
      snapshot: const StoredPostCodec().encode(
        post,
        dataCodec: const PixivPostCodec(),
      ),
      post: post,
    );
  }
}

void _requireAccess(ContentAccessContext access) {
  if (access.key.engine != BooruType.pixiv ||
      access.key.profileId == null ||
      access.config == null ||
      access.config!.anonymousReadScope != null) {
    throw const FormatException('Pixiv Bookmark target requires its actor');
  }
}

void _requireCurrent(
  ContentAccessContext access,
  ContentAccessContext? current,
) {
  if (current == null || !access.hasSameAuthorization(current)) {
    throw StateError('Pixiv Bookmark target access changed');
  }
}
