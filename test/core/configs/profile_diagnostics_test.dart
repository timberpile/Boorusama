import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/configs/config/src/data/booru_config_repository_hive.dart';
import 'package:boorusama/core/configs/config/types.dart';
import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test(
    'failed profile write preserves null result and one payload-free cause',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'profile-diagnostics-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<String>('profiles');
      final logger = AppLogger();
      final repository = HiveBooruConfigRepository(box: box, logger: logger);
      final data = BooruConfigData.fromJson({
        ...jsonDecode(HiveBooruConfigRepository.defaultValue())
            as Map<String, dynamic>,
        'name': 'private-profile-name',
        'apiKey': 'private-credential',
      })!;
      await box.close();
      try {
        expect(await repository.update('private-profile-id', data), isNull);
        expect(logger.logs, hasLength(1));
        expect(logger.dump(), contains('write_profile'));
        expect(logger.dump(), contains('HiveError'));
        expect(logger.dump(), contains('write_not_confirmed'));
        expect(logger.dump(), isNot(contains('private-')));
        expect(logger.logs.single.sensitiveMessage, isNull);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
