import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/posts/related/related_posts_order.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  for (final value in [null, 'oldest', 'unknown', 1, true, [], {}]) {
    test('Related order $value safely defaults to Oldest', () {
      final json = Settings.defaultSettings.toJson()
        ..['relatedPostsOrder'] = value;
      expect(
        Settings.fromJson(json).relatedPostsOrder,
        RelatedPostsOrder.oldest,
      );
    });
  }

  test('Related preference survives storage reopening and Settings backup round trip', () async {
    final directory = await Directory.systemTemp.createTemp('related-order-');
    Hive.init(directory.path);
    var box = await Hive.openBox<String>('settings');
    try {
      var repository = SettingsRepositoryHive(Future.value(box));
      final settings = Settings.defaultSettings.copyWith(
        relatedPostsOrder: RelatedPostsOrder.newest,
      );
      expect(await repository.save(settings), isTrue);
      await box.close();
      box = await Hive.openBox<String>('settings');
      repository = SettingsRepositoryHive(Future.value(box));
      final restored = (await repository.load().run()).getOrElse(
        (_) => throw StateError('load failed'),
      );
      final backup = Settings.fromJson(
        jsonDecode(jsonEncode(restored.toJson())) as Map<String, dynamic>,
      );
      expect(backup.relatedPostsOrder, RelatedPostsOrder.newest);
      expect(
        backup.copyWith(showBookmarkCount: true).relatedPostsOrder,
        RelatedPostsOrder.newest,
      );
      expect(backup.listing, Settings.defaultSettings.listing);
      expect(
        backup.copyWith(relatedPostsOrder: RelatedPostsOrder.oldest),
        isNot(backup),
      );
    } finally {
      if (box.isOpen) await box.close();
      await directory.delete(recursive: true);
    }
  });
}
