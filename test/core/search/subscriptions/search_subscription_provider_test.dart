// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

// Project imports:
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_hive_object.dart';
import 'package:boorusama/core/search/subscriptions/src/data/hive/search_subscription_repository_hive.dart';
import 'package:boorusama/core/search/subscriptions/src/data/providers.dart';

void main() {
  const boxName = 'pinned_search_subscriptions_provider_test';

  Future<Directory> initializeHive() async {
    final directory = await Directory.systemTemp.createTemp(
      'search_subscription_provider_test_',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(SearchSubscriptionHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(SearchPostPreviewHiveObjectAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(RecentSearchPostHiveObjectAdapter());
    }
    return directory;
  }

  test(
    'exposes a repository through an async notifier and closes its box',
    () async {
      final directory = await initializeHive();
      final box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
      final container = ProviderContainer(
        overrides: [
          searchSubscriptionRepositoryProvider.overrideWith(
            () => SearchSubscriptionRepositoryNotifier(
              openBox: () async => box,
            ),
          ),
        ],
      );

      final repository = await container.read(
        searchSubscriptionRepositoryProvider.future,
      );
      final notifier = container.read(
        searchSubscriptionRepositoryProvider.notifier,
      );
      container.dispose();
      await notifier.closeFuture;

      expect(repository, isA<HiveSearchSubscriptionRepository>());
      expect(box.isOpen, isFalse);
      await directory.delete(recursive: true);
    },
  );

  test('closes a box that opens after the provider is disposed', () async {
    final directory = await initializeHive();
    final box = await Hive.openBox<SearchSubscriptionHiveObject>(boxName);
    final opening = Completer<Box<SearchSubscriptionHiveObject>>();
    final container = ProviderContainer(
      overrides: [
        searchSubscriptionRepositoryProvider.overrideWith(
          () => SearchSubscriptionRepositoryNotifier(
            openBox: () => opening.future,
          ),
        ),
      ],
    );

    final notifier = container.read(
      searchSubscriptionRepositoryProvider.notifier,
    );
    container.read(searchSubscriptionRepositoryProvider);
    container.dispose();
    opening.complete(box);
    await notifier.closeFuture;

    expect(box.isOpen, isFalse);
    await directory.delete(recursive: true);
  });

  test('keeps the rebuilt repository usable after invalidation', () async {
    final directory = await initializeHive();
    final container = ProviderContainer(
      overrides: [
        searchSubscriptionRepositoryProvider.overrideWith(
          () => SearchSubscriptionRepositoryNotifier(
            openBox: () => Hive.openBox<SearchSubscriptionHiveObject>(boxName),
          ),
        ),
      ],
    );

    final first = await container.read(
      searchSubscriptionRepositoryProvider.future,
    );
    await first.create(
      profileId: 4,
      query: 'first',
      name: null,
      id: 'first',
    );
    container.invalidate(searchSubscriptionRepositoryProvider);
    final rebuilt = await container.read(
      searchSubscriptionRepositoryProvider.future,
    );
    final second = await rebuilt.create(
      profileId: 4,
      query: 'second',
      name: null,
      id: 'second',
    );
    expect(second.id, 'second');
    expect((await rebuilt.getAll()).map((item) => item.id), [
      'first',
      'second',
    ]);
    final notifier = container.read(
      searchSubscriptionRepositoryProvider.notifier,
    );
    container.dispose();
    await notifier.closeFuture;

    await directory.delete(recursive: true);
  });

  test('retries a failed box opening after invalidation', () async {
    final directory = await initializeHive();
    var openAttempts = 0;
    final container = ProviderContainer(
      overrides: [
        searchSubscriptionRepositoryProvider.overrideWith(
          () => SearchSubscriptionRepositoryNotifier(
            openBox: () {
              if (openAttempts++ == 0) {
                throw StateError('Opening failed.');
              }
              return Hive.openBox<SearchSubscriptionHiveObject>(boxName);
            },
          ),
        ),
      ],
    );
    SearchSubscriptionRepositoryNotifier? notifier;

    try {
      await expectLater(
        container.read(searchSubscriptionRepositoryProvider.future),
        throwsStateError,
      );
      container.invalidate(searchSubscriptionRepositoryProvider);
      final rebuilt = await container
          .read(searchSubscriptionRepositoryProvider.future)
          .timeout(const Duration(milliseconds: 100));
      final created = await rebuilt.create(
        profileId: 4,
        query: 'retry',
        name: null,
        id: 'retry',
      );

      expect(created.id, 'retry');
      expect((await rebuilt.getAll()).map((item) => item.id), ['retry']);
      notifier = container.read(
        searchSubscriptionRepositoryProvider.notifier,
      );
    } finally {
      container.dispose();
      if (notifier != null) {
        await notifier.closeFuture;
      }
      await directory.delete(recursive: true);
    }
  });
}
