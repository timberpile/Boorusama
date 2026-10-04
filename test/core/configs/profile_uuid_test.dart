import 'dart:io';

import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_test/flutter_test.dart';

const profileUuid = '4d5b640c-cf50-4291-83f6-d6ff359e6389';

void main() {
  test('profile JSON retains its canonical UUID', () {
    final profile = BooruConfig.fromJson({
      ...BooruConfig.empty.toJson(),
      'id': profileUuid,
    });

    expect(profile.id, profileUuid);
    expect(profile.toJson()['id'], profileUuid);
  });

  test(
    'new profiles get distinct UUID Hive keys and old integer keys are ignored',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'profile-uuid-test',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<String>('profiles');
      addTearDown(() async {
        await box.close();
        await directory.delete(recursive: true);
      });
      await box.put(1, '{}');
      final repository = HiveBooruConfigRepository(box: box);
      final data = BooruConfig.empty.toBooruConfigData();

      final first = (await repository.add(data))!;
      final second = (await repository.add(data))!;

      expect(isCanonicalProfileId(first.id), isTrue);
      expect(isCanonicalProfileId(second.id), isTrue);
      expect(second.id, isNot(first.id));
      expect(box.keys, containsAll([1, first.id, second.id]));
      expect((await repository.getAll()).map((profile) => profile.id).toSet(), {
        first.id,
        second.id,
      });
    },
  );

  test('profile JSON rejects integer and uppercase IDs', () {
    for (final invalid in [4, profileUuid.toUpperCase()]) {
      expect(
        () => BooruConfig.fromJson({
          ...BooruConfig.empty.toJson(),
          'id': invalid,
        }),
        throwsFormatException,
      );
    }
  });
}
