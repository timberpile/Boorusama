import 'dart:async';

import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/posts/favorites/providers.dart';
import 'package:boorusama/core/posts/favorites/src/data/confirmed_favorite_repository.dart';
import 'package:boorusama/core/posts/favorites/src/data/providers.dart';
import 'package:boorusama/core/posts/favorites/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late Future<AddFavoriteStatus> Function(int) add;
  late Future<bool> Function(int) remove;
  late Future<List<int>?> Function(List<int>)? lookup;
  late int mutations;
  late int projections;

  setUp(() {
    mutations = 0;
    projections = 0;
    add = (_) async => AddFavoriteStatus.success;
    remove = (_) async => true;
    lookup = null;
    container = ProviderContainer(
      overrides: [
        favoriteRepoProvider.overrideWith(
          (ref, auth) => ConfirmedFavoriteRepository(
            delegate: FavoriteRepositoryBuilder(
              canFavorite: () => true,
              filter: lookup,
              add: (id) {
                mutations++;
                return add(id);
              },
              remove: (id) {
                mutations++;
                return remove(id);
              },
            ),
            prepareProjection: (_, _) async => () {
              projections++;
              return Future.value();
            },
            onProjectionError: (error) => fail('$error'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  FavoritesNotifier notifier([BooruConfigAuth? auth]) =>
      container.read(favoritesProvider(auth ?? _profile.auth).notifier);
  bool? status(int id, [BooruConfigAuth? auth]) =>
      container.read(favoriteStatusProvider((auth ?? _profile.auth, id)));

  void own(Iterable<int> ids, {FavoriteRead? read}) {
    final observer = notifier();
    observer.observeOwnFavorites(
      ids,
      read ?? observer.beginRead(),
      owner: '42',
    );
  }

  test(
    'partial pages accumulate silently and leave unreturned IDs unknown',
    () {
      own([1, 2]);
      final previous = container.read(favoritesProvider(_profile.auth));
      own([1, 2, 2]);
      expect(container.read(favoritesProvider(_profile.auth)), same(previous));
      own([3, 4]);
      own([]);
      own([4]);
      expect(
        [for (var id = 1; id <= 5; id++) status(id)],
        [true, true, true, true, null],
      );
      expect(mutations, 0);
      expect(projections, 0);
    },
  );

  for (final acknowledged in [true, false]) {
    test(
      'remove settlement ($acknowledged) fences reads on both sides of start',
      () async {
        final response = Completer<bool>();
        remove = (_) => response.future;
        own([7]);
        final observer = notifier();
        final before = observer.beginRead();
        final mutation = observer.remove(7);
        final pending = observer.beginRead();

        own([7], read: before);
        expect(status(7), false);
        response.complete(acknowledged);
        expect(await mutation, acknowledged);
        own([7, 8], read: before);
        own([7, 8], read: pending);
        expect(status(7), !acknowledged);
        expect(status(8), true);

        own([7]);
        expect(status(7), true);
      },
    );

    test(
      'add settlement ($acknowledged) fences stale negatives and positives',
      () async {
        final response = Completer<AddFavoriteStatus>();
        add = (_) => response.future;
        final observer = notifier();
        final before = observer.beginRead();
        final mutation = observer.add(7);
        final pending = observer.beginRead();
        observer.observeFavorites({7: false}, before);
        expect(status(7), true);
        response.complete(
          acknowledged ? AddFavoriteStatus.success : AddFavoriteStatus.failure,
        );
        expect((await mutation).confirmed, acknowledged);
        own([7], read: pending);
        observer.observeFavorites({7: false}, before);
        expect(status(7), acknowledged ? true : null);
      },
    );
  }

  test('an older lookup can fill other IDs but cannot overwrite a newer observation', () async {
    final response = Completer<List<int>?>();
    lookup = (ids) {
      expect(ids, [7, 8]);
      return response.future;
    };
    final old = notifier().checkFavorites([7, 8]);
    own([7]);
    response.complete([]);
    await old;
    expect(status(7), true);
    expect(status(8), false);
  });

  test(
    'overlapping lookups share pending IDs and wait for both responses',
    () async {
      final first = Completer<List<int>?>();
      final second = Completer<List<int>?>();
      final requests = <List<int>>[];
      lookup = (ids) {
        requests.add(ids);
        return requests.length == 1 ? first.future : second.future;
      };
      final older = notifier().checkFavorites([1, 2]);
      var finished = false;
      final newer = notifier()
          .checkFavorites([2, 3])
          .then((_) => finished = true);
      expect(requests, [
        [1, 2],
        [3],
      ]);
      second.complete([3]);
      await notifier().checkFavorites([3]);
      expect(finished, isFalse);
      first.complete([2]);
      await Future.wait([older, newer]);
      expect([status(1), status(2), status(3)], [false, true, true]);
    },
  );

  test('unsupported and inconclusive lookups leave unknown; confirmed negatives work', () async {
    expect(notifier().repo.supportsFavoriteLookup, false);
    await notifier().checkFavorites([7]);
    expect(status(7), isNull);

    lookup = (_) async => null;
    container.invalidate(favoriteRepoProvider(_profile.auth));
    expect(notifier().repo.supportsFavoriteLookup, true);
    await notifier().checkFavorites([7]);
    expect(status(7), isNull);

    lookup = (_) async => throw const FormatException();
    container.invalidate(favoriteRepoProvider(_profile.auth));
    await expectLater(notifier().checkFavorites([7]), throwsFormatException);
    expect(status(7), isNull);

    lookup = (_) async => [8];
    container.invalidate(favoriteRepoProvider(_profile.auth));
    await notifier().checkFavorites([7, 8]);
    expect(status(7), false);
    expect(status(8), true);
    expect(status(9), isNull);
  });

  test('a retry after a failed mutation uses a fresh lookup', () async {
    final stale = Completer<List<int>?>();
    final fresh = Completer<List<int>?>();
    var calls = 0;
    lookup = (_) => ++calls == 1 ? stale.future : fresh.future;
    add = (_) async => AddFavoriteStatus.failure;
    final observer = notifier();
    final original = observer.checkFavorites([7]);
    expect(await observer.add(7), AddFavoriteStatus.failure);
    final retry = observer.checkFavorites([7]);
    expect(calls, 2);
    stale.complete([7]);
    await original;
    expect(status(7), isNull);
    final overlapping = observer.checkFavorites([7]);
    expect(calls, 2);
    fresh.complete([]);
    await Future.wait([retry, overlapping]);
    expect(status(7), false);
  });

  test(
    'cache and read contexts stay with the same site/account and credentials',
    () {
      final compatible = _config(id: '00000000-0000-4000-8000-000000000002');
      final otherAccount = _config(login: '43');
      final otherSite = _config(url: 'https://other.example');
      final replacement = _config(apiKey: 'replacement');
      final read = notifier().beginRead();

      notifier().observeOwnFavorites([7], read, owner: '43');
      expect(status(7), isNull);
      for (final other in [otherAccount, otherSite, replacement]) {
        notifier(other.auth).observeFavorites({7: true}, read);
        expect(status(7, other.auth), isNull);
      }

      own([7], read: read);
      expect(status(7, compatible.auth), true);
      expect(status(7, otherAccount.auth), isNull);
      expect(status(7, otherSite.auth), isNull);
      expect(status(7, replacement.auth), isNull);
    },
  );

  test(
    'provider invalidation rejects obsolete read and mutation completions',
    () async {
      final response = Completer<AddFavoriteStatus>();
      add = (_) => response.future;
      final observer = notifier();
      final mutation = observer.add(8);
      final read = observer.beginRead();
      container.invalidate(favoritesProvider(_profile.auth));
      expect(status(8), isNull);
      response.complete(AddFavoriteStatus.success);
      expect(await mutation, AddFavoriteStatus.success);
      notifier().observeOwnFavorites([7], read, owner: '42');
      expect(status(7), isNull);
      expect(status(8), isNull);
    },
  );
}

final _profile = _config();

BooruConfig _config({
  String id = '00000000-0000-4000-8000-000000000001',
  String login = '42',
  String apiKey = 'fake-api-key',
  String url = 'https://rule34.xxx/',
}) => BooruConfig.fromJson({
  ...BooruConfig.defaultConfig(
    booruType: BooruType.gelbooruV2,
    url: url,
    customDownloadFileNameFormat: null,
  ).toJson(),
  'id': id,
  'login': login,
  'apiKey': apiKey,
});
