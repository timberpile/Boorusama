import 'profile_uuid_utils.dart';

// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/configs/config/providers.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_converter.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:boorusama/core/settings/src/data/providers.dart';
import 'package:boorusama/core/settings/src/providers/settings_notifier.dart';
import 'package:boorusama/core/settings/src/providers/settings_provider.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/core/search/following_topics/providers.dart'
    show followingTopicsProvider;
import 'package:boorusama/core/search/following_topics/src/data/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/tracking/providers.dart';
import 'package:boorusama/core/tracking/types.dart';
import 'package:boorusama/foundation/loggers.dart';

import 'riverpod_test_utils.dart';
import 'core/search/following_topics/topic_test_utils.dart';

class InMemoryBooruConfigRepository implements BooruConfigRepository {
  InMemoryBooruConfigRepository({this.removeFailure});

  final List<BooruConfig> _configs = [];
  final Object? removeFailure;
  var failNextUpdate = false;
  var returnNullAfterUpdate = false;

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) {
    final id = profileUuid(_configs.length + 1);
    final config = booruConfigData.toBooruConfig(id: id);

    if (config == null) return Future.value();

    _configs.add(config);
    return Future.value(config);
  }

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) {
    _configs.addAll(booruConfigs);
    return Future.value(booruConfigs);
  }

  @override
  Future<void> clear() {
    _configs.clear();
    return Future.value();
  }

  @override
  Future<List<BooruConfig>> getAll() {
    return Future.value(_configs.toList());
  }

  @override
  Future<void> remove(BooruConfig booruConfig) {
    if (removeFailure case final error?) {
      return Future.error(error);
    }
    _configs.removeWhere((e) => e.id == booruConfig.id);
    return Future.value();
  }

  @override
  Future<BooruConfig?> update(String id, BooruConfigData booruConfigData) {
    if (failNextUpdate) {
      failNextUpdate = false;
      return Future.value();
    }
    final index = _configs.indexWhere((e) => e.id == id);
    if (index == -1) return Future.value();

    final config = booruConfigData.toBooruConfig(id: id);
    if (config == null) return Future.value();

    _configs[index] = config;
    return Future.value(returnNullAfterUpdate ? null : config);
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository() : _settings = Settings.defaultSettings;

  late Settings _settings;
  Error? saveFailure;

  @override
  Future<bool> save(Settings settings) {
    if (saveFailure case final error?) {
      return Future.error(error);
    }
    _settings = settings;
    return Future.value(true);
  }

  @override
  SettingsOrError load() => TaskEither.right(_settings);
}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLogger extends Mock implements Logger {}

class MockCallback extends Mock {
  // ignore: unreachable_from_main
  void call();
}

class RecordingFollowingTopicRepository implements FollowingTopicRepository {
  RecordingFollowingTopicRepository(
    List<FollowingTopic> topics, {
    TopicOrganization? organization,
    List<TopicFeed> feeds = const [],
  }) : _topics = topics.toList(),
       _feeds = feeds.toList(),
       organization =
           organization ??
           TopicOrganization(folders: const [], homeSearchIds: const []);

  final List<FollowingTopic> _topics;
  final List<TopicFeed> _feeds;
  final deletedProfileIds = <String>[];
  final restoredProfileIds = <String>[];
  List<FollowingTopic>? restoredSubscriptions;
  Error? deleteFailure;
  Error? invalidateFailure;
  Completer<void>? invalidationStarted;
  Completer<void>? releaseInvalidation;
  Completer<void>? lookupStarted;
  TopicOrganization organization;
  TopicOrganization? restoredOrganization;

  List<FollowingTopic> get remaining => _topics.toList();
  List<TopicFeed> get remainingFeeds => _feeds.toList();

  @override
  Future<List<FollowingTopic>> getAll() async => _topics.toList();

  @override
  Future<FollowingTopic?> getById(String id) async {
    lookupStarted?.complete();
    return _topics.where((item) => item.id == id).firstOrNull;
  }

  @override
  Future<List<TopicFeed>> getFeeds() async => _feeds.toList();
  @override
  Future<void> restoreFeeds(
    String profileId,
    List<TopicFeed> feeds,
  ) async {
    _feeds.removeWhere((feed) => feed.profileId == profileId);
    _feeds.addAll(feeds);
  }

  @override
  Future<TopicOrganization> getOrganization() async => organization;

  @override
  Future<void> replaceOrganization(TopicOrganization value) async {
    organization = value;
    restoredOrganization = value;
  }

  @override
  Future<void> deleteSharedFolderAndTopics(String folderId) async {
    final folder = organization.folders
        .where((folder) => folder.id == folderId)
        .firstOrNull;
    if (folder == null) return;
    _topics.removeWhere(
      (search) => folder.searchIds.contains(search.id),
    );
    organization = TopicOrganization(
      folders: organization.folders.where((folder) => folder.id != folderId),
      homeSearchIds: organization.homeSearchIds,
    );
  }

  @override
  Future<void> deleteForProfile(String profileId) async {
    deletedProfileIds.add(profileId);
    if (deleteFailure case final error?) {
      throw error;
    }
    final removedIds = _topics
        .where((subscription) => subscription.profileId == profileId)
        .map((subscription) => subscription.id)
        .toSet();
    _topics.removeWhere(
      (subscription) => subscription.profileId == profileId,
    );
    organization = TopicOrganization(
      folders: [
        for (final folder in organization.folders)
          TopicFolder(
            id: folder.id,
            name: folder.name,
            searchIds: folder.searchIds.where((id) => !removedIds.contains(id)),
          ),
      ],
      homeSearchIds: organization.homeSearchIds.where(
        (id) => !removedIds.contains(id),
      ),
    );
  }

  @override
  Future<void> invalidateRuntimeForProfile(String profileId) async {
    if (invalidateFailure case final error?) throw error;
    invalidationStarted?.complete();
    await releaseInvalidation?.future;
    for (var index = 0; index < _topics.length; index++) {
      final source = _topics[index];
      if (source.profileId != profileId) continue;
      _topics[index] = FollowingTopic(
        id: source.id,
        profileId: source.profileId,
        query: source.query,
        name: source.name,
        position: source.position,
        createdAt: source.createdAt,
        runtimeRevision: source.runtimeRevision + 1,
        previews: const [],
        recentPostIdentities: const [],
        unreadCount: 0,
      );
    }
    for (var index = 0; index < _feeds.length; index++) {
      if (_feeds[index].profileId == profileId) {
        _feeds[index] = _feeds[index].copyWith(posts: const []);
      }
    }
  }

  @override
  Future<void> restoreForProfile(
    String profileId,
    List<FollowingTopic> topics,
  ) async {
    restoredProfileIds.add(profileId);
    restoredSubscriptions = topics.toList();
    _topics.removeWhere(
      (subscription) => subscription.profileId == profileId,
    );
    _topics.addAll(topics);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FollowingTopicRepositoryNotifier
    extends FollowingTopicRepositoryNotifier {
  _FollowingTopicRepositoryNotifier(this.repository);

  final FollowingTopicRepository repository;

  @override
  Future<FollowingTopicRepository> build() async => repository;
}

ProviderContainer createBooruConfigContainer({
  required SettingsRepository settingsRepository,
  BooruConfigRepository? booruConfigRepository,
  FollowingTopicRepository? followingTopicRepository,
}) {
  final mockLogger = MockLogger();

  return createContainer(
    overrides: [
      booruConfigRepoProvider.overrideWith(
        (ref) => booruConfigRepository ?? InMemoryBooruConfigRepository(),
      ),
      followingTopicRepositoryProvider.overrideWith(
        () => _FollowingTopicRepositoryNotifier(
          followingTopicRepository ??
              RecordingFollowingTopicRepository(const []),
        ),
      ),
      settingsRepoProvider.overrideWithValue(settingsRepository),
      settingsNotifierProvider.overrideWith(
        () => SettingsNotifier(Settings.defaultSettings),
      ),
      initialSettingsBooruConfigProvider.overrideWithValue(BooruConfig.empty),
      loggerProvider.overrideWithValue(mockLogger),
      trackerProvider.overrideWith((_) => DummyTracker()),
      booruConfigProvider.overrideWith(
        () => BooruConfigNotifier(
          initialConfigs: [],
        ),
      ),
      booruLoginDetailsProvider.overrideWith(
        (_, _) => const DefaultBooruLoginDetails(
          login: '',
          apiKey: '',
          url: '',
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Settings.defaultSettings);
  });

  FollowingTopic subscriptionFor(
    String id,
    int profileSeed, {
    int position = 0,
  }) {
    return FollowingTopic.create(
      id: id,
      profileId: profileUuid(profileSeed),
      query: 'query-$id',
      name: 'Saved $id',
      position: position,
      createdAt: DateTime.utc(2026, 9, 14),
    );
  }

  group(
    'Add a new config',
    () {
      final mockSettingsRepository = MockSettingsRepository();
      late ProviderContainer container;
      final configData = BooruConfig.empty.toBooruConfigData();
      final configData2 = BooruConfig.empty.toBooruConfigData();

      BooruConfigNotifier getNotifier() =>
          container.read(booruConfigProvider.notifier);

      setUp(
        () async {
          reset(mockSettingsRepository);

          when(
            () => mockSettingsRepository.save(any()),
          ).thenAnswer((_) async => true);

          container = createBooruConfigContainer(
            settingsRepository: mockSettingsRepository,
          );

          await getNotifier().fetch();
        },
      );

      test(
        'should add a new config',
        () async {
          await getNotifier().add(
            data: configData,
          );

          final newData = container.read(booruConfigProvider);

          expect(
            listEquals(
              [
                configData.toBooruConfig(
                  id: '00000000-0000-4000-8000-000000000001',
                ),
              ],
              newData,
            ),
            isTrue,
          );
        },
      );

      test(
        'should call the success callback',
        () async {
          final successCallback = MockCallback();

          await getNotifier().add(
            data: configData,
            onSuccess: (booruConfig) => successCallback(),
          );

          verify(() => successCallback()).called(1);
        },
      );

      test(
        'should update order',
        () async {
          await getNotifier().add(
            data: configData,
          );

          final settings = container.read(settingsProvider);

          expect(
            settings.booruConfigIdOrders,
            profileUuid(1),
          );
        },
      );

      // should update current booru config if set as current
      test(
        'should update current booru config if set as current',
        () async {
          await getNotifier().add(
            data: configData,
          );

          await getNotifier().add(
            data: configData2,
            setAsCurrent: true,
          );

          expect(
            container.read(currentBooruConfigProvider).id,
            profileUuid(2),
          );
        },
      );

      test(
        'should update current config if there is no current config',
        () async {
          await getNotifier().add(
            data: configData,
          );

          final currentConfig = container.read(currentBooruConfigProvider);

          expect(
            currentConfig.id,
            profileUuid(1),
          );
        },
      );
    },
  );

  group(
    'Update a config',
    () {
      final checkedAt = DateTime.utc(2026, 9, 20, 8);
      final original = BooruConfig.empty.toBooruConfigData().copyWith(
        url: 'https://site-a.example',
      );

      RecordingFollowingTopicRepository repository() {
        final source = FollowingTopic(
          id: 'source',
          profileId: '00000000-0000-4000-8000-000000000001',
          query: 'artist',
          position: 0,
          createdAt: checkedAt,
          previews: const [],
          recentPostIdentities: const [],
          unreadCount: 1,
          lastAttemptAt: checkedAt,
          lastSuccessfulCheckAt: checkedAt,
          lastErrorKind: SearchRefreshErrorKind.network,
        );
        final unrelated = FollowingTopic.create(
          id: 'unrelated',
          profileId: '00000000-0000-4000-8000-000000000002',
          query: 'cat',
          name: null,
          position: 0,
          createdAt: checkedAt,
        );
        return RecordingFollowingTopicRepository(
          [source, unrelated],
          feeds: [
            TopicFeed(
              id: 'feed',
              profileId: '00000000-0000-4000-8000-000000000001',
              name: 'Artists',
              sourceIds: const ['source'],
              posts: [
                feedPostSnapshotFromPost(testSearchPost(5, checkedAt)),
              ],
            ),
          ],
        );
      }

      test(
        'changing a profile site clears its feed and search runtime',
        () async {
          final searches = repository();
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            followingTopicRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);

          await notifier.update(
            booruConfigData: original.copyWith(url: 'https://site-b.example'),
            oldConfigId: '00000000-0000-4000-8000-000000000001',
          );

          final source = searches.remaining.singleWhere(
            (item) => item.id == 'source',
          );
          expect(source.query, 'artist');
          expect(source.createdAt, checkedAt);
          expect(source.runtimeRevision, 1);
          expect(source.lastAttemptAt, isNull);
          expect(source.lastSuccessfulCheckAt, isNull);
          expect(source.lastErrorKind, isNull);
          expect(source.hasNewPosts, isFalse);
          expect(
            searches.remaining
                .singleWhere((item) => item.id == 'unrelated')
                .createdAt,
            checkedAt,
          );
          expect(searches.remainingFeeds.single.sourceIds, ['source']);
          expect(searches.remainingFeeds.single.posts, isEmpty);
        },
      );

      test(
        'editing the name on an equivalent site preserves feed cache',
        () async {
          final searches = repository();
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            followingTopicRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);

          await notifier.update(
            booruConfigData: original.copyWith(
              url: 'https://site-a.example/',
              name: 'Renamed',
            ),
            oldConfigId: '00000000-0000-4000-8000-000000000001',
          );

          expect(
            searches.remaining
                .singleWhere((item) => item.id == 'source')
                .lastSuccessfulCheckAt,
            checkedAt,
          );
          expect(searches.remainingFeeds.single.posts, hasLength(1));
        },
      );

      test(
        'a failed reset keeps the old profile site and feed cache',
        () async {
          final searches = repository()
            ..invalidateFailure = StateError('write failed');
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            followingTopicRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);
          final errors = <String>[];

          await notifier.update(
            booruConfigData: original.copyWith(url: 'https://site-b.example'),
            oldConfigId: '00000000-0000-4000-8000-000000000001',
            onFailure: errors.add,
          );

          expect(errors, isNotEmpty);
          expect(container.read(booruConfigProvider).single.url, original.url);
          expect(searches.remainingFeeds.single.posts, hasLength(1));
        },
      );

      test('a failed profile save restores the old site cache', () async {
        final searches = repository();
        final configs = InMemoryBooruConfigRepository();
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          booruConfigRepository: configs,
          followingTopicRepository: searches,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: original);
        configs.failNextUpdate = true;
        final errors = <String>[];

        await notifier.update(
          booruConfigData: original.copyWith(url: 'https://site-b.example'),
          oldConfigId: '00000000-0000-4000-8000-000000000001',
          onFailure: errors.add,
        );

        expect(errors, isNotEmpty);
        expect((await configs.getAll()).single.url, original.url);
        expect(container.read(booruConfigProvider).single.url, original.url);
        expect(searches.remainingFeeds.single.posts, hasLength(1));
        expect(
          searches.remaining
              .singleWhere((item) => item.id == 'source')
              .lastSuccessfulCheckAt,
          checkedAt,
        );
      });

      test(
        'an ambiguous save keeps a newly persisted site cache empty',
        () async {
          final searches = repository();
          final configs = InMemoryBooruConfigRepository();
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            booruConfigRepository: configs,
            followingTopicRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);
          configs.returnNullAfterUpdate = true;

          await notifier.update(
            booruConfigData: original.copyWith(url: 'https://site-b.example'),
            oldConfigId: '00000000-0000-4000-8000-000000000001',
          );

          expect((await configs.getAll()).single.url, 'https://site-b.example');
          expect(
            container.read(booruConfigProvider).single.url,
            'https://site-b.example',
          );
          expect(searches.remainingFeeds.single.posts, isEmpty);
        },
      );

      test('a site edit pauses new refreshes before replacing cache', () async {
        final searches = repository()
          ..invalidationStarted = Completer<void>()
          ..releaseInvalidation = Completer<void>()
          ..lookupStarted = Completer<void>();
        final configs = InMemoryBooruConfigRepository();
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          booruConfigRepository: configs,
          followingTopicRepository: searches,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: original);
        final updating = notifier.update(
          booruConfigData: original.copyWith(url: 'https://site-b.example'),
          oldConfigId: '00000000-0000-4000-8000-000000000001',
        );
        await searches.invalidationStarted!.future;
        Future<SearchRefreshOutcome>? refreshing;
        try {
          expect((await configs.getAll()).single.url, original.url);
          refreshing = container
              .read(followingTopicsProvider.notifier)
              .refresh('source');
          await searches.lookupStarted!.future;
        } finally {
          searches.releaseInvalidation!.complete();
          await updating;
        }
        expect(await refreshing, const SearchRefreshDiscarded());
        expect(
          container.read(booruConfigProvider).single.url,
          'https://site-b.example',
        );
      });
    },
  );

  group(
    'Delete a config',
    () {
      group(
        'when there is only a single config',
        () {
          final config1 = BooruConfig.empty.toBooruConfigData();

          late ProviderContainer container;

          BooruConfigNotifier notifier() =>
              container.read(booruConfigProvider.notifier);

          setUp(
            () async {
              container = createBooruConfigContainer(
                settingsRepository: InMemorySettingsRepository(),
              );

              await notifier().add(data: config1);
            },
          );

          test(
            'should clear all configs',
            () async {
              await notifier().delete(
                config1.toBooruConfig(
                  id: '00000000-0000-4000-8000-000000000001',
                )!,
              );

              final newConfigs = container.read(booruConfigProvider);

              expect(
                newConfigs,
                isEmpty,
              );
            },
          );

          test(
            'should clear the order',
            () async {
              await notifier().delete(
                config1.toBooruConfig(
                  id: '00000000-0000-4000-8000-000000000001',
                )!,
              );

              final settings = container.read(settingsProvider);

              expect(
                settings.booruConfigIdOrders,
                '',
              );
            },
          );

          test(
            'should clear the current config',
            () async {
              await notifier().delete(
                config1.toBooruConfig(
                  id: '00000000-0000-4000-8000-000000000001',
                )!,
              );

              final currentConfig = container.read(currentBooruConfigProvider);

              expect(
                currentConfig.id,
                BooruConfig.empty.id,
              );
            },
          );
        },
      );

      group(
        'from a list of 2 or more configs',
        () {
          final config1 = BooruConfig.empty.toBooruConfigData();
          final config2 = BooruConfig.empty.toBooruConfigData();
          final config3 = BooruConfig.empty.toBooruConfigData();

          late ProviderContainer container;

          BooruConfigNotifier notifier() =>
              container.read(booruConfigProvider.notifier);

          group(
            'when it is not the currently selected config',
            () {
              setUpAll(
                () async {
                  container = createBooruConfigContainer(
                    settingsRepository: InMemorySettingsRepository(),
                  );
                  await notifier().add(data: config1);
                  await notifier().add(
                    data: config2,
                    setAsCurrent: true,
                  );
                  await notifier().add(data: config3);

                  await notifier().delete(
                    config1.toBooruConfig(
                      id: '00000000-0000-4000-8000-000000000001',
                    )!,
                  );
                },
              );

              test(
                'should works',
                () {
                  final newConfigs = container.read(booruConfigProvider);

                  expect(
                    listEquals(
                      [
                        config2.toBooruConfig(
                          id: '00000000-0000-4000-8000-000000000002',
                        ),
                        config3.toBooruConfig(
                          id: '00000000-0000-4000-8000-000000000003',
                        ),
                      ],
                      newConfigs,
                    ),
                    isTrue,
                  );
                },
              );

              test(
                'should update order',
                () {
                  final settings = container.read(settingsProvider);

                  expect(
                    settings.booruConfigIdOrders,
                    '${profileUuid(2)} ${profileUuid(3)}',
                  );
                },
              );
            },
          );

          group(
            'when it is the currently selected config',
            () {
              setUpAll(
                () async {
                  container = createBooruConfigContainer(
                    settingsRepository: InMemorySettingsRepository(),
                  );
                  await notifier().add(data: config1);
                  await notifier().add(
                    data: config2,
                    setAsCurrent: true,
                  );
                  await notifier().add(data: config3);

                  await notifier().delete(
                    config2.toBooruConfig(
                      id: '00000000-0000-4000-8000-000000000002',
                    )!,
                  );
                },
              );

              test(
                'should works',
                () {
                  final newConfigs = container.read(booruConfigProvider);

                  expect(
                    listEquals(
                      [
                        config1.toBooruConfig(
                          id: '00000000-0000-4000-8000-000000000001',
                        ),
                        config3.toBooruConfig(
                          id: '00000000-0000-4000-8000-000000000003',
                        ),
                      ],
                      newConfigs,
                    ),
                    isTrue,
                  );
                },
              );

              test(
                'should update order',
                () {
                  final settings = container.read(settingsProvider);

                  expect(
                    settings.booruConfigIdOrders,
                    '${profileUuid(1)} ${profileUuid(3)}',
                  );
                },
              );

              test(
                'should update current config to the first config',
                () {
                  final currentConfig = container.read(
                    currentBooruConfigProvider,
                  );

                  expect(
                    currentConfig.id,
                    profileUuid(1),
                  );
                },
              );
            },
          );
        },
      );

      test('removes followed topics with the final profile', () async {
        final config = BooruConfig.empty.toBooruConfigData();
        final searchRepository = RecordingFollowingTopicRepository([
          subscriptionFor('final', 1),
          subscriptionFor('other', 2),
        ]);
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          followingTopicRepository: searchRepository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: config);

        await notifier.delete(
          config.toBooruConfig(id: '00000000-0000-4000-8000-000000000001')!,
        );

        expect(searchRepository.deletedProfileIds, [profileUuid(1)]);
        expect(
          searchRepository.remaining.every(
            (subscription) => subscription.profileId != profileUuid(1),
          ),
          isTrue,
        );
      });

      test('removes followed topics with the current profile', () async {
        final config1 = BooruConfig.empty.toBooruConfigData();
        final config2 = BooruConfig.empty.toBooruConfigData();
        final config3 = BooruConfig.empty.toBooruConfigData();
        final searchRepository = RecordingFollowingTopicRepository([
          subscriptionFor('current', 2),
          subscriptionFor('other', 3),
        ]);
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          followingTopicRepository: searchRepository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: config1);
        await notifier.add(data: config2, setAsCurrent: true);
        await notifier.add(data: config3);

        await notifier.delete(
          config2.toBooruConfig(id: '00000000-0000-4000-8000-000000000002')!,
        );

        expect(searchRepository.deletedProfileIds, [profileUuid(2)]);
        expect(
          searchRepository.remaining.every(
            (subscription) => subscription.profileId != profileUuid(2),
          ),
          isTrue,
        );
      });

      test('removes followed topics with another profile', () async {
        final config1 = BooruConfig.empty.toBooruConfigData();
        final config2 = BooruConfig.empty.toBooruConfigData();
        final config3 = BooruConfig.empty.toBooruConfigData();
        final searchRepository = RecordingFollowingTopicRepository([
          subscriptionFor('other', 1),
          subscriptionFor('current', 2),
        ]);
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          followingTopicRepository: searchRepository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: config1);
        await notifier.add(data: config2, setAsCurrent: true);
        await notifier.add(data: config3);

        await notifier.delete(
          config1.toBooruConfig(id: '00000000-0000-4000-8000-000000000001')!,
        );

        expect(searchRepository.deletedProfileIds, [profileUuid(1)]);
        expect(
          searchRepository.remaining.every(
            (subscription) => subscription.profileId != profileUuid(1),
          ),
          isTrue,
        );
      });

      test(
        'publishes remaining followed topics after profile deletion',
        () async {
          final config1 = BooruConfig.empty.toBooruConfigData();
          final config2 = BooruConfig.empty.toBooruConfigData();
          final searchRepository = RecordingFollowingTopicRepository([
            subscriptionFor('deleted', 1),
            subscriptionFor('remaining', 2),
          ]);
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            followingTopicRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config1);
          await notifier.add(data: config2);
          await container.read(followingTopicsProvider.future);

          await notifier.delete(
            config1.toBooruConfig(id: '00000000-0000-4000-8000-000000000001')!,
          );

          expect(
            container
                .read(followingTopicsProvider)
                .requireValue
                .topics
                .map((subscription) => subscription.id),
            ['remaining'],
          );
        },
      );

      test(
        'keeps the profile when following-topic cleanup fails',
        () async {
          final config = BooruConfig.empty.toBooruConfigData();
          final followingTopic = subscriptionFor('failed-cleanup', 1);
          final searchRepository = RecordingFollowingTopicRepository([
            followingTopic,
          ])..deleteFailure = StateError('search deletion failed');
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            followingTopicRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config);
          final failures = <String>[];

          await notifier.delete(
            config.toBooruConfig(id: '00000000-0000-4000-8000-000000000001')!,
            onFailure: failures.add,
          );

          expect(
            container.read(booruConfigProvider).map((config) => config.id),
            [profileUuid(1)],
          );
          expect(searchRepository.remaining, [followingTopic]);
          expect(failures, ['Bad state: search deletion failed']);
        },
      );

      test(
        'restores exact followed topics when profile deletion fails',
        () async {
          final config = BooruConfig.empty.toBooruConfigData();
          final followingTopics = [
            subscriptionFor('first', 1),
            subscriptionFor('second', 1, position: 1),
          ];
          final unaffectedSearch = subscriptionFor('other', 2);
          final organization = TopicOrganization(
            folders: [
              TopicFolder(
                id: 'mixed',
                name: 'Mixed',
                searchIds: [followingTopics.first.id, unaffectedSearch.id],
              ),
            ],
            homeSearchIds: [followingTopics.last.id],
          );
          final searchRepository = RecordingFollowingTopicRepository([
            ...followingTopics,
            unaffectedSearch,
          ], organization: organization);
          final configRepository = InMemoryBooruConfigRepository(
            removeFailure: StateError('profile deletion failed'),
          );
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            booruConfigRepository: configRepository,
            followingTopicRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config);
          await container.read(followingTopicsProvider.future);
          var publishedStates = 0;
          final subscription = container.listen(
            followingTopicsProvider,
            (_, next) {
              if (next.hasValue) publishedStates++;
            },
          );
          addTearDown(subscription.close);
          final failures = <String>[];

          await notifier.delete(
            config.toBooruConfig(id: '00000000-0000-4000-8000-000000000001')!,
            onFailure: failures.add,
          );

          expect(
            container.read(booruConfigProvider).map((config) => config.id),
            [profileUuid(1)],
          );
          expect(searchRepository.deletedProfileIds, [profileUuid(1)]);
          expect(searchRepository.restoredProfileIds, [profileUuid(1)]);
          expect(searchRepository.restoredSubscriptions, followingTopics);
          expect(searchRepository.restoredOrganization, organization);
          expect(
            searchRepository.remaining,
            unorderedEquals([...followingTopics, unaffectedSearch]),
          );
          expect(
            container.read(followingTopicsProvider).requireValue.topics,
            unorderedEquals([...followingTopics, unaffectedSearch]),
          );
          expect(publishedStates, 1);
          expect(failures, ['Bad state: profile deletion failed']);
        },
      );

      test(
        'restores followed topics when current-profile replacement persistence fails',
        () async {
          final config1 = BooruConfig.empty.toBooruConfigData();
          final config2 = BooruConfig.empty.toBooruConfigData();
          final config3 = BooruConfig.empty.toBooruConfigData();
          final followingTopics = [
            subscriptionFor('first', 2),
            subscriptionFor('second', 2, position: 1),
          ];
          final unaffectedSearch = subscriptionFor('other', 3);
          final searchRepository = RecordingFollowingTopicRepository([
            ...followingTopics,
            unaffectedSearch,
          ]);
          final configRepository = InMemoryBooruConfigRepository();
          final settingsRepository = InMemorySettingsRepository();
          final container = createBooruConfigContainer(
            settingsRepository: settingsRepository,
            booruConfigRepository: configRepository,
            followingTopicRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config1);
          await notifier.add(data: config2, setAsCurrent: true);
          await notifier.add(data: config3);
          settingsRepository.saveFailure = StateError('settings save failed');
          final failures = <String>[];

          await notifier.delete(
            config2.toBooruConfig(id: '00000000-0000-4000-8000-000000000002')!,
            onFailure: failures.add,
          );

          expect(
            (await configRepository.getAll()).map((config) => config.id),
            [profileUuid(1), profileUuid(2), profileUuid(3)],
          );
          expect(searchRepository.restoredProfileIds, [profileUuid(2)]);
          expect(searchRepository.restoredSubscriptions, followingTopics);
          expect(
            searchRepository.remaining,
            unorderedEquals([...followingTopics, unaffectedSearch]),
          );
          expect(failures, ['Bad state: settings save failed']);
          expect(failures, hasLength(1));
        },
      );
    },
  );
}
