import 'dart:async';
import 'dart:convert';

import 'package:boorusama/core/analytics/providers.dart';
import 'package:boorusama/core/search/following_topics/providers.dart';
import 'package:boorusama/core/search/following_topics/types.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/src/types/settings_repository.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_test_utils.dart';

void main() {
  test('every following-topic sort survives settings serialization', () {
    for (final sort in FollowingTopicSort.values) {
      final settings = Settings.defaultSettings.copyWith(
        followingTopicSort: sort.name,
      );

      expect(
        FollowingTopicSort.parse(
          Settings.fromJson(settings.toJson()).followingTopicSort,
        ),
        sort,
        reason: '${sort.name} should be restored from stored settings',
      );
    }
  });

  test('missing and unknown stored sorts default to manual order', () {
    final legacySettings = Settings.defaultSettings.toJson()
      ..remove('followingTopicSort');
    final unknownSettings = {
      ...Settings.defaultSettings.toJson(),
      'followingTopicSort': 'futureSortValue',
    };

    expect(
      FollowingTopicSort.parse(
        Settings.fromJson(legacySettings).followingTopicSort,
      ),
      FollowingTopicSort.manual,
    );
    expect(
      FollowingTopicSort.parse(
        Settings.fromJson(unknownSettings).followingTopicSort,
      ),
      FollowingTopicSort.manual,
    );
  });

  for (final sort in FollowingTopicSort.values) {
    test(
      '${sort.name} is restored after the provider is recreated',
      () async {
        final settingsBox = MemoryBox<dynamic>();
        final repository = SettingsRepositoryHive(Future.value(settingsBox));
        final firstContainer = _createContainer(repository);
        addTearDown(firstContainer.dispose);

        expect(
          firstContainer.read(followingTopicSortProvider),
          FollowingTopicSort.manual,
        );
        expect(
          await firstContainer
              .read(followingTopicSortProvider.notifier)
              .select(sort),
          isTrue,
        );

        final storedSettings = Settings.fromJson(
          jsonDecode(settingsBox.get('settings') as String),
        );
        final recreatedContainer = _createContainer(
          repository,
          initialSettings: storedSettings,
        );
        addTearDown(recreatedContainer.dispose);

        expect(
          recreatedContainer.read(followingTopicSortProvider),
          sort,
        );
      },
    );
  }

  test('a rejected save keeps the last persisted sort visible', () async {
    final repository = _ControlledSettingsRepository(
      Future.value(MemoryBox<dynamic>()),
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    final selection = container
        .read(followingTopicSortProvider.notifier)
        .select(FollowingTopicSort.updatesFirst);
    await _waitForAttempt(repository, 1);

    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    repository.releases.single.complete(false);
    expect(await selection, isFalse);
    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    expect(container.read(settingsProvider).followingTopicSort, 'manual');
  });

  test('a throwing save keeps the last persisted sort visible', () async {
    final repository = _ControlledSettingsRepository(
      Future.value(MemoryBox<dynamic>()),
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    final selection = container
        .read(followingTopicSortProvider.notifier)
        .select(FollowingTopicSort.updatesFirst);
    await _waitForAttempt(repository, 1);

    repository.releases.single.completeError(StateError('save failed'));
    expect(await selection, isFalse);
    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    expect(container.read(settingsProvider).followingTopicSort, 'manual');
  });

  test('rapid selections persist in order and finish on the latest', () async {
    final settingsBox = MemoryBox<dynamic>();
    final repository = _ControlledSettingsRepository(Future.value(settingsBox));
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    final notifier = container.read(followingTopicSortProvider.notifier);
    final first = notifier.select(FollowingTopicSort.updatesFirst);
    final second = notifier.select(FollowingTopicSort.lastPostOldest);
    await _waitForAttempt(repository, 1);

    expect(repository.attemptedSorts, ['updatesFirst']);
    repository.releases.first.complete(true);
    expect(await first, isTrue);
    await _waitForAttempt(repository, 2);

    expect(repository.attemptedSorts, ['updatesFirst', 'lastPostOldest']);
    repository.releases.last.complete(true);
    expect(await second, isTrue);
    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.lastPostOldest,
    );
    expect(
      Settings.fromJson(
        jsonDecode(settingsBox.get('settings') as String),
      ).followingTopicSort,
      'lastPostOldest',
    );
  });

  test('a failed selection does not block a newer choice', () async {
    final repository = _ControlledSettingsRepository(
      Future.value(MemoryBox<dynamic>()),
    );
    final container = _createContainer(repository);
    addTearDown(container.dispose);

    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.manual,
    );
    final notifier = container.read(followingTopicSortProvider.notifier);
    final first = notifier.select(FollowingTopicSort.updatesFirst);
    final second = notifier.select(FollowingTopicSort.lastPostOldest);
    await _waitForAttempt(repository, 1);

    repository.releases.first.completeError(StateError('save failed'));
    expect(await first, isFalse);
    await _waitForAttempt(repository, 2);

    repository.releases.last.complete(true);
    expect(await second, isTrue);
    expect(
      container.read(followingTopicSortProvider),
      FollowingTopicSort.lastPostOldest,
    );
  });
}

Future<void> _waitForAttempt(
  _ControlledSettingsRepository repository,
  int count,
) async {
  for (var i = 0; i < 50 && repository.releases.length < count; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(repository.releases, hasLength(count));
}

class _ControlledSettingsRepository extends SettingsRepositoryHive {
  _ControlledSettingsRepository(super._db);

  final attemptedSorts = <String>[];
  final releases = <Completer<bool>>[];

  @override
  Future<bool> save(Settings setting) async {
    attemptedSorts.add(setting.followingTopicSort);
    final release = Completer<bool>();
    releases.add(release);
    if (!await release.future) return false;
    return super.save(setting);
  }
}

ProviderContainer _createContainer(
  SettingsRepository repository, {
  Settings initialSettings = Settings.defaultSettings,
}) => ProviderContainer(
  overrides: [
    settingsNotifierProvider.overrideWith(
      () => SettingsNotifier(initialSettings),
    ),
    settingsRepoProvider.overrideWithValue(repository),
    loggerProvider.overrideWithValue(
      ConsoleLogger(options: const ConsoleLoggerOptions.defaults()),
    ),
    analyticsProvider.overrideWith((ref) => Future.value()),
  ],
);
