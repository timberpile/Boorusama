import '../../../boorus/booru/types.dart';
import '../../../content/types.dart';
import 'bookmark.dart';
import 'content_group_bookmark.dart';
import 'legacy_group_bookmark.dart';

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
