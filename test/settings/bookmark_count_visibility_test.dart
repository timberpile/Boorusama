import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  test(
    'absent and malformed count preferences are disabled on existing installs',
    () {
      expect(Settings.defaultSettings.showBookmarkCount, isFalse);
      for (final stored in [null, false, 'true', 1]) {
        final json = Settings.defaultSettings.toJson()
          ..remove('showBookmarkCount');
        if (stored != null) json['showBookmarkCount'] = stored;
        expect(Settings.fromJson(json).showBookmarkCount, isFalse);
      }
    },
  );

  test(
    'count preference survives unrelated updates and repository reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bookmark-count-',
      );
      Hive.init(directory.path);
      var box = await Hive.openBox('bookmark_count_settings');
      try {
        // Simulate an existing installation whose saved settings predate this key.
        final legacy = Settings.defaultSettings.toJson()
          ..remove('showBookmarkCount');
        await box.put('settings', jsonEncode(legacy));
        var repository = SettingsRepositoryHive(Future.value(box));
        final initial = (await repository.load().run()).fold(
          (error) => throw StateError('$error'),
          (settings) => settings,
        );
        expect(initial.showBookmarkCount, isFalse);
        final enabled = initial
            .copyWith(showBookmarkCount: true)
            .copyWith(reduceAnimations: true);
        expect(enabled, isNot(initial));
        expect(await repository.save(enabled), isTrue);
        await box.close();
        box = await Hive.openBox('bookmark_count_settings');
        repository = SettingsRepositoryHive(Future.value(box));
        final reopened = (await repository.load().run()).fold(
          (error) => throw StateError('$error'),
          (settings) => settings,
        );
        expect(reopened.showBookmarkCount, isTrue);
        expect(reopened.reduceAnimations, isTrue);
        expect(
          reopened.copyWith(
            showBookmarkCount: initial.showBookmarkCount,
            reduceAnimations: initial.reduceAnimations,
          ),
          initial,
        );
        final disabled = reopened.copyWith(showBookmarkCount: false);
        expect(await repository.save(disabled), isTrue);
        expect(
          (await repository.load().run()).fold(
            (error) => throw StateError('$error'),
            (settings) => settings.showBookmarkCount,
          ),
          isFalse,
        );
      } finally {
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
