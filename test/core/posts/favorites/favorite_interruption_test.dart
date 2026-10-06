import 'dart:async';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/http/client/coordination.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final config = BooruConfig.defaultConfig(
    booruType: BooruType.danbooru,
    url: 'https://site.test',
    customDownloadFileNameFormat: null,
  ).auth;
  for (final cancelled in [false, true]) {
    for (final prior in [null, false, true]) {
      test(
        'interrupted ${cancelled ? 'cancel' : 'cooldown'} restores $prior exactly',
        () async {
          var attempts = 0;
          final error = DioException(
            requestOptions: RequestOptions(path: '/favorite'),
            type: cancelled
                ? DioExceptionType.cancel
                : DioExceptionType.unknown,
            error: cancelled
                ? null
                : ApiCooldownException(
                    ApiQuotaKey.fromUri(Uri.parse('https://site.test')),
                    DateTime.now().toUtc().add(const Duration(seconds: 30)),
                  ),
          );
          final container = ProviderContainer(
            overrides: [
              favoriteRepoProvider(config).overrideWithValue(
                FavoriteRepositoryBuilder(
                  add: (_) {
                    attempts++;
                    return Future<AddFavoriteStatus>.error(error);
                  },
                  remove: (_) {
                    attempts++;
                    return Future<bool>.error(error);
                  },
                  filter: (_) async => prior ?? false ? [1] : [],
                  isFavorited: (_) => false,
                  canFavorite: () => true,
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(favoritesProvider(config).notifier);
          if (prior != null) await notifier.checkFavorites([1]);
          final before = container.read(favoritesProvider(config));
          await expectLater(
            prior ?? false ? notifier.remove(1) : notifier.add(1),
            throwsA(same(error)),
          );
          expect(container.read(favoritesProvider(config)), before);
          expect(attempts, 1);
        },
      );
    }
  }
  test(
    'older interrupted add cannot erase a newer confirmed removal',
    () async {
      final addResult = Completer<AddFavoriteStatus>();
      final error = DioException(
        requestOptions: RequestOptions(path: '/favorite'),
        type: DioExceptionType.cancel,
      );
      final container = ProviderContainer(
        overrides: [
          favoriteRepoProvider(config).overrideWithValue(
            FavoriteRepositoryBuilder(
              add: (_) => addResult.future,
              remove: (_) async => true,
              isFavorited: (_) => false,
              canFavorite: () => true,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(favoritesProvider(config).notifier);
      final oldAction = notifier.add(1);
      final rejected = expectLater(oldAction, throwsA(same(error)));
      expect(await notifier.remove(1), true);
      addResult.completeError(error);
      await rejected;
      expect(container.read(favoritesProvider(config))[1], false);
    },
  );
  for (final olderFirst in [false, true]) {
    for (final olderSucceeds in [false, true]) {
      test(
        'overlapping intents olderFirst=$olderFirst olderSucceeds=$olderSucceeds use confirmed base',
        () async {
          final addResult = Completer<AddFavoriteStatus>();
          final removeResult = Completer<bool>();
          final error = DioException(
            requestOptions: RequestOptions(path: '/favorite'),
            type: DioExceptionType.cancel,
          );
          final container = ProviderContainer(
            overrides: [
              favoriteRepoProvider(config).overrideWithValue(
                FavoriteRepositoryBuilder(
                  add: (_) => addResult.future,
                  remove: (_) => removeResult.future,
                  isFavorited: (_) => false,
                  canFavorite: () => true,
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(favoritesProvider(config).notifier);
          final older = notifier.add(1);
          final newer = notifier.remove(1);
          final olderCheck = olderSucceeds
              ? older.then((value) => expect(value, AddFavoriteStatus.success))
              : expectLater(older, throwsA(same(error)));
          final newerCheck = expectLater(newer, throwsA(same(error)));
          void finishOlder() {
            if (olderSucceeds) {
              addResult.complete(AddFavoriteStatus.success);
            } else {
              addResult.completeError(error);
            }
          }

          if (olderFirst) {
            finishOlder();
            await olderCheck;
            removeResult.completeError(error);
            await newerCheck;
          } else {
            removeResult.completeError(error);
            await newerCheck;
            finishOlder();
            await olderCheck;
          }
          final state = container.read(favoritesProvider(config));
          expect(state.containsKey(1), olderSucceeds);
          expect(state[1], olderSucceeds ? true : null);
        },
      );
    }
  }
  test('interrupted status read does not cache false', () async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/status'),
      type: DioExceptionType.cancel,
    );
    final container = ProviderContainer(
      overrides: [
        favoriteRepoProvider(config).overrideWithValue(
          FavoriteRepositoryBuilder(
            add: (_) async => AddFavoriteStatus.success,
            remove: (_) async => true,
            filter: (_) async => throw error,
            isFavorited: (_) => false,
            canFavorite: () => true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(favoritesProvider(config).notifier).checkFavorites([1]),
      throwsA(same(error)),
    );
    expect(container.read(favoritesProvider(config)).containsKey(1), false);
  });
}
