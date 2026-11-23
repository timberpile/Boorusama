import '../../../boorus/booru/types.dart';
import '../../../content/types.dart';
import '../../../posts/post/types.dart';
import 'bookmark.dart';
import 'content_group_bookmark.dart';
import 'legacy_group_bookmark.dart';
import 'bookmark_search_token.dart';

/// Local IDs address every record, including retained unaddressable media.
/// Only independently established source facts enter the content index.
ContentIdentity? bookmarkContentIdentity(Bookmark bookmark) =>
    switch (bookmark) {
      PostBookmark(uniqueId: final BookmarkIdentity identity)
          when bookmark.post.origin.booruType != BooruType.unknown =>
        (
          siteNamespace: identity.site,
          kind: ContentKind.post,
          sourceKey: identity.postKey,
        ),
      ContentGroupBookmark() => bookmark.reference.identity,
      LegacyGroupBookmark() => bookmark.identity,
      _ => null,
    };

BooruType bookmarkEngine(Bookmark bookmark) => switch (bookmark) {
  PostBookmark() => bookmark.post.origin.booruType,
  ContentGroupBookmark() => bookmark.reference.engine,
  LegacyGroupBookmark() => bookmark.metadata.origin.booruType,
  _ => throw const FormatException('Unsupported Bookmark record'),
};

DateTime bookmarkCreatedAt(Bookmark bookmark) => switch (bookmark) {
  PostBookmark() => bookmark.createdAt,
  ContentGroupBookmark() => bookmark.createdAt,
  LegacyGroupBookmark() => bookmark.createdAt,
  _ => throw const FormatException('Unsupported Bookmark record'),
};

Bookmark bookmarkWithId(Bookmark bookmark, int id) {
  if (id < 0) throw const FormatException('Invalid Bookmark ID');
  return switch (bookmark) {
    PostBookmark() => bookmark.copyWith(id: id),
    ContentGroupBookmark() => bookmark.copyWith(id: id),
    LegacyGroupBookmark() => bookmark.copyWith(id: id),
    _ => throw const FormatException('Unsupported Bookmark record'),
  };
}

PostOrigin nativeBookmarkGroupOrigin(ContentGroupBookmark bookmark) =>
    PostOrigin.fromSource(
      booruType: bookmark.reference.engine,
      booruId: bookmark.reference.engine.id,
      source: bookmark.reference.site.toString(),
      profileIdHint: bookmark.sourceProfileHint,
    );

Set<String> nativeGroupBookmarkTags(ContentGroupBookmark record) => {
  ...?record.snapshot.index?.tags.map(canonicalBookmarkTag),
  for (final tag
      in (record.snapshot.details?.tags ?? record.summary.previewTags)
              ?.values ??
          const []) ...[
    if (tag.name case final name?) canonicalBookmarkTag(name),
    if (tag.displayName case final name?) canonicalBookmarkTag(name),
  ],
};

bool isNativeGroupBookmark(Bookmark record) =>
    record is ContentGroupBookmark &&
    !record.reference.sourceKey.startsWith('pool:') &&
    !record.reference.sourceKey.startsWith('related:');
