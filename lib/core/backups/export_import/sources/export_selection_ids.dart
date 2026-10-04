final class ExportSelectionIds {
  const ExportSelectionIds._();

  static const ungroupedBookmarks = 'ungrouped';
  static const pinnedSearchHome = 'home';

  static String bookmarkGroup(String id) => 'group:$id';

  static String pinnedSearch(String id) => 'search:$id';

  static String pinnedSearchFolder(String id) => 'folder:$id';

  static String followingFeed(String id) => 'feed:$id';

  static String profile(String id) => 'profile:$id';

  static String? bookmarkGroupId(String childId) => _value(childId, 'group:');

  static String? pinnedSearchId(String childId) => _value(childId, 'search:');

  static String? pinnedSearchFolderId(String childId) =>
      _value(childId, 'folder:');

  static String? followingFeedId(String childId) => _value(childId, 'feed:');

  static String? profileId(String childId) => _value(childId, 'profile:');

  static String? _value(String childId, String prefix) {
    if (!childId.startsWith(prefix) || childId.length == prefix.length) {
      return null;
    }
    return childId.substring(prefix.length);
  }
}
