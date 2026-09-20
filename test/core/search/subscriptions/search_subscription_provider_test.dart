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
}
