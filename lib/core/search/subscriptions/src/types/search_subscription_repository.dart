// Project imports:
import 'search_refresh.dart';
import 'search_following_feed.dart';
import 'search_organization.dart';
import 'search_subscription.dart';

abstract interface class SearchSubscriptionRepository {
  Future<List<SearchSubscription>> getAll();
  Future<List<SearchFollowingFeed>> getFeeds();
  Future<SearchFollowingFeed> saveFeed({
    required int profileId,
    required String name,
    required List<String> queries,
    String? id,
  });
  Future<void> deleteFeed(String id);
  Future<void> setFeedOrder(int profileId, List<String> orderedIds);
  Future<void> restoreFeeds(int profileId, List<SearchFollowingFeed> feeds);
  Future<SearchOrganization> getOrganization();
  Future<void> replaceOrganization(SearchOrganization organization);
  Future<void> deleteSharedFolderAndPins(String folderId);
  Future<SearchSubscription?> getById(String id);
  Future<SearchSubscription?> findByQuery(int profileId, String query);
  Future<SearchSubscription> create({
    required int profileId,
    required String query,
    required String? name,
    String? id,
    DateTime? createdAt,
  });
  Future<SearchSubscription> rename(String id, String? name);
  Future<List<SearchSubscription>> reorder(
    int profileId,
    int oldIndex,
    int newIndex,
  );
  Future<SearchSubscription?> markRead(String id);
  Future<SearchSubscription?> commitRefresh(SearchRefreshCommit commit);
  Future<SearchSubscription?> recordRefreshFailure(
    String id, {
    required DateTime expectedCreatedAt,
    int expectedRevision = 0,
    required DateTime attemptedAt,
    required SearchRefreshErrorKind kind,
  });
  Future<void> delete(String id);
  Future<void> deleteForProfile(int profileId);
  Future<void> invalidateRuntimeForProfile(int profileId);
  Future<void> restoreForProfile(
    int profileId,
    List<SearchSubscription> subscriptions,
  );
}
