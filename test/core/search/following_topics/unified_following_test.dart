import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/backups/sources/search_backup_profile.dart';
import 'package:boorusama/core/backups/sources/topic_feed_backup_data.dart';
import 'package:boorusama/core/backups/sources/topic_feed_import_service.dart';
import 'package:boorusama/core/posts/listing/widgets.dart';
import 'package:boorusama/core/posts/post/types.dart';
import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_test_utils.dart';

void main() {
  const firstProfile = '00000000-0000-4000-8000-000000000001';
  const secondProfile = '00000000-0000-4000-8000-000000000002';
  final now = DateTime.utc(2026, 10, 15);
  late MemorySubscriptionBox searches;
  late _FailingCacheBox storage;
  late HiveFollowingTopicRepository repository;

  setUp(() {
    searches = MemorySubscriptionBox();
    storage = _FailingCacheBox();
    repository = HiveFollowingTopicRepository(
      box: searches,
      organizationBox: storage,
    );
  });

  Post post(String site, String profile, int id) =>
      testSearchPost(id, now).copyWith(
        origin: PostOrigin.fromSource(
          booruType: BooruType.danbooru,
          booruId: 1,
          source: 'https://$site',
          profileIdHint: profile,
        ),
      );

  Future<void> commit(
    FollowingTopic source,
    List<Post> posts, {
    bool baseline = true,
  }) async {
    await repository.commitRefresh(
      SearchRefreshCommit(
        topicId: source.id,
        expectedCreatedAt: source.createdAt,
        expectedRevision: source.runtimeRevision,
        expectedCheckpoint: source.lastSuccessfulCheckAt,
        startedAt: now,
        identityRetentionBoundary: now,
        baseline: baseline,
        discoveredPosts: [
          for (final post in posts)
            SearchPostPreview(
              postId: post.id,
              postCreatedAt: now,
              thumbnailUrl: '',
              sampleUrl: null,
              discoveredAt: now,
            ),
        ],
        feedPosts: posts.map(feedPostSnapshotFromPost).toList(),
      ),
    );
  }

  Future<(FollowingTopic, FollowingTopic)> folderSources() async {
    final a = await repository.create(
      profileId: firstProfile,
      query: 'cat',
      name: null,
      id: 'a',
    );
    final b = await repository.create(
      profileId: secondProfile,
      query: 'dog',
      name: null,
      id: 'b',
    );
    await repository.replaceOrganization(
      TopicOrganization(
        folders: [
          TopicFolder(
            id: 'parent',
            name: 'Parent',
            feedEnabled: true,
            searchIds: ['a'],
          ),
          TopicFolder(
            id: 'child',
            parentId: 'parent',
            name: 'Child',
            feedEnabled: true,
            searchIds: ['b'],
          ),
        ],
        homeSearchIds: [],
      ),
    );
    await repository.ensureFolderFeed('parent');
    await repository.ensureFolderFeed('child');
    return (a, b);
  }

  test(
    'legacy scope switches become independent topic preferences once',
    () async {
      await repository.create(
        profileId: firstProfile,
        query: 'topic',
        name: null,
        id: 'topic',
      );
      final feed = await repository.saveFeed(
        profileId: firstProfile,
        name: 'Feed',
        queries: ['cat'],
      );
      expect(
        await repository.migrateLegacyTopicFeeds(
          topicsAutoUpdateEnabled: false,
        ),
        isTrue,
      );
      expect((await repository.getById('topic'))!.autoUpdateEnabled, isFalse);
      expect(
        (await repository.getById(feed.sourceIds.single))!.autoUpdateEnabled,
        isTrue,
      );
      await repository.setAutoUpdate(['topic'], true);
      expect(
        await repository.migrateLegacyTopicFeeds(
          topicsAutoUpdateEnabled: false,
        ),
        isFalse,
      );
      expect((await repository.getById('topic'))!.autoUpdateEnabled, isTrue);
    },
  );

  test(
    'a recreated backup ID starts with its own Auto-update and NEW state',
    () async {
      final original = await repository.create(
        profileId: firstProfile,
        query: 'cat',
        name: null,
        id: 'reused',
      );
      await repository.setAutoUpdate([original.id], false);
      await commit(original, [post('first.test', firstProfile, 1)]);
      await commit((await repository.getById(original.id))!, [
        post('first.test', firstProfile, 2),
      ], baseline: false);
      await repository.delete(original.id);
      final recreated = await repository.create(
        profileId: firstProfile,
        query: 'dog',
        name: null,
        id: original.id,
      );
      expect(recreated.autoUpdateEnabled, isTrue);
      expect(recreated.newPostCountEstimate, isNull);
      expect(recreated.hasNewPosts, isFalse);
    },
  );

  test(
    'legacy feed replacement and deletion never remove visible folder Topics',
    () async {
      final (a, b) = await folderSources();
      await commit(a, [post('first.test', firstProfile, 42)]);
      await commit(b, [post('second.test', secondProfile, 42)]);
      final before = await repository.getFeeds();
      final topics = await repository.getAll();
      await TopicFeedImportService(
        repository: repository,
      ).replace(TopicFeedBackupData(feeds: []), profiles: []);
      expect(await repository.getFeeds(), before);
      await expectLater(
        repository.saveFeed(
          profileId: firstProfile,
          id: 'parent',
          name: 'Overwrite',
          queries: ['different'],
        ),
        throwsStateError,
      );
      expect(await repository.getFeeds(), before);
      await repository.deleteFeed('parent');
      expect(await repository.getAll(), topics);
      expect((await repository.getOrganization()).folders, hasLength(2));
      expect((await repository.ensureFolderFeed('parent'))!.sourceIds.toSet(), {
        'a',
        'b',
      });
    },
  );

  test(
    'failed legacy replacement restores removed sources, preferences and mixed caches',
    () async {
      final (a, b) = await folderSources();
      await commit(a, [post('first.test', firstProfile, 42)]);
      await commit(b, [post('second.test', secondProfile, 42)]);
      const legacyId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
      final legacy = await repository.saveFeed(
        profileId: firstProfile,
        id: legacyId,
        name: 'Legacy',
        queries: ['bird'],
      );
      await repository.setAutoUpdate(legacy.sourceIds, false);
      final topics = await repository.getAll();
      final feeds = await repository.getFeeds();
      final organization = await repository.getOrganization();
      final profile = BooruConfig.fromJson({
        ...BooruConfig.empty.toJson(),
        'id': secondProfile,
        'booruIdHint': BooruType.danbooru.id,
        'url': 'https://second.test',
        'name': 'Second',
      });
      storage.failKey = 'feed:$legacyId';
      await expectLater(
        TopicFeedImportService(repository: repository).replace(
          TopicFeedBackupData(
            feeds: [
              TopicFeedBackupRecord(
                id: legacyId,
                name: 'Replacement',
                queries: ['different'],
                position: 0,
                profile: BackupProfileReference(
                  id: profile.id,
                  booruType: 'danbooru',
                  url: profile.url,
                  name: profile.name,
                ),
              ),
            ],
          ),
          profiles: [profile],
        ),
        throwsStateError,
      );
      expect(await repository.getAll(), topics);
      expect(await repository.getFeeds(), feeds);
      expect(await repository.getOrganization(), organization);
    },
  );

  test('mixed-site IDs survive the shared grid duplicate tracker', () {
    final tracker = PostDuplicateTracker<Post>(
      mode: DuplicateCheckMode.originAndId,
    );
    final a = post('first.test', firstProfile, 42);
    final b = post('second.test', secondProfile, 42);
    tracker.trackItem(a);
    expect(tracker.isDuplicate(b), isFalse);
    expect(tracker.isDuplicate(post('first.test', secondProfile, 42)), isTrue);
    tracker.rebuildFrom([b]);
    expect(tracker.isDuplicate(a), isFalse);
    expect(tracker.isDuplicate(b), isTrue);
    tracker.clear();
    expect(tracker.isDuplicate(b), isFalse);
  });

  test(
    'nested mixed feeds invalidate only changed profile sources and persist progress',
    () async {
      final (a, b) = await folderSources();
      await commit(a, [post('first.test', firstProfile, 42)]);
      await commit(b, [post('second.test', secondProfile, 42)]);
      var parent = (await repository.getFeeds()).firstWhere(
        (f) => f.id == 'parent',
      );
      expect(parent.posts, hasLength(2));
      expect(parent.initializedSourceIds.toSet(), {'a', 'b'});
      repository = HiveFollowingTopicRepository(
        box: searches,
        organizationBox: storage,
      );
      await repository.invalidateRuntimeForProfile(secondProfile);
      parent = (await repository.getFeeds()).firstWhere(
        (f) => f.id == 'parent',
      );
      expect(parent.posts.single.origin.profileIdHint, firstProfile);
      expect(parent.initializedSourceIds, ['a']);
      expect(parent.sourceIds.toSet(), {'a', 'b'});
      expect(
        (await repository.getFeeds()).firstWhere((f) => f.id == 'child').posts,
        isEmpty,
      );
      expect((await repository.getById('a'))!.hasBaseline, isTrue);
      expect((await repository.getById('b'))!.hasBaseline, isFalse);
      await commit((await repository.getById('b'))!, [
        post('replacement.test', secondProfile, 42),
      ]);
      parent = (await repository.getFeeds()).firstWhere(
        (f) => f.id == 'parent',
      );
      expect(parent.posts.map((p) => p.origin.sourceHost).toSet(), {
        'first.test',
        'replacement.test',
      });
    },
  );

  test(
    'overlapping same-site matches survive topic edits and membership removal',
    () async {
      final (a, b) = await folderSources();
      final shared = post('first.test', firstProfile, 42);
      await commit(a, [shared, post('first.test', firstProfile, 43)]);
      await commit(b, [shared]);
      await repository.edit(
        'a',
        profileId: firstProfile,
        query: 'bird',
        name: null,
      );
      var parent = (await repository.getFeeds()).firstWhere(
        (f) => f.id == 'parent',
      );
      expect(parent.posts.map(feedPostId), [42]);
      expect(parent.initializedSourceIds, ['b']);
      await repository.delete('b');
      parent = (await repository.getFeeds()).firstWhere(
        (f) => f.id == 'parent',
      );
      expect(parent.posts, isEmpty);
      expect((await repository.getById('a'))!.query, 'bird');
    },
  );

  test(
    'a failure writing a later feed rolls back every cache and topic checkpoint',
    () async {
      final (_, b) = await folderSources();
      final before = await repository.getFeeds();
      storage.failKey = 'feed:child';
      await expectLater(
        commit(b, [post('second.test', secondProfile, 42)]),
        throwsStateError,
      );
      expect(await repository.getFeeds(), before);
      expect((await repository.getById('b'))!.hasBaseline, isFalse);
      expect((await repository.getById('b'))!.newPostCountEstimate, isNull);
    },
  );

  test(
    'clearing caches preserves folders and independent topic preferences',
    () async {
      final (a, b) = await folderSources();
      await commit(a, [post('first.test', firstProfile, 42)]);
      await commit(b, [post('second.test', secondProfile, 42)]);
      await repository.setAutoUpdate(['a'], false);
      final topics = await repository.getAll();
      final organization = await repository.getOrganization();
      await repository.clearAllFeedCaches();
      expect(await repository.getAll(), topics);
      expect(await repository.getOrganization(), organization);
      for (final feed in await repository.getFeeds()) {
        expect(feed.posts, isEmpty);
        expect(feed.postSources, isEmpty);
        expect(feed.initializedSourceIds, isEmpty);
      }
    },
  );

  test(
    'migration clones disabled Auto-update and unread estimates with shared sources',
    () async {
      final first = await repository.saveFeed(
        profileId: firstProfile,
        name: 'One',
        queries: ['cat'],
      );
      await repository.saveFeed(
        profileId: firstProfile,
        name: 'Two',
        queries: ['cat'],
      );
      final source = (await repository.getById(first.sourceIds.single))!;
      await commit(source, [post('first.test', firstProfile, 1)]);
      await commit((await repository.getById(source.id))!, [
        post('first.test', firstProfile, 2),
      ], baseline: false);
      await repository.setAutoUpdate([source.id], false);
      await repository.migrateLegacyTopicFeeds();
      final topics = await repository.getAll();
      expect(topics, hasLength(2));
      expect(topics.map((t) => t.id).toSet(), hasLength(2));
      for (final topic in topics) {
        expect(topic.autoUpdateEnabled, isFalse);
        expect(topic.newPostCountEstimate, 1);
        expect(topic.hasNewPosts, isTrue);
      }
    },
  );
}

class _FailingCacheBox extends MemoryBox<dynamic> {
  String? failKey;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (key == failKey) {
      failKey = null;
      throw StateError('injected feed write failure');
    }
    await super.put(key, value);
  }
}
