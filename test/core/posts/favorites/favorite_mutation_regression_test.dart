import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/src/types/favorite_interruption.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final auth = BooruConfig.fromJson({
    ...BooruConfig.defaultConfig(
      booruType: BooruType.gelbooruV2,
      url: 'https://rule34.xxx/',
      customDownloadFileNameFormat: null,
    ).toJson(),
    'id': '00000000-0000-4000-8000-00000000002a',
    'login': '42',
  }).auth;

  ProviderContainer create(FavoriteRepository repository) {
    final container = ProviderContainer(
      overrides: [favoriteRepoProvider(auth).overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final confirmed in [false, true]) {
    test('a mutation fences only its post (confirmed: $confirmed)', () async {
      final response = Completer<bool>();
      final container = create(_repo(remove: (_) => response.future));
      final notifier = container.read(favoritesProvider(auth).notifier);
      notifier.observeOwnFavorites([7], notifier.beginRead(), owner: '42');
      final before = notifier.beginRead();
      final mutation = notifier.remove(7);
      final during = notifier.beginRead();
      notifier.observeOwnFavorites([7, 8], before, owner: '42');
      expect(container.read(favoritesProvider(auth))[7], false);
      expect(container.read(favoritesProvider(auth))[8], true);
      response.complete(confirmed);
      expect(await mutation, confirmed);
      notifier.observeOwnFavorites([7, 9], during, owner: '42');
      expect(container.read(favoritesProvider(auth))[7], !confirmed);
      expect(container.read(favoritesProvider(auth))[9], true);
      notifier.observeOwnFavorites([7], notifier.beginRead(), owner: '42');
      expect(container.read(favoritesProvider(auth))[7], true);
    });
  }

  test('an unrelated mutation does not discard a conclusive lookup', () async {
    final response = Completer<List<int>?>();
    final container = create(_repo(filter: (_) => response.future));
    final notifier = container.read(favoritesProvider(auth).notifier);
    final lookup = notifier.checkFavorites([7, 8]);
    expect(await notifier.add(9), AddFavoriteStatus.success);
    response.complete([7]);
    await lookup;
    expect(container.read(favoritesProvider(auth)).unlock, {
      7: true,
      8: false,
      9: true,
    });
  });

  test('out-of-scope lookup results cannot fabricate negatives', () async {
    final container = create(_repo(filter: (_) async => [99]));
    await container.read(favoritesProvider(auth).notifier).checkFavorites([7]);
    expect(container.read(favoritesProvider(auth)), isEmpty);
  });

  test(
    'capability rejection does not mutate or project cached state',
    () async {
      var calls = 0;
      final container = create(
        FavoriteRepositoryBuilder(
          canFavorite: () => false,
          add: (_) async {
            calls++;
            return AddFavoriteStatus.success;
          },
          remove: (_) async {
            calls++;
            return true;
          },
        ),
      );
      final notifier = container.read(favoritesProvider(auth).notifier);
      expect(await notifier.add(7), AddFavoriteStatus.failure);
      expect(await notifier.remove(7), false);
      expect(calls, 0);
      expect(container.read(favoritesProvider(auth)), isEmpty);
    },
  );

  for (final captured in [false, true]) {
    test(
      'completed add keeps its state after cleanup interruption ($captured)',
      () async {
        final interruption = FavoriteCompletedWithInterruption(
          DioException.requestCancelled(
            requestOptions: RequestOptions(path: '/cleanup'),
            reason: 'synthetic cancellation',
          ),
          StackTrace.current,
        );
        final container = create(_repo(add: (_) async => throw interruption));
        final notifier = container.read(favoritesProvider(auth).notifier);
        if (captured) {
          FavoriteCompletedWithInterruption? reported;
          final result = await collectFavoriteInterruptions(
            () => notifier.add(7),
            (error) => reported = error,
          );
          expect(result, AddFavoriteStatus.success);
          expect(reported, same(interruption));
        } else {
          await expectLater(notifier.add(7), throwsA(same(interruption)));
        }
        expect(container.read(favoritesProvider(auth))[7], true);
      },
    );
  }
}

FavoriteRepository _repo({
  Future<AddFavoriteStatus> Function(int)? add,
  Future<bool> Function(int)? remove,
  Future<List<int>?> Function(List<int>)? filter,
}) => FavoriteRepositoryBuilder(
  canFavorite: () => true,
  add: add ?? (_) async => AddFavoriteStatus.success,
  remove: remove ?? (_) async => true,
  filter: filter,
);
