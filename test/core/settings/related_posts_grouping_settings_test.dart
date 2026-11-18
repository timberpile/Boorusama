import 'dart:convert';
import 'dart:io';

import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/settings/src/data/setting_repository_hive.dart';
import 'package:boorusama/core/settings/src/pages/appearance/appearance_page.dart';
import 'package:boorusama/core/settings/src/widgets/related_posts_grouping_setting.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../search/following_topics/following_topic_test_utils.dart';

void main() {
  test(
    'existing installations and malformed Related preferences default to off',
    () {
      expect(Settings.defaultSettings.groupRelatedPosts, isFalse);
      for (final value in [null, false, 'true', 1, [], {}]) {
        final json = Settings.defaultSettings.toJson()
          ..remove('groupRelatedPosts');
        if (value != null) json['groupRelatedPosts'] = value;
        expect(Settings.fromJson(json).groupRelatedPosts, isFalse);
      }
    },
  );

  test('global Related preference survives repository reopening and Settings backup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'related-grouping-',
    );
    Hive.init(directory.path);
    var box = await Hive.openBox<String>('related-grouping');
    try {
      var repository = SettingsRepositoryHive(Future.value(box));
      final enabled = Settings.defaultSettings.copyWith(
        groupRelatedPosts: true,
      );
      expect(await repository.save(enabled), isTrue);
      await box.close();
      box = await Hive.openBox<String>('related-grouping');
      repository = SettingsRepositoryHive(Future.value(box));
      final loaded = (await repository.load().run()).getOrElse(
        (error) => throw StateError('$error'),
      );
      final backup = Settings.fromJson(
        jsonDecode(jsonEncode(loaded.toJson())) as Map<String, dynamic>,
      );
      expect(backup, enabled);
      expect(
        backup.copyWith(showBookmarkCount: true).groupRelatedPosts,
        isTrue,
      );
      final disabled = backup.copyWith(groupRelatedPosts: false);
      expect(disabled, isNot(backup));
      expect(await repository.save(disabled), isTrue);
      expect(
        (await repository.load().run())
            .getOrElse(
              (error) => throw StateError('$error'),
            )
            .groupRelatedPosts,
        isFalse,
      );
    } finally {
      if (box.isOpen) await box.close();
      await directory.delete(recursive: true);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Appearance edits global Related even with custom listing, scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = FollowingTopicHarness(
          overrides: [
            hasPremiumProvider.overrideWithValue(false),
            showPremiumFeatsProvider.overrideWithValue(false),
            dynamicColorSupportProvider.overrideWithValue(false),
            hasCustomListingSettingsProvider.overrideWithValue(true),
          ],
        );
        addTearDown(harness.dispose);
        await harness.pump(
          tester,
          CurrentBooruConfigScope(
            config: testProfile,
            child: const AppearancePage(),
          ),
        );
        final control = find.byType(RelatedPostsGroupingSetting);
        await tester.scrollUntilVisible(
          control,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final toggle = find.descendant(
          of: control,
          matching: find.byType(KurumiSwitchListTile),
        );
        expect(tester.widget<KurumiSwitchListTile>(toggle).value, isFalse);
        await tester.tap(toggle);
        await drain(tester);
        expect(
          harness.container.read(settingsProvider).groupRelatedPosts,
          isTrue,
        );
        expect(
          jsonDecode(
            harness.settingsBox.get('settings') as String,
          )['groupRelatedPosts'],
          isTrue,
        );
        await tester.tap(toggle);
        await drain(tester);
        expect(
          harness.container.read(settingsProvider).groupRelatedPosts,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
