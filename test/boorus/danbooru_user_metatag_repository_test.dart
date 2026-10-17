import 'dart:io';

import 'package:boorusama/boorus/danbooru/tags/user_metatags/src/data/factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory root;
  const factory = HiveDanbooruUserMetatagRepositoryFactory();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('user-metatags-');
    Hive.init(root.path);
  });
  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  test(
    'first use seeds defaults, intentionally empty saved list stays empty',
    () async {
      final first = await factory.create();
      expect(
        first.getAll(),
        unorderedEquals(['age', 'rating', 'order', 'score', 'id', 'user']),
      );
      for (final tag in first.getAll()) {
        await first.delete(tag);
      }
      expect(first.getAll(), isEmpty);
      await factory.dispose(first);
      final reopened = await factory.create();
      expect(reopened.getAll(), isEmpty);
      await factory.dispose(reopened);
    },
  );

  test(
    'custom partial list survives a cold reopen without added defaults',
    () async {
      final first = await factory.create();
      for (final tag in first.getAll()) {
        await first.delete(tag);
      }
      await first.put('rating');
      await first.put('user');
      await factory.dispose(first);
      final reopened = await factory.create();
      expect(reopened.getAll(), ['rating', 'user']);
      await factory.dispose(reopened);
    },
  );
}
