import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_repository_factory_hive.dart';
import 'package:boorusama/core/tags/favorites/src/providers/providers.dart';
import 'package:boorusama/core/tags/favorites/types.dart';

void main() {
  testWidgets(
    'replacing runtime scope preserves the new favorite-tag repository',
    (tester) async {
      final root = await tester.runAsync(
        () => Directory.systemTemp.createTemp('hive-review-'),
      );
      Hive.init(root!.path);
      addTearDown(
        () => tester.runAsync(() async {
          await Hive.close();
          await root.delete(recursive: true);
        }),
      );
      await tester.runAsync(
        () =>
            const HiveFavoriteTagRepositoryFactory(boxName: 'reboot-review')
                .create(),
      );
      late Future<FavoriteTagRepository> current;
      Widget scope() => ProviderScope(
        key: UniqueKey(),
        overrides: [
          favoriteTagRepositoryFactoryProvider.overrideWithValue(
            const HiveFavoriteTagRepositoryFactory(boxName: 'reboot-review'),
          ),
        ],
        child: Consumer(
          builder: (_, ref, _) {
            current = ref.watch(favoriteTagRepoProvider.future);
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(scope());
      final first = (await tester.runAsync(() => current))!;
      expect(await first.getAll(), isEmpty);
      await tester.pumpWidget(scope());
      final second = (await tester.runAsync(() => current))!;
      await tester.runAsync(() async {
        expect(await second.getAll(), isEmpty);
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}
