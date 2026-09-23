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
import 'package:boorusama/core/search/subscriptions/providers.dart'
    show searchSubscriptionsProvider;
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';
import 'package:boorusama/core/search/subscriptions/types.dart';
import 'package:boorusama/core/tracking/providers.dart';
import 'package:boorusama/core/tracking/types.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'riverpod_test_utils.dart';
import 'core/search/subscriptions/subscription_test_utils.dart';

class InMemoryBooruConfigRepository implements BooruConfigRepository {
  InMemoryBooruConfigRepository({this.removeFailure});

  final List<BooruConfig> _configs = [];
  final Object? removeFailure;
  var failNextUpdate = false;
  var returnNullAfterUpdate = false;

  @override
  Future<BooruConfig?> add(BooruConfigData booruConfigData) {
    final id = _configs.isEmpty ? 1 : _configs.last.id + 1;
    final config = booruConfigData.toBooruConfig(id: id);

    if (config == null) return Future.value();

    _configs.add(config);
    return Future.value(config);
  }

  @override
  Future<List<BooruConfig>> addAll(List<BooruConfig> booruConfigs) {
    final ids = _configs.map((e) => e.id).toList();
    final newConfigs = booruConfigs
        .map((e) {
          final data = e.toBooruConfigData();
          final id = ids.isEmpty ? 1 : ids.last + 1;
          return data.toBooruConfig(id: id);
        })
        .nonNulls
        .toList();

    _configs.addAll(newConfigs);

    return Future.value(newConfigs);
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
  Future<BooruConfig?> update(int id, BooruConfigData booruConfigData) {
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

class RecordingSearchSubscriptionRepository
    implements SearchSubscriptionRepository {
  RecordingSearchSubscriptionRepository(
    List<SearchSubscription> subscriptions, {
    SearchOrganization? organization,
    List<SearchFollowingFeed> feeds = const [],
  }) : _subscriptions = subscriptions.toList(),
       _feeds = feeds.toList(),
       organization =
           organization ??
           SearchOrganization(folders: const [], homeSearchIds: const []);

  final List<SearchSubscription> _subscriptions;
  final List<SearchFollowingFeed> _feeds;
  final deletedProfileIds = <int>[];
  final restoredProfileIds = <int>[];
  List<SearchSubscription>? restoredSubscriptions;
  Error? deleteFailure;
  Error? invalidateFailure;
  Completer<void>? invalidationStarted;
  Completer<void>? releaseInvalidation;
  Completer<void>? lookupStarted;
  SearchOrganization organization;
  SearchOrganization? restoredOrganization;

  List<SearchSubscription> get remaining => _subscriptions.toList();
  List<SearchFollowingFeed> get remainingFeeds => _feeds.toList();

  @override
  Future<List<SearchSubscription>> getAll() async => _subscriptions.toList();

  @override
  Future<SearchSubscription?> getById(String id) async {
    lookupStarted?.complete();
    return _subscriptions.where((item) => item.id == id).firstOrNull;
  }

  @override
  Future<List<SearchFollowingFeed>> getFeeds() async => _feeds.toList();
  @override
  Future<void> restoreFeeds(
    int profileId,
    List<SearchFollowingFeed> feeds,
  ) async {
    _feeds.removeWhere((feed) => feed.profileId == profileId);
    _feeds.addAll(feeds);
  }

  @override
  Future<SearchOrganization> getOrganization() async => organization;

  @override
  Future<void> replaceOrganization(SearchOrganization value) async {
    organization = value;
    restoredOrganization = value;
  }

  @override
  Future<void> deleteSharedFolderAndPins(String folderId) async {
    final folder = organization.folders
        .where((folder) => folder.id == folderId)
        .firstOrNull;
    if (folder == null) return;
    _subscriptions.removeWhere(
      (search) => folder.searchIds.contains(search.id),
    );
    organization = SearchOrganization(
      folders: organization.folders.where((folder) => folder.id != folderId),
      homeSearchIds: organization.homeSearchIds,
    );
  }

  @override
  Future<void> deleteForProfile(int profileId) async {
    deletedProfileIds.add(profileId);
    if (deleteFailure case final error?) {
      throw error;
    }
    final removedIds = _subscriptions
        .where((subscription) => subscription.profileId == profileId)
        .map((subscription) => subscription.id)
        .toSet();
    _subscriptions.removeWhere(
      (subscription) => subscription.profileId == profileId,
    );
    organization = SearchOrganization(
      folders: [
        for (final folder in organization.folders)
          SharedSearchFolder(
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
  Future<void> invalidateRuntimeForProfile(int profileId) async {
    if (invalidateFailure case final error?) throw error;
    invalidationStarted?.complete();
    await releaseInvalidation?.future;
    for (var index = 0; index < _subscriptions.length; index++) {
      final source = _subscriptions[index];
      if (source.profileId != profileId) continue;
      _subscriptions[index] = SearchSubscription(
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
    int profileId,
    List<SearchSubscription> subscriptions,
  ) async {
    restoredProfileIds.add(profileId);
    restoredSubscriptions = subscriptions.toList();
    _subscriptions.removeWhere(
      (subscription) => subscription.profileId == profileId,
    );
    _subscriptions.addAll(subscriptions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SearchSubscriptionRepositoryNotifier
    extends SearchSubscriptionRepositoryNotifier {
  _SearchSubscriptionRepositoryNotifier(this.repository);

  final SearchSubscriptionRepository repository;

  @override
  Future<SearchSubscriptionRepository> build() async => repository;
}

ProviderContainer createBooruConfigContainer({
  required SettingsRepository settingsRepository,
  BooruConfigRepository? booruConfigRepository,
  SearchSubscriptionRepository? searchSubscriptionRepository,
}) {
  final mockLogger = MockLogger();

  return createContainer(
    overrides: [
      booruConfigRepoProvider.overrideWith(
        (ref) => booruConfigRepository ?? InMemoryBooruConfigRepository(),
      ),
      searchSubscriptionRepositoryProvider.overrideWith(
        () => _SearchSubscriptionRepositoryNotifier(
          searchSubscriptionRepository ??
              RecordingSearchSubscriptionRepository(const []),
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

  SearchSubscription subscriptionFor(
    String id,
    int profileId, {
    int position = 0,
  }) {
    return SearchSubscription.create(
      id: id,
      profileId: profileId,
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
              [configData.toBooruConfig(id: 1)],
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
            '1',
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
            2,
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
            1,
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

      RecordingSearchSubscriptionRepository repository() {
        final source = SearchSubscription(
          id: 'source',
          profileId: 1,
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
        final unrelated = SearchSubscription.create(
          id: 'unrelated',
          profileId: 2,
          query: 'cat',
          name: null,
          position: 0,
          createdAt: checkedAt,
        );
        return RecordingSearchSubscriptionRepository(
          [source, unrelated],
          feeds: [
            SearchFollowingFeed(
              id: 'feed',
              profileId: 1,
              name: 'Artists',
              sourceIds: const ['source'],
              posts: [
                feedPostSnapshotFromPost(TestSearchPost(5, checkedAt)),
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
            searchSubscriptionRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);

          await notifier.update(
            booruConfigData: original.copyWith(url: 'https://site-b.example'),
            oldConfigId: 1,
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
            searchSubscriptionRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);

          await notifier.update(
            booruConfigData: original.copyWith(
              url: 'https://site-a.example/',
              name: 'Renamed',
            ),
            oldConfigId: 1,
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
            searchSubscriptionRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);
          final errors = <String>[];

          await notifier.update(
            booruConfigData: original.copyWith(url: 'https://site-b.example'),
            oldConfigId: 1,
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
          searchSubscriptionRepository: searches,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: original);
        configs.failNextUpdate = true;
        final errors = <String>[];

        await notifier.update(
          booruConfigData: original.copyWith(url: 'https://site-b.example'),
          oldConfigId: 1,
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
            searchSubscriptionRepository: searches,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: original);
          configs.returnNullAfterUpdate = true;

          await notifier.update(
            booruConfigData: original.copyWith(url: 'https://site-b.example'),
            oldConfigId: 1,
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
          searchSubscriptionRepository: searches,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: original);
        final updating = notifier.update(
          booruConfigData: original.copyWith(url: 'https://site-b.example'),
          oldConfigId: 1,
        );
        await searches.invalidationStarted!.future;
        Future<SearchRefreshOutcome>? refreshing;
        try {
          expect((await configs.getAll()).single.url, original.url);
          refreshing = container
              .read(searchSubscriptionsProvider.notifier)
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
              await notifier().delete(config1.toBooruConfig(id: 1)!);

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
              await notifier().delete(config1.toBooruConfig(id: 1)!);

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
              await notifier().delete(config1.toBooruConfig(id: 1)!);

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

                  await notifier().delete(config1.toBooruConfig(id: 1)!);
                },
              );

              test(
                'should works',
                () {
                  final newConfigs = container.read(booruConfigProvider);

                  expect(
                    listEquals(
                      [
                        config2.toBooruConfig(id: 2),
                        config3.toBooruConfig(id: 3),
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
                    '2 3',
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

                  await notifier().delete(config2.toBooruConfig(id: 2)!);
                },
              );

              test(
                'should works',
                () {
                  final newConfigs = container.read(booruConfigProvider);

                  expect(
                    listEquals(
                      [
                        config1.toBooruConfig(id: 1),
                        config3.toBooruConfig(id: 3),
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
                    '1 3',
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
                    1,
                  );
                },
              );
            },
          );
        },
      );

      test('removes pinned searches with the final profile', () async {
        final config = BooruConfig.empty.toBooruConfigData();
        final searchRepository = RecordingSearchSubscriptionRepository([
          subscriptionFor('final', 1),
          subscriptionFor('other', 2),
        ]);
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          searchSubscriptionRepository: searchRepository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: config);

        await notifier.delete(config.toBooruConfig(id: 1)!);

        expect(searchRepository.deletedProfileIds, [1]);
        expect(
          searchRepository.remaining.every(
            (subscription) => subscription.profileId != 1,
          ),
          isTrue,
        );
      });

      test('removes pinned searches with the current profile', () async {
        final config1 = BooruConfig.empty.toBooruConfigData();
        final config2 = BooruConfig.empty.toBooruConfigData();
        final config3 = BooruConfig.empty.toBooruConfigData();
        final searchRepository = RecordingSearchSubscriptionRepository([
          subscriptionFor('current', 2),
          subscriptionFor('other', 3),
        ]);
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          searchSubscriptionRepository: searchRepository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: config1);
        await notifier.add(data: config2, setAsCurrent: true);
        await notifier.add(data: config3);

        await notifier.delete(config2.toBooruConfig(id: 2)!);

        expect(searchRepository.deletedProfileIds, [2]);
        expect(
          searchRepository.remaining.every(
            (subscription) => subscription.profileId != 2,
          ),
          isTrue,
        );
      });

      test('removes pinned searches with another profile', () async {
        final config1 = BooruConfig.empty.toBooruConfigData();
        final config2 = BooruConfig.empty.toBooruConfigData();
        final config3 = BooruConfig.empty.toBooruConfigData();
        final searchRepository = RecordingSearchSubscriptionRepository([
          subscriptionFor('other', 1),
          subscriptionFor('current', 2),
        ]);
        final container = createBooruConfigContainer(
          settingsRepository: InMemorySettingsRepository(),
          searchSubscriptionRepository: searchRepository,
        );
        addTearDown(container.dispose);
        final notifier = container.read(booruConfigProvider.notifier);
        await notifier.add(data: config1);
        await notifier.add(data: config2, setAsCurrent: true);
        await notifier.add(data: config3);

        await notifier.delete(config1.toBooruConfig(id: 1)!);

        expect(searchRepository.deletedProfileIds, [1]);
        expect(
          searchRepository.remaining.every(
            (subscription) => subscription.profileId != 1,
          ),
          isTrue,
        );
      });

      test(
        'publishes remaining pinned searches after profile deletion',
        () async {
          final config1 = BooruConfig.empty.toBooruConfigData();
          final config2 = BooruConfig.empty.toBooruConfigData();
          final searchRepository = RecordingSearchSubscriptionRepository([
            subscriptionFor('deleted', 1),
            subscriptionFor('remaining', 2),
          ]);
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            searchSubscriptionRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config1);
          await notifier.add(data: config2);
          await container.read(searchSubscriptionsProvider.future);

          await notifier.delete(config1.toBooruConfig(id: 1)!);

          expect(
            container
                .read(searchSubscriptionsProvider)
                .requireValue
                .subscriptions
                .map((subscription) => subscription.id),
            ['remaining'],
          );
        },
      );

      test(
        'keeps the profile when pinned-search cleanup fails',
        () async {
          final config = BooruConfig.empty.toBooruConfigData();
          final pinnedSearch = subscriptionFor('failed-cleanup', 1);
          final searchRepository = RecordingSearchSubscriptionRepository([
            pinnedSearch,
          ])..deleteFailure = StateError('search deletion failed');
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            searchSubscriptionRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config);
          final failures = <String>[];

          await notifier.delete(
            config.toBooruConfig(id: 1)!,
            onFailure: failures.add,
          );

          expect(
            container.read(booruConfigProvider).map((config) => config.id),
            [1],
          );
          expect(searchRepository.remaining, [pinnedSearch]);
          expect(failures, ['Bad state: search deletion failed']);
        },
      );

      test(
        'restores exact pinned searches when profile deletion fails',
        () async {
          final config = BooruConfig.empty.toBooruConfigData();
          final pinnedSearches = [
            subscriptionFor('first', 1),
            subscriptionFor('second', 1, position: 1),
          ];
          final unaffectedSearch = subscriptionFor('other', 2);
          final organization = SearchOrganization(
            folders: [
              SharedSearchFolder(
                id: 'mixed',
                name: 'Mixed',
                searchIds: [pinnedSearches.first.id, unaffectedSearch.id],
              ),
            ],
            homeSearchIds: [pinnedSearches.last.id],
          );
          final searchRepository = RecordingSearchSubscriptionRepository([
            ...pinnedSearches,
            unaffectedSearch,
          ], organization: organization);
          final configRepository = InMemoryBooruConfigRepository(
            removeFailure: StateError('profile deletion failed'),
          );
          final container = createBooruConfigContainer(
            settingsRepository: InMemorySettingsRepository(),
            booruConfigRepository: configRepository,
            searchSubscriptionRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config);
          await container.read(searchSubscriptionsProvider.future);
          var publishedStates = 0;
          final subscription = container.listen(
            searchSubscriptionsProvider,
            (_, next) {
              if (next.hasValue) publishedStates++;
            },
          );
          addTearDown(subscription.close);
          final failures = <String>[];

          await notifier.delete(
            config.toBooruConfig(id: 1)!,
            onFailure: failures.add,
          );

          expect(
            container.read(booruConfigProvider).map((config) => config.id),
            [1],
          );
          expect(searchRepository.deletedProfileIds, [1]);
          expect(searchRepository.restoredProfileIds, [1]);
          expect(searchRepository.restoredSubscriptions, pinnedSearches);
          expect(searchRepository.restoredOrganization, organization);
          expect(
            searchRepository.remaining,
            unorderedEquals([...pinnedSearches, unaffectedSearch]),
          );
          expect(
            container
                .read(searchSubscriptionsProvider)
                .requireValue
                .subscriptions,
            unorderedEquals([...pinnedSearches, unaffectedSearch]),
          );
          expect(publishedStates, 1);
          expect(failures, ['Bad state: profile deletion failed']);
        },
      );

      test(
        'restores pinned searches when current-profile replacement persistence fails',
        () async {
          final config1 = BooruConfig.empty.toBooruConfigData();
          final config2 = BooruConfig.empty.toBooruConfigData();
          final config3 = BooruConfig.empty.toBooruConfigData();
          final pinnedSearches = [
            subscriptionFor('first', 2),
            subscriptionFor('second', 2, position: 1),
          ];
          final unaffectedSearch = subscriptionFor('other', 3);
          final searchRepository = RecordingSearchSubscriptionRepository([
            ...pinnedSearches,
            unaffectedSearch,
          ]);
          final configRepository = InMemoryBooruConfigRepository();
          final settingsRepository = InMemorySettingsRepository();
          final container = createBooruConfigContainer(
            settingsRepository: settingsRepository,
            booruConfigRepository: configRepository,
            searchSubscriptionRepository: searchRepository,
          );
          addTearDown(container.dispose);
          final notifier = container.read(booruConfigProvider.notifier);
          await notifier.add(data: config1);
          await notifier.add(data: config2, setAsCurrent: true);
          await notifier.add(data: config3);
          settingsRepository.saveFailure = StateError('settings save failed');
          final failures = <String>[];

          await notifier.delete(
            config2.toBooruConfig(id: 2)!,
            onFailure: failures.add,
          );

          expect(
            (await configRepository.getAll()).map((config) => config.id),
            [1, 2, 3],
          );
          expect(searchRepository.restoredProfileIds, [2]);
          expect(searchRepository.restoredSubscriptions, pinnedSearches);
          expect(
            searchRepository.remaining,
            unorderedEquals([...pinnedSearches, unaffectedSearch]),
          );
          expect(failures, ['Bad state: settings save failed']);
          expect(failures, hasLength(1));
        },
      );
    },
  );
}
