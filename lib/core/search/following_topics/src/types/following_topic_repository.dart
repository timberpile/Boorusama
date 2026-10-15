// Project imports:
import 'search_refresh.dart';
import 'topic_feed.dart';
import 'topic_organization.dart';
import 'following_topic.dart';

final class DuplicateFollowingTopicException implements Exception {}

final class MissingFollowingTopicProfileException implements Exception {}

abstract interface class FollowingTopicRepository {
  Future<List<FollowingTopic>> getAll();
  Future<List<TopicFeed>> getFeeds();
  Future<bool> migrateLegacyTopicFeeds({
    bool topicsAutoUpdateEnabled = true,
    bool feedsAutoUpdateEnabled = true,
  });

  /// Materialize a folder's feed cache on first opening. Disabled/empty
  /// folders do not allocate a cache.
  Future<TopicFeed?> ensureFolderFeed(
    String folderId, {
    String? fallbackProfileId,
  });
  Future<void> clearFolderFeedCache(String folderId);
  Future<void> clearAllFeedCaches();

  Future<TopicFeed> saveFeed({
    required String profileId,
    required String name,
    required List<String> queries,
    String? id,
  });
  Future<void> deleteFeed(String id);
  Future<void> setFeedOrder(String profileId, List<String> orderedIds);
  Future<void> restoreFeeds(String profileId, List<TopicFeed> feeds);
  Future<TopicOrganization> getOrganization();
  Future<void> replaceOrganization(TopicOrganization organization);
  Future<void> deleteSharedFolderAndTopics(String folderId);
  Future<FollowingTopic?> getById(String id);
  Future<FollowingTopic?> findByQuery(String profileId, String query);
  Future<FollowingTopic> create({
    required String profileId,
    required String query,
    SearchQueryStructure? queryStructure,
    required String? name,
    String? id,
    DateTime? createdAt,
  });
  Future<FollowingTopic> edit(
    String id, {
    required String profileId,
    required String query,
    required String? name,
  });
  Future<FollowingTopic> rename(String id, String? name);
  Future<FollowingTopic> saveTopicInNewFolder({
    required String profileId,
    required String query,
    required String? name,
    required String folderName,
    String? existingTopicId,
  });
  Future<List<FollowingTopic>> reorder(
    String profileId,
    int oldIndex,
    int newIndex,
  );
  Future<FollowingTopic?> markRead(String id);
  Future<void> setAutoUpdate(Iterable<String> ids, bool enabled);
  Future<FollowingTopic?> commitRefresh(SearchRefreshCommit commit);
  Future<FollowingTopic?> recordRefreshFailure(
    String id, {
    required DateTime expectedCreatedAt,
    int expectedRevision = 0,
    required DateTime attemptedAt,
    required SearchRefreshErrorKind kind,
    bool Function()? canCommit,
  });
  Future<void> delete(String id);
  Future<void> deleteForProfile(String profileId);
  Future<void> invalidateRuntimeForProfile(String profileId);
  Future<void> restoreForProfile(
    String profileId,
    List<FollowingTopic> topics,
  );
}
