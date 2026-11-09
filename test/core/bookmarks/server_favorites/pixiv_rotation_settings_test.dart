import 'dart:io';

import 'package:booru_clients/pixiv.dart';
import 'package:boorusama/boorus/pixiv/client_provider.dart';
import 'package:boorusama/boorus/pixiv/configs/extra_data.dart';
import 'package:boorusama/core/boorus/booru/types.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/foundation/data_mutation_coordinator.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/configs/manage/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'test_support.dart' show FavoriteTestStore;

class _Library extends BookmarkLibraryNotifier {
  @override
  Future<T> runWithLibrary<T>(Future<T> Function() operation) =>
      ref.read(dataMutationCoordinatorProvider).runExclusive(operation);

  @override
  Future<BookmarkLibraryState> build() async => await snapshotForExport();
  @override
  Future<BookmarkLibraryState> snapshotForExport() async =>
      BookmarkLibraryState(
        bookmarks: const [],
        groups: [BookmarkGroup(id: 'target', name: 'Target', bookmarkIds: {})],
      );
}

void main() {
  test('real persisted Pixiv rotation does not reject unrelated global or profile assignments', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pixiv-sync-rotation-',
    );
    Hive.init(directory.path);
    final box = await Hive.openBox<String>('profiles');
    final repository = HiveBooruConfigRepository(box: box);
    final pixiv = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000001',
      'booruId': BooruType.pixiv.id,
      'booruIdHint': BooruType.pixiv.id,
      'url': 'https://pixiv.net',
      'apiKey': 'initial-fixture',
      'passHash': const PixivExtraData(userId: '42').toPassHash(),
    });
    final other = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': '00000000-0000-4000-8000-000000000002',
      'booruId': BooruType.danbooru.id,
      'booruIdHint': BooruType.danbooru.id,
      'url': 'https://danbooru.donmai.us',
      'login': 'fixture',
      'apiKey': 'fixture',
    });
    await repository.addAll([pixiv, other]);
    final profiles = await repository.getAll();
    final store = FavoriteTestStore();
    ProviderContainer create() => ProviderContainer(
      overrides: [
        booruConfigRepoProvider.overrideWithValue(repository),
        booruConfigProvider.overrideWith(
          () => BooruConfigNotifier(initialConfigs: profiles),
        ),
        bookmarkLibraryProvider.overrideWith(_Library.new),
        miscDataStoreProvider.overrideWithValue(store),
      ],
    );
    final container = create();
    try {
      final before = await container.read(
        serverFavoriteSettingsProvider.future,
      );
      await persistPixivRotatedToken(
        repo: repository,
        configId: pixiv.id,
        expectedRefreshToken: 'initial-fixture',
        tokens: PixivTokens.fromJson({
          'refresh_token': 'rotated-fixture',
          'expires_in': 3600,
          'user': {'id': '42', 'name': 'Fixture'},
        }),
      );
      final rotated = (await repository.getAll()).firstWhere(
        (p) => p.id == pixiv.id,
      );
      expect(rotated.auth, isNot(profiles.first.auth));
      expect(container.read(booruConfigProvider), profiles);
      final updated = before
          .withGlobal('target')
          .withProfile(other.id, const ServerFavoriteTarget.group('target'));
      await container
          .read(serverFavoriteSettingsProvider.notifier)
          .saveAll(profiles: profiles, expected: before, updated: updated);
      expect(
        await container.read(serverFavoriteSettingsProvider.future),
        updated,
      );
      final restarted = create();
      try {
        expect(
          await restarted.read(serverFavoriteSettingsProvider.future),
          updated,
        );
      } finally {
        restarted.dispose();
      }
      final switched = BooruConfig.fromJson({
        ...rotated.toJson(),
        'passHash': const PixivExtraData(userId: '99').toPassHash(),
      });
      await repository.update(pixiv.id, switched.toBooruConfigData());
      await expectLater(
        container
            .read(serverFavoriteSettingsProvider.notifier)
            .saveAll(
              profiles: profiles,
              expected: updated,
              updated: updated.withGlobal(null),
            ),
        throwsA(
          isA<ServerFavoriteException>().having(
            (e) => e.problem,
            'problem',
            ServerFavoriteProblem.accountChanged,
          ),
        ),
      );
      expect(store.writes, 1);
    } finally {
      container.dispose();
      await box.close();
      await directory.delete(recursive: true);
    }
  });
}
