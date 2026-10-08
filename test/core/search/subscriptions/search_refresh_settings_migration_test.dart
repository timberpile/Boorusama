import 'dart:convert';

import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'subscription_test_utils.dart';

void main() {
  test(
    'legacy minute refresh settings are rewritten once without losing other values',
    () async {
      final box = _CountingBox();
      final legacy = Settings.defaultSettings.toJson()
        ..['searchRefresh'] = {'enabled': false, 'intervalMinutes': 5}
        ..['futureSetting'] = 'preserve';
      await box.put('settings', jsonEncode(legacy));
      final repository = SettingsRepositoryHive(Future.value(box));

      final first = await repository.load().run();
      expect(
        first.fold(
          (error) => null,
          (settings) => settings.searchRefresh.enabled,
        ),
        isFalse,
      );
      final written =
          jsonDecode(box.get('settings') as String) as Map<String, dynamic>;
      expect(written['futureSetting'], 'preserve');
      expect(written['searchRefresh'], {
        'schemaVersion': 2,
        'enabled': false,
        'pinnedSearchesEnabled': true,
        'followingFeedsEnabled': true,
        'mode': 'adaptive',
        'fixedIntervalHours': 24,
        'wifiEthernetOnly': true,
      });

      final writesAfterMigration = box.writes;
      await repository.load().run();
      expect(box.writes, writesAfterMigration);
    },
  );
}

class _CountingBox extends MemoryBox<dynamic> {
  var writes = 0;

  @override
  Future<void> put(dynamic key, dynamic value) {
    writes++;
    return super.put(key, value);
  }
}
