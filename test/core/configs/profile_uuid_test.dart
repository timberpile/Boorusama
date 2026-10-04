import 'dart:io';

import 'package:boorusama/core/configs/config/data.dart';
import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:hive_ce/hive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boorusama/foundation/loggers.dart';

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

  test('deleted last profile stays deleted after a restart', () async {
    final directory = await Directory.systemTemp.createTemp('profile-restart');
    Hive.init(directory.path);
    addTearDown(() async {
      if (Hive.isBoxOpen('booru_configs')) {
        await Hive.box<String>('booru_configs').close();
      }
      await directory.delete(recursive: true);
    });

    var created = 0;
    final repository = await createBooruConfigsRepo(
      logger: const _NoopLogger(),
      onCreateNew: (_) async {
        created++;
      },
    );
    expect(created, 1);
    await repository.remove((await repository.getAll()).single);
    await Hive.box<String>('booru_configs').close();

    final restarted = await createBooruConfigsRepo(
      logger: const _NoopLogger(),
      onCreateNew: (_) async {
        created++;
      },
    );
    expect(await restarted.getAll(), isEmpty);
    expect(created, 1);
  });

  test(
    'legacy-only profile rows still start with a new UUID profile',
    () async {
      final directory = await Directory.systemTemp.createTemp('profile-legacy');
      Hive.init(directory.path);
      addTearDown(() async {
        if (Hive.isBoxOpen('booru_configs')) {
          await Hive.box<String>('booru_configs').close();
        }
        await directory.delete(recursive: true);
      });
      final box = await Hive.openBox<String>('booru_configs');
      await box.put(1, '{}');
      await box.close();

      final repository = await createBooruConfigsRepo(
        logger: const _NoopLogger(),
        onCreateNew: (_) async {},
      );
      expect(
        isCanonicalProfileId((await repository.getAll()).single.id),
        isTrue,
      );
      expect(Hive.box<String>('booru_configs').keys, contains(1));
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

final class _NoopLogger implements Logger {
  const _NoopLogger();

  @override
  String getDebugName() => 'noop';

  @override
  void debug(String serviceName, String message) {}

  @override
  void error(String serviceName, String message) {}

  @override
  void info(String serviceName, String message) {}

  @override
  void verbose(String serviceName, String message) {}

  @override
  void warn(String serviceName, String message) {}
}
