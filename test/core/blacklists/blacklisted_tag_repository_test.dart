import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:test/test.dart';

import 'package:boorusama/core/blacklists/src/data/hive/tag_repository.dart';
import 'package:boorusama/core/blacklists/types.dart';
import 'package:boorusama/core/hive/hive_adapters.dart';

void main() {
  late Directory tempDirectory;
  late HiveBlacklistedTagRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'blacklisted_tag_repository_test_',
    );
    Hive.init(tempDirectory.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(BlacklistedTagHiveObjectAdapter());
    }
    repository = HiveBlacklistedTagRepository();
    await repository.init(tempDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test('replacement exactly matches imported tags and metadata', () async {
    await repository.addTag('local_only');
    final imported = BlacklistedTag(
      id: 42,
      name: 'imported',
      isActive: false,
      createdDate: DateTime.utc(2020),
      updatedDate: DateTime.utc(2021),
    );

    await repository.replaceAll([imported]);

    expect(await repository.getBlacklist(), [imported]);
  });
}
