// Dart imports:
import 'dart:io';
import 'dart:convert';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/recent_search_post_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_post_preview_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'subscription_test_utils.dart';

class FailingOrganizationBox extends MemoryBox<dynamic> {
  var failWrites = false;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failWrites) throw StateError('organization write failed');
    await super.put(key, value);
  }
}

void main() {
  const boxName = 'pinned_search_subscriptions_test';
  final createdAt = DateTime.utc(2026, 9, 14, 8);

  late Directory tempDirectory;
  late Box<SearchSubscriptionHiveObject> box;
  late HiveSearchSubscriptionRepository repository;
  late Box<dynamic> organizationBox;

  SearchPostPreview preview(
    int id,
    DateTime createdAt, {
    DateTime? discoveredAt,
  }) {
    return SearchPostPreview(
      postId: id,
      postCreatedAt: createdAt,
      thumbnailUrl: 'https://example.com/$id.jpg',
      sampleUrl: null,
      discoveredAt: discoveredAt ?? createdAt,
    );
  }

  SearchRefreshCommit commit({
    required String subscriptionId,
    required DateTime? expectedCheckpoint,
    required DateTime startedAt,
    required bool baseline,
    required List<SearchPostPreview> discoveredPosts,
    DateTime? identityRetentionBoundary,
  }) {
    return SearchRefreshCommit(
      subscriptionId: subscriptionId,
      expectedCreatedAt: createdAt,
      expectedCheckpoint: expectedCheckpoint,
      startedAt: startedAt,
      identityRetentionBoundary:
          identityRetentionBoundary ?? DateTime.utc(2026, 9),
      baseline: baseline,
      discoveredPosts: discoveredPosts,
    );
  }

  test(
    'feed ownership and materialized results survive closing both Hive boxes',
    () async {
      final pin = await repository.create(
        profileId: 12,
        query: 'cat',
        name: null,
      );
      final feed = await repository.saveFeed(
        profileId: 12,
        name: 'Animals',
        queries: ['cat'],
      );
      final source = (await repository.getAll()).singleWhere(
        (s) => s.feedId == feed.id,
      );
      await repository.commitRefresh(
        SearchRefreshCommit(
          subscriptionId: source.id,
          expectedCreatedAt: source.createdAt,
          expectedCheckpoint: null,
          startedAt: createdAt,
          identityRetentionBoundary: createdAt,
          baseline: true,
          discoveredPosts: const [],
          feedPosts: [CachedFeedPost.fromPost(TestSearchPost(7, createdAt))],
        ),
      );
      await box.close();
      await organizationBox.close();
      box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
      organizationBox = await Hive.openBox<dynamic>('folder_test');
      repository = HiveSearchSubscriptionRepository(
        box: box,
        organizationBox: organizationBox,
      );
      expect((await repository.getById(source.id))!.feedId, feed.id);
      expect((await repository.getFeeds()).single.posts.single.id, 7);
      expect((await repository.findByQuery(12, 'cat'))!.id, pin.id);
      await repository.deleteFeed(feed.id);
      expect((await repository.getAll()).single.id, pin.id);
    },
  );

  for (final sourceCount in [100, 1000]) {
    test(
      'a $sourceCount source feed opens from a bounded cache and merges incrementally',
      () async {
        final creation = Stopwatch()..start();
        final feed = await repository.saveFeed(
          profileId: 12,
          name: 'Large feed',
          queries: [for (var i = 0; i < sourceCount; i++) 'source_$i'],
        );
        creation.stop();
        final sources = (await repository.getAll())
            .where((s) => s.feedId == feed.id)
            .toList();
        final updates = Stopwatch()..start();
        for (var batch = 0; batch < 11; batch++) {
          final source = sources[batch];
          await repository.commitRefresh(
            SearchRefreshCommit(
              subscriptionId: source.id,
              expectedCreatedAt: source.createdAt,
              expectedCheckpoint: null,
              startedAt: createdAt,
              identityRetentionBoundary: createdAt,
              baseline: true,
              discoveredPosts: const [],
              feedPosts: [
                for (var i = 0; i < 50; i++)
                  CachedFeedPost.fromPost(
                    TestSearchPost(
                      batch * 50 + i,
                      createdAt.add(Duration(seconds: batch * 50 + i)),
                    ),
                  ),
              ],
            ),
          );
        }
        updates.stop();
        final opening = Stopwatch()..start();
        final materialized = (await repository.getFeeds()).single;
        opening.stop();
        expect(materialized.posts.length, followingFeedRetention);
        expect(materialized.posts.first.id, 549);
        expect(materialized.posts.last.id, 50);
        expect(
          (await repository.getAll()).where((s) => s.hasBaseline).length,
          11,
        );
        final bytes = utf8.encode(jsonEncode(materialized.toJson())).length;
        stdout.writeln(
          'FEED_BENCH sources=$sourceCount create_ms=${creation.elapsedMicroseconds / 1000} merge_11_ms=${updates.elapsedMicroseconds / 1000} cached_open_ms=${opening.elapsedMicroseconds / 1000} cache_bytes=$bytes',
        );
        await expectLater(
          repository.saveFeed(
            profileId: 12,
            name: 'Too large',
            queries: [
              for (var i = 0; i <= followingFeedSourceLimit; i++) 'overflow_$i',
            ],
          ),
          throwsFormatException,
        );
      },
    );
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'search_subscription_repository_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SearchSubscriptionHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
    }
    box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
    organizationBox = await Hive.openBox<dynamic>('folder_test');
    repository = HiveSearchSubscriptionRepository(
      box: box,
      organizationBox: organizationBox,
    );
  });

  test(
    'folders survive reopening and deleting a pin removes its membership',
    () async {
      final search = await repository.create(
        profileId: 12,
        query: 'cat',
        name: null,
      );
      await repository.replaceFolders(12, [
        SearchFolder(
          id: 'folder',
          profileId: 12,
          name: 'Cats',
          position: 0,
          searchIds: [search.id],
        ),
      ]);
      await organizationBox.close();
      organizationBox = await Hive.openBox<dynamic>('folder_test');
      repository = HiveSearchSubscriptionRepository(
        box: box,
        organizationBox: organizationBox,
      );
      expect((await repository.getFolders()).single.searchIds, {search.id});
      await repository.delete(search.id);
      expect((await repository.getFolders()).single.searchIds, isEmpty);
      await repository.deleteForProfile(12);
      expect(await repository.getFolders(), isEmpty);
    },
  );

  test(
    'stores one ordered organization across profiles and recovers unlisted pins in Home',
    () async {
      final cat = await repository.create(
        profileId: 12,
        query: 'cat',
        name: null,
        id: 'cat',
        createdAt: DateTime.utc(2026, 9, 14),
      );
      final dog = await repository.create(
        profileId: 99,
        query: 'dog',
        name: null,
        id: 'dog',
        createdAt: DateTime.utc(2026, 9, 15),
      );
      final bird = await repository.create(
        profileId: 12,
        query: 'bird',
        name: null,
        id: 'bird',
        createdAt: DateTime.utc(2026, 9, 16),
      );
      final feed = await repository.saveFeed(
        profileId: 12,
        name: 'Feed',
        queries: ['fish'],
      );
      final source = (await repository.getAll()).singleWhere(
        (search) => search.feedId == feed.id,
      );
      final folder = SharedSearchFolder(
        id: 'animals',
        name: 'Animals',
        searchIds: [cat.id, dog.id],
      );

      await repository.replaceOrganization(
        SearchOrganization(folders: [folder], homeSearchIds: const []),
      );
      await box.close();
      await organizationBox.close();
      box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
      organizationBox = await Hive.openBox<dynamic>('folder_test');
      repository = HiveSearchSubscriptionRepository(
        box: box,
        organizationBox: organizationBox,
      );

      expect(
        (await repository.getOrganization()).folders.single.searchIds,
        [cat.id, dog.id],
      );
      expect(
        (await repository.getAll())
            .where((search) => search.feedId == null)
            .map((search) => search.profileId),
        [12, 12, 99],
      );
      expect((await repository.getOrganization()).homeSearchIds, [bird.id]);

      final stored = await repository.getOrganization();
      await expectLater(
        repository.replaceOrganization(
          SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: folder.id,
                name: folder.name,
                searchIds: [source.id],
              ),
            ],
            homeSearchIds: const [],
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.replaceOrganization(
          SearchOrganization(
            folders: [folder],
            homeSearchIds: [cat.id],
          ),
        ),
        throwsStateError,
      );
      expect(await repository.getOrganization(), stored);

      await organizationBox.put(
        'search:organization',
        SearchOrganization(
          folders: [folder],
          homeSearchIds: ['stale', bird.id],
        ).toJson(),
      );

      expect(
        await repository.getOrganization(),
        SearchOrganization(folders: [folder], homeSearchIds: [bird.id]),
      );
    },
  );

  test('preserves explicit Home order after reopening Hive storage', () async {
    final first = await repository.create(
      profileId: 12,
      query: 'first',
      name: null,
      id: 'first',
      createdAt: DateTime.utc(2026, 9, 14),
    );
    final second = await repository.create(
      profileId: 99,
      query: 'second',
      name: null,
      id: 'second',
      createdAt: DateTime.utc(2026, 9, 15),
    );
    await repository.replaceOrganization(
      SearchOrganization(
        folders: const [],
        homeSearchIds: [second.id, first.id],
      ),
    );
    await box.close();
    await organizationBox.close();
    box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
    organizationBox = await Hive.openBox<dynamic>('folder_test');
    repository = HiveSearchSubscriptionRepository(
      box: box,
      organizationBox: organizationBox,
    );

    expect(
      (await repository.getOrganization()).homeSearchIds,
      [second.id, first.id],
    );
  });

  test(
    'folder membership rejects cross-profile searches without changing stored folders',
    () async {
      final other = await repository.create(
        profileId: 99,
        query: 'cat',
        name: null,
      );
      await expectLater(
        repository.replaceFolders(12, [
          SearchFolder(
            id: 'folder',
            profileId: 12,
            name: 'Cats',
            position: 0,
            searchIds: [other.id],
          ),
        ]),
        throwsStateError,
      );
      expect(await repository.getFolders(), isEmpty);
    },
  );

  tearDown(() async {
    await box.close();
    await organizationBox.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'stores a blank name as null and finds the same normalized query',
    () async {
      final created = await repository.create(
        profileId: 4,
        query: '  cat   rating:safe  ',
        name: ' ',
        createdAt: DateTime.utc(2026),
      );

      expect(created.name, isNull);
      expect(
        (await repository.findByQuery(4, 'cat rating:safe'))?.id,
        created.id,
      );
    },
  );

  test(
    'prevents duplicate normalized queries only within one profile',
    () async {
      await repository.create(
        profileId: 4,
        query: 'cat   rating:safe',
        name: null,
        id: 'first',
        createdAt: createdAt,
      );

      await expectLater(
        repository.create(
          profileId: 4,
          query: ' cat rating:safe ',
          name: null,
          id: 'duplicate',
          createdAt: createdAt,
        ),
        throwsStateError,
      );
      final otherProfile = await repository.create(
        profileId: 5,
        query: 'cat rating:safe',
        name: null,
        id: 'other-profile',
        createdAt: createdAt,
      );

      expect(otherProfile.profileId, 5);
    },
  );

  test('reorders one profile into contiguous positions', () async {
    final first = await repository.create(
      profileId: 4,
      query: 'first',
      name: null,
      id: 'first',
      createdAt: createdAt,
    );
    final second = await repository.create(
      profileId: 4,
      query: 'second',
      name: null,
      id: 'second',
      createdAt: createdAt,
    );
    await repository.create(
      profileId: 5,
      query: 'other',
      name: null,
      id: 'other',
      createdAt: createdAt,
    );

    final reordered = await repository.reorder(4, 1, 0);

    expect(reordered.map((item) => item.id), [second.id, first.id]);
    expect(reordered.map((item) => item.position), [0, 1]);
    expect((await repository.getById('other'))?.position, 0);
  });

  test('keeps the four newest previews after a refresh', () async {
    final subscription = await repository.create(
      profileId: 4,
      query: 'cat',
      name: null,
      id: 'previews',
      createdAt: createdAt,
    );
    final committed = await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: null,
        startedAt: DateTime.utc(2026, 9, 14, 9),
        baseline: true,
        discoveredPosts: [
          preview(1, DateTime.utc(2026, 9, 10)),
          preview(2, DateTime.utc(2026, 9, 14)),
          preview(3, DateTime.utc(2026, 9, 12)),
          preview(4, DateTime.utc(2026, 9, 11)),
          preview(5, DateTime.utc(2026, 9, 13)),
        ],
      ),
    );

    expect(committed?.previews.map((item) => item.postId), [2, 5, 3, 4]);
  });

  test(
    'deduplicates overlapping identities before detecting new uploads',
    () async {
      final subscription = await repository.create(
        profileId: 4,
        query: 'cat',
        name: null,
        id: 'overlap',
        createdAt: createdAt,
      );
      final checkpoint = DateTime.utc(2026, 9, 14, 9);
      await repository.commitRefresh(
        commit(
          subscriptionId: subscription.id,
          expectedCheckpoint: null,
          startedAt: checkpoint,
          baseline: true,
          discoveredPosts: [preview(1, checkpoint)],
        ),
      );

      final committed = await repository.commitRefresh(
        commit(
          subscriptionId: subscription.id,
          expectedCheckpoint: checkpoint,
          startedAt: DateTime.utc(2026, 9, 14, 10),
          baseline: false,
          discoveredPosts: [
            preview(1, checkpoint),
            preview(2, DateTime.utc(2026, 9, 14, 10)),
          ],
        ),
      );

      expect(committed?.unreadCount, 1);
      expect(
        committed?.recentPostIdentities.map((item) => item.postId),
        unorderedEquals([
          1,
          2,
        ]),
      );
    },
  );

  test('old matches prune identities without setting NEW', () async {
    final subscription = await repository.create(
      profileId: 4,
      query: 'cat',
      name: null,
      id: 'retention',
      createdAt: createdAt,
    );
    final checkpoint = DateTime.utc(2026, 9, 12);
    await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: null,
        startedAt: checkpoint,
        baseline: true,
        discoveredPosts: [
          preview(1, DateTime.utc(2026, 9, 9)),
          preview(2, DateTime.utc(2026, 9, 10)),
          preview(3, DateTime.utc(2026, 9, 11)),
        ],
      ),
    );

    final committed = await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: checkpoint,
        startedAt: DateTime.utc(2026, 9, 13),
        identityRetentionBoundary: DateTime.utc(2026, 9, 10),
        baseline: false,
        discoveredPosts: [
          preview(4, DateTime.utc(2026, 9, 9)),
          preview(5, DateTime.utc(2026, 9, 10)),
          preview(6, DateTime.utc(2026, 9, 11)),
        ],
      ),
    );

    expect(committed?.hasNewPosts, isFalse);
    expect(
      committed?.recentPostIdentities.map((item) => item.postId),
      unorderedEquals([
        2,
        3,
        5,
        6,
      ]),
    );
  });

  test(
    'repeated snapshots retain only the newest bounded identity window',
    () async {
      final subscription = await repository.create(
        profileId: 4,
        query: 'cat',
        name: null,
        id: 'bounded',
        createdAt: createdAt,
      );
      DateTime? checkpoint;
      for (var round = 0; round < 3; round++) {
        final startedAt = DateTime.utc(2026, 9, 14, 9, round);
        final saved = await repository.commitRefresh(
          commit(
            subscriptionId: subscription.id,
            expectedCheckpoint: checkpoint,
            startedAt: startedAt,
            baseline: checkpoint == null,
            discoveredPosts: [
              for (var offset = 49; offset >= 0; offset--)
                preview(
                  round * 50 + offset,
                  startedAt.add(Duration(seconds: offset)),
                ),
            ],
          ),
        );
        expect(saved!.recentPostIdentities.length, 50);
        expect(saved.previews.length, 4);
        expect(
          saved.recentPostIdentities.map((post) => post.postId),
          unorderedEquals([
            for (var offset = 0; offset < 50; offset++) round * 50 + offset,
          ]),
        );
        expect(saved.hasNewPosts, round > 0);
        checkpoint = startedAt;
      }
      await repository.markRead(subscription.id);
      expect((await repository.getById(subscription.id))!.hasNewPosts, isFalse);
    },
  );

  test('commits a baseline with no unread posts', () async {
    final subscription = await repository.create(
      profileId: 4,
      query: 'cat',
      name: null,
      id: 'baseline',
      createdAt: createdAt,
    );

    final committed = await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: null,
        startedAt: DateTime.utc(2026, 9, 14, 9),
        baseline: true,
        discoveredPosts: [preview(1, DateTime.utc(2026, 9, 14, 9))],
      ),
    );

    expect(committed?.unreadCount, 0);
    expect(committed?.lastSuccessfulCheckAt, DateTime.utc(2026, 9, 14, 9));
  });

  test('rejects a refresh whose checkpoint has become stale', () async {
    final subscription = await repository.create(
      profileId: 4,
      query: 'cat',
      name: null,
      id: 'stale',
      createdAt: createdAt,
    );
    await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: null,
        startedAt: DateTime.utc(2026, 9, 14, 9),
        baseline: true,
        discoveredPosts: const [],
      ),
    );

    final stale = await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: null,
        startedAt: DateTime.utc(2026, 9, 14, 10),
        baseline: false,
        discoveredPosts: [preview(1, DateTime.utc(2026, 9, 14, 10))],
      ),
    );

    expect(stale, isNull);
    expect((await repository.getById(subscription.id))?.unreadCount, 0);
  });

  final staleIncarnationCases = [
    (description: 'successful result', fails: false),
    (description: 'failure', fails: true),
  ];
  for (final c in staleIncarnationCases) {
    test(
      'rejects an old ${c.description} after recreating the same subscription ID',
      () async {
        final original = await repository.create(
          profileId: 4,
          query: 'cat',
          name: null,
          id: 'reused',
          createdAt: createdAt,
        );
        final pendingCommit = commit(
          subscriptionId: original.id,
          expectedCheckpoint: null,
          startedAt: createdAt.add(const Duration(minutes: 5)),
          baseline: true,
          discoveredPosts: [preview(42, createdAt)],
        );
        await repository.delete(original.id);
        final restored = await repository.create(
          profileId: 4,
          query: 'cat',
          name: null,
          id: original.id,
          createdAt: createdAt.add(const Duration(hours: 1)),
        );
        final result = c.fails
            ? await repository.recordRefreshFailure(
                original.id,
                expectedCreatedAt: original.createdAt,
                attemptedAt: pendingCommit.startedAt,
                kind: SearchRefreshErrorKind.network,
              )
            : await repository.commitRefresh(pendingCommit);

        expect(result, isNull);
        expect(await repository.getById(original.id), restored);
      },
    );
  }

  test('preserves refresh state when recording a failure', () async {
    final subscription = await repository.create(
      profileId: 4,
      query: 'cat',
      name: null,
      id: 'failure',
      createdAt: createdAt,
    );
    final checkpoint = DateTime.utc(2026, 9, 14, 9);
    await repository.commitRefresh(
      commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: null,
        startedAt: checkpoint,
        baseline: true,
        discoveredPosts: [preview(1, checkpoint)],
      ),
    );

    final failed = await repository.recordRefreshFailure(
      subscription.id,
      expectedCreatedAt: subscription.createdAt,
      attemptedAt: DateTime.utc(2026, 9, 14, 10),
      kind: SearchRefreshErrorKind.network,
    );

    expect(failed?.lastSuccessfulCheckAt, checkpoint);
    expect(failed?.previews.map((item) => item.postId), [1]);
    expect(failed?.lastErrorKind, SearchRefreshErrorKind.network);
  });

  test(
    'commits new discoveries without overwriting a concurrent mark read',
    () async {
      final subscription = await repository.create(
        profileId: 4,
        query: 'cat',
        name: null,
        id: 'mark-read',
        createdAt: createdAt,
      );
      final checkpoint = DateTime.utc(2026, 9, 14, 9);
      await repository.commitRefresh(
        commit(
          subscriptionId: subscription.id,
          expectedCheckpoint: null,
          startedAt: checkpoint,
          baseline: true,
          discoveredPosts: const [],
        ),
      );
      final seededCheckpoint = DateTime.utc(2026, 9, 14, 9, 30);
      await repository.commitRefresh(
        commit(
          subscriptionId: subscription.id,
          expectedCheckpoint: checkpoint,
          startedAt: seededCheckpoint,
          baseline: false,
          discoveredPosts: [
            preview(1, DateTime.utc(2026, 9, 14, 9, 10)),
            preview(2, DateTime.utc(2026, 9, 14, 9, 20)),
          ],
        ),
      );
      final discoveredPosts = [
        preview(3, DateTime.utc(2026, 9, 14, 10)),
        preview(4, DateTime.utc(2026, 9, 14, 10, 1)),
      ];
      final refresh = commit(
        subscriptionId: subscription.id,
        expectedCheckpoint: seededCheckpoint,
        startedAt: DateTime.utc(2026, 9, 14, 10),
        baseline: false,
        discoveredPosts: discoveredPosts,
      );

      await repository.markRead(subscription.id);
      await repository.rename(subscription.id, 'Renamed');
      final committed = await repository.commitRefresh(refresh);

      expect(committed?.hasNewPosts, isTrue);
      expect(committed?.name, 'Renamed');
    },
  );

  test('deletes only the requested subscription', () async {
    final first = await repository.create(
      profileId: 4,
      query: 'first',
      name: null,
      id: 'first',
      createdAt: createdAt,
    );
    await repository.create(
      profileId: 4,
      query: 'second',
      name: null,
      id: 'second',
      createdAt: createdAt,
    );

    await repository.delete(first.id);

    expect(await repository.getById(first.id), isNull);
    expect((await repository.getAll()).map((item) => item.id), ['second']);
  });

  test(
    'deletes subscriptions for one profile without affecting another',
    () async {
      await repository.create(
        profileId: 4,
        query: 'first',
        name: null,
        id: 'first',
        createdAt: createdAt,
      );
      await repository.create(
        profileId: 5,
        query: 'second',
        name: null,
        id: 'second',
        createdAt: createdAt,
      );

      await repository.deleteForProfile(4);

      expect(await repository.getById('first'), isNull);
      expect((await repository.getById('second'))?.profileId, 5);
    },
  );

  test('removes only deleted profile pins from shared folders', () async {
    final cat = await repository.create(
      profileId: 12,
      query: 'cat',
      name: null,
      id: 'cat',
      createdAt: createdAt,
    );
    final dog = await repository.create(
      profileId: 99,
      query: 'dog',
      name: null,
      id: 'dog',
      createdAt: createdAt,
    );
    final home = await repository.create(
      profileId: 99,
      query: 'bird',
      name: null,
      id: 'bird',
      createdAt: createdAt,
    );
    await repository.replaceOrganization(
      SearchOrganization(
        folders: [
          SharedSearchFolder(
            id: 'animals',
            name: 'Animals',
            searchIds: [cat.id, dog.id],
          ),
        ],
        homeSearchIds: [home.id],
      ),
    );

    await repository.deleteForProfile(12);

    expect(
      await repository.getOrganization(),
      SearchOrganization(
        folders: [
          SharedSearchFolder(
            id: 'animals',
            name: 'Animals',
            searchIds: [dog.id],
          ),
        ],
        homeSearchIds: [home.id],
      ),
    );
  });

  test(
    'deleting a shared folder unpins its members and keeps Home pins',
    () async {
      final cat = await repository.create(
        profileId: 12,
        query: 'cat',
        name: null,
        id: 'cat',
        createdAt: createdAt,
      );
      final dog = await repository.create(
        profileId: 99,
        query: 'dog',
        name: null,
        id: 'dog',
        createdAt: createdAt,
      );
      final home = await repository.create(
        profileId: 99,
        query: 'bird',
        name: null,
        id: 'bird',
        createdAt: createdAt,
      );
      await repository.replaceOrganization(
        SearchOrganization(
          folders: [
            SharedSearchFolder(
              id: 'animals',
              name: 'Animals',
              searchIds: [cat.id, dog.id],
            ),
          ],
          homeSearchIds: [home.id],
        ),
      );

      await repository.deleteSharedFolderAndPins('animals');

      expect((await repository.getAll()).map((search) => search.id), [home.id]);
      expect(
        await repository.getOrganization(),
        SearchOrganization(folders: const [], homeSearchIds: [home.id]),
      );
    },
  );

  test(
    'restores shared-folder members after organization storage fails',
    () async {
      final subscriptions = MemorySubscriptionBox();
      final organization = FailingOrganizationBox();
      final failingRepository = HiveSearchSubscriptionRepository(
        box: subscriptions,
        organizationBox: organization,
      );
      final cat = await failingRepository.create(
        profileId: 12,
        query: 'cat',
        name: null,
        id: 'cat',
        createdAt: createdAt,
      );
      final dog = await failingRepository.create(
        profileId: 99,
        query: 'dog',
        name: null,
        id: 'dog',
        createdAt: createdAt,
      );
      final original = SearchOrganization(
        folders: [
          SharedSearchFolder(
            id: 'animals',
            name: 'Animals',
            searchIds: [cat.id, dog.id],
          ),
        ],
        homeSearchIds: const [],
      );
      await failingRepository.replaceOrganization(original);
      organization.failWrites = true;

      await expectLater(
        failingRepository.deleteSharedFolderAndPins('animals'),
        throwsStateError,
      );

      expect(
        (await failingRepository.getAll()).map((search) => search.id),
        [cat.id, dog.id],
      );
      expect(await failingRepository.getOrganization(), original);
    },
  );

  test('restores exact captured aggregates for one profile', () async {
    final source = await repository.create(
      profileId: 4,
      query: 'first',
      name: ' First ',
      id: 'first',
      createdAt: createdAt,
    );
    final checkpoint = DateTime.utc(2026, 9, 14, 9);
    final captured = await repository.commitRefresh(
      commit(
        subscriptionId: source.id,
        expectedCheckpoint: null,
        startedAt: checkpoint,
        baseline: false,
        discoveredPosts: [preview(1, checkpoint)],
      ),
    );
    await repository.deleteForProfile(4);

    await repository.restoreForProfile(4, [captured!]);

    expect(await repository.getById(source.id), captured);
  });

  test(
    'loads legacy unread counts as NEW while preserving persisted fields',
    () async {
      final object = SearchSubscriptionHiveObject(
        id: 'round-trip',
        profileId: 4,
        query: 'cat rating:safe',
        name: 'Cats',
        position: 2,
        createdAt: createdAt,
        lastAttemptAt: DateTime.utc(2026, 9, 14, 9),
        lastSuccessfulCheckAt: DateTime.utc(2026, 9, 14, 8, 30),
        unreadCount: 7,
        lastErrorKind: 'future_error',
        previews: [
          SearchPostPreviewHiveObject(
            postId: 11,
            postCreatedAt: DateTime.utc(2026, 9, 14, 8),
            thumbnailUrl: 'https://example.com/11.jpg',
            sampleUrl: 'https://example.com/11-sample.jpg',
            discoveredAt: DateTime.utc(2026, 9, 14, 9),
          ),
        ],
        recentPostIdentities: [
          RecentSearchPostHiveObject(
            postId: 11,
            postCreatedAt: DateTime.utc(2026, 9, 14, 8),
          ),
        ],
      );
      await box.put(object.id, object);
      await box.close();
      box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
      repository = HiveSearchSubscriptionRepository(box: box);

      final restored = await repository.getById(object.id);

      expect(restored?.id, object.id);
      expect(restored?.profileId, object.profileId);
      expect(restored?.name, object.name);
      expect(restored?.previews.single.postId, 11);
      expect(restored?.recentPostIdentities.single.postId, 11);
      expect(restored?.hasNewPosts, isTrue);
      expect(restored?.unreadCount, 1);
      expect(restored?.lastErrorKind, SearchRefreshErrorKind.other);
    },
  );
}
