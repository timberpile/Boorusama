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

  ProviderContainer create(FavoriteRepository repository) {
    final container = ProviderContainer(
      overrides: [
        favoriteRepoProvider(config).overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final cancelled in [false, true]) {
    for (final prior in [null, false, true]) {
      test(
        'interrupted action restores $prior (cancelled: $cancelled)',
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
                    DateTime.utc(2030),
                  ),
          );
          final container = create(
            FavoriteRepositoryBuilder(
              add: (_) {
                attempts++;
                return Future<AddFavoriteStatus>.error(error);
              },
              remove: (_) {
                attempts++;
                return Future<bool>.error(error);
              },
              filter: (_) async => (prior ?? false) ? [1] : [],
              canFavorite: () => true,
            ),
          );
          final notifier = container.read(favoritesProvider(config).notifier);
          if (prior != null) await notifier.checkFavorites([1]);
          final before = container.read(favoritesProvider(config));
          await expectLater(
            (prior ?? false) ? notifier.remove(1) : notifier.add(1),
            throwsA(same(error)),
          );
          expect(container.read(favoritesProvider(config)), before);
          expect(attempts, 1);
        },
      );
    }
  }

  for (final adding in [false, true]) {
    for (final interrupted in [false, true]) {
      test('same-post commands cannot overtake $adding/$interrupted', () async {
        final response = Completer<void>();
        var attempts = 0;
        final error = DioException.requestCancelled(
          requestOptions: RequestOptions(path: '/favorite'),
          reason: 'synthetic cancellation',
        );
        final container = create(
          FavoriteRepositoryBuilder(
            add: (_) async {
              attempts++;
              await response.future;
              return AddFavoriteStatus.success;
            },
            remove: (_) async {
              attempts++;
              await response.future;
              return true;
            },
            canFavorite: () => true,
          ),
        );
        final notifier = container.read(favoritesProvider(config).notifier);
        notifier.observeFavorites({1: !adding}, notifier.beginRead());
        final pending = notifier.setFavorite(1, favorited: adding);
        final completion = interrupted
            ? expectLater(pending, throwsA(same(error)))
            : pending.then((value) => expect(value, true));
        expect(await notifier.add(1), AddFavoriteStatus.failure);
        expect(await notifier.remove(1), false);
        expect(attempts, 1);
        if (interrupted) {
          response.completeError(error);
        } else {
          response.complete();
        }
        await completion;
        expect(
          container.read(favoritesProvider(config))[1],
          interrupted ? !adding : adding,
        );
        expect(attempts, 1);
      });
    }
  }

  test('an interrupted status read does not cache false', () async {
    final error = DioException.requestCancelled(
      requestOptions: RequestOptions(path: '/status'),
      reason: 'synthetic cancellation',
    );
    final container = create(
      FavoriteRepositoryBuilder(
        add: (_) async => AddFavoriteStatus.success,
        remove: (_) async => true,
        filter: (_) async => throw error,
        canFavorite: () => true,
      ),
    );
    await expectLater(
      container.read(favoritesProvider(config).notifier).checkFavorites([1]),
      throwsA(same(error)),
    );
    expect(container.read(favoritesProvider(config)).containsKey(1), false);
  });
}
