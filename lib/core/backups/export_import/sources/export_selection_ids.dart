final class ExportSelectionIds {
  const ExportSelectionIds._();

  static const ungroupedBookmarks = 'ungrouped';
  static const followingTopicHome = 'home';

  static String bookmarkGroup(String id) => 'group:$id';

  static String followingTopic(String id) => 'search:$id';

  static String followingTopicFolder(String id) => 'folder:$id';

  static String topicFeed(String id) => 'feed:$id';

  static String profile(String id) => 'profile:$id';

  static String? bookmarkGroupId(String childId) => _value(childId, 'group:');

  static String? followingTopicId(String childId) => _value(childId, 'search:');

  static String? followingTopicFolderId(String childId) =>
      _value(childId, 'folder:');

  static String? topicFeedId(String childId) => _value(childId, 'feed:');

  static String? profileId(String childId) => _value(childId, 'profile:');

  static String? _value(String childId, String prefix) {
    if (!childId.startsWith(prefix) || childId.length == prefix.length) {
      return null;
    }
    return childId.substring(prefix.length);
  }
}
