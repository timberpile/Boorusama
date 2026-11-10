export 'bookmark_identity.dart';
export 'post_bookmark.dart';

/// Hive's explicit integer-key range, shared by every saved payload kind.
const maxBookmarkId = 0xFFFFFFFF;

/// A local saved record. Media-only APIs explicitly consume PostBookmark.
abstract interface class Bookmark {
  int get id;
}
