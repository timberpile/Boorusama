// Dart imports:
import 'dart:io';

// Package imports:
import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

// Project imports:
import 'package:boorusama/core/hive/hive_adapters.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_hive_object.dart';
import 'package:boorusama/core/tags/favorites/src/data/favorite_tag_repository_hive.dart';
import 'package:boorusama/core/tags/favorites/types.dart';

void main() {
  late Directory tempDirectory;
  late Box<FavoriteTagHiveObject> box;
  late FavoriteTagRepositoryHive repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'favorite_tag_repository_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FavoriteTagHiveObjectAdapter());
    }
    box = await Hive.openBox<FavoriteTagHiveObject>('favorite_tags_test');
    repository = FavoriteTagRepositoryHive(box);
  });

  tearDown(() async {
    await box.close();
    await tempDirectory.delete(recursive: true);
  });

  test('renaming moves the Hive key and remains deletable', () async {
    final original = await repository.create(name: 'old_tag');

    await repository.updateFirst(
      original.name,
      original.copyWith(name: 'new_tag'),
    );

    expect(await repository.getFirst('old_tag'), isNull);
    expect(await repository.getFirst('new_tag'), isNotNull);
    expect(box.containsKey('old_tag'), isFalse);
    expect(box.containsKey('new_tag'), isTrue);

    expect(await repository.deleteFirst('new_tag'), isNotNull);
    expect(await repository.getAll(), isEmpty);
  });

  test('restore preserves metadata and never overwrites', () async {
    final original = FavoriteTag(
      name: 'archived',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2021),
      labels: const ['daily'],
    );

    expect(await repository.restore(original), original);
    expect(await repository.getFirst(original.name), original);

    final replacement = original.copyWith(
      createdAt: DateTime.utc(2022),
      labels: () => const ['replacement'],
    );
    expect(await repository.restore(replacement), isNull);
    expect(await repository.getFirst(original.name), original);
  });

  test('replacement exactly matches imported tags and metadata', () async {
    await repository.create(name: 'local_only');
    final imported = FavoriteTag(
      name: 'imported',
      createdAt: DateTime.utc(2020),
      updatedAt: DateTime.utc(2021),
      labels: const ['shared'],
    );

    await repository.replaceAll([imported]);

    expect(await repository.getAll(), [imported]);
    expect(await repository.getFirst('local_only'), isNull);
  });
}
