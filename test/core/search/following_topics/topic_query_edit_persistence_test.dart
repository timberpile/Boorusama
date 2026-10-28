import 'package:boorusama/core/search/following_topics/src/data/hive/following_topic_repository_hive.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_test_utils.dart';

void main() {
  const profileId = '00000000-0000-4000-8000-00000000000c';

  test(
    'edit atomically updates settings and rejects stale or deleted topics',
    () async {
      final repository = memorySubscriptionRepository();
      final topic = await repository.create(
        profileId: profileId,
        query: 'cat',
        name: 'Cats',
      );
      final saved = await repository.edit(
        topic.id,
        profileId: profileId,
        query: 'dog',
        name: 'Dogs',
        autoUpdateEnabled: false,
        expectedTopic: topic,
      );
      expect(saved.id, topic.id);
      expect(saved.createdAt, topic.createdAt);
      expect(saved.autoUpdateEnabled, isFalse);
      await expectLater(
        repository.edit(
          topic.id,
          profileId: profileId,
          query: 'bird',
          name: 'Cats',
          expectedTopic: topic,
        ),
        throwsA(isA<StaleFollowingTopicEditException>()),
      );
      expect(await repository.getById(topic.id), saved);
      await repository.delete(topic.id);
      await expectLater(
        repository.edit(
          topic.id,
          profileId: profileId,
          query: 'bird',
          name: 'Cats',
          expectedTopic: saved,
        ),
        throwsA(isA<StaleFollowingTopicEditException>()),
      );
      expect(await repository.getAll(), isEmpty);
    },
  );

  test(
    'sidecar failure rolls back query and settings and permits retry',
    () async {
      final settings = _FailOnceBox();
      final repository = HiveFollowingTopicRepository(
        box: MemorySubscriptionBox(),
        organizationBox: settings,
      );
      final topic = await repository.create(
        profileId: profileId,
        query: 'cat',
        name: 'Cats',
      );
      settings.failNext = true;
      await expectLater(
        repository.edit(
          topic.id,
          profileId: profileId,
          query: 'dog',
          name: 'Dogs',
          autoUpdateEnabled: false,
          expectedTopic: topic,
        ),
        throwsStateError,
      );
      expect(await repository.getById(topic.id), topic);
      final saved = await repository.edit(
        topic.id,
        profileId: profileId,
        query: 'dog',
        name: 'Dogs',
        autoUpdateEnabled: false,
        expectedTopic: topic,
      );
      expect(saved.query, 'dog');
      expect(saved.autoUpdateEnabled, isFalse);
    },
  );

  test('editing typed terms persists their new structure', () async {
    final repository = memorySubscriptionRepository();
    final topic = await repository.create(
      profileId: profileId,
      query: 'cat',
      queryStructure: SearchQueryStructure.typedTags(['cat']),
      name: null,
    );
    final structure = SearchQueryStructure.typedTags(['dog', '-cat']);
    final edited = await repository.edit(
      topic.id,
      profileId: profileId,
      query: 'dog -cat',
      queryStructure: () => structure,
      name: null,
    );
    expect(edited.queryStructure, structure);
    expect((await repository.getById(topic.id))!.queryStructure, structure);
    expect(edited.runtimeRevision, topic.runtimeRevision + 1);
  });

  test(
    'changing only representation preserves tracking and can clear typing',
    () async {
      final repository = memorySubscriptionRepository();
      final topic = await repository.create(
        profileId: profileId,
        query: 'cat',
        name: null,
      );
      final checkedAt = DateTime.utc(2026, 10, 1);
      await repository.commitRefresh(
        SearchRefreshCommit(
          topicId: topic.id,
          expectedCreatedAt: topic.createdAt,
          expectedCheckpoint: null,
          startedAt: checkedAt,
          identityRetentionBoundary: checkedAt,
          baseline: true,
          discoveredPosts: const [],
        ),
      );
      final typed = await repository.edit(
        topic.id,
        profileId: profileId,
        query: 'cat',
        queryStructure: () => SearchQueryStructure.typedTags(['cat']),
        name: 'Cats',
      );
      expect(typed.queryStructure!.typedTags, ['cat']);
      expect(typed.lastSuccessfulCheckAt, checkedAt);
      expect(typed.runtimeRevision, topic.runtimeRevision);
      final raw = await repository.edit(
        topic.id,
        profileId: profileId,
        query: 'cat',
        queryStructure: () => null,
        name: 'Cats',
      );
      expect(raw.queryStructure, isNull);
      expect((await repository.getById(topic.id))!.queryStructure, isNull);
      expect(raw.lastSuccessfulCheckAt, checkedAt);
      expect(raw.runtimeRevision, topic.runtimeRevision);
    },
  );

  test('legacy edits preserve only compatible structure', () async {
    final repository = memorySubscriptionRepository();
    final structure = SearchQueryStructure.typedTags(['cat']);
    final topic = await repository.create(
      profileId: profileId,
      query: 'cat',
      queryStructure: structure,
      name: null,
    );
    final renamed = await repository.edit(
      topic.id,
      profileId: profileId,
      query: 'cat',
      name: 'Cats',
    );
    expect(renamed.queryStructure, structure);
    final raw = await repository.edit(
      topic.id,
      profileId: profileId,
      query: '( cat ~ dog ) source:"a b"',
      name: null,
    );
    expect(raw.query, '( cat ~ dog ) source:"a b"');
    expect(raw.queryStructure, isNull);
  });

  test('mismatched structure cannot corrupt the canonical query', () async {
    final repository = memorySubscriptionRepository();
    final topic = await repository.create(
      profileId: profileId,
      query: 'cat',
      name: null,
    );
    final edited = await repository.edit(
      topic.id,
      profileId: profileId,
      query: 'dog',
      queryStructure: () => SearchQueryStructure.typedTags(['cat']),
      name: null,
    );
    expect(edited.query, 'dog');
    expect(edited.queryStructure, isNull);
  });
}

class _FailOnceBox extends MemoryBox<dynamic> {
  var failNext = false;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failNext && key == 'search:auto_update_overrides') {
      failNext = false;
      throw StateError('settings write failed');
    }
    await super.put(key, value);
  }
}
