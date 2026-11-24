import 'dart:convert';

import 'package:boorusama/core/bookmarks/server_favorites.dart';
import 'package:boorusama/core/cache/misc_data_store.dart';
import 'package:boorusama/core/configs/manage/widgets.dart';
import 'package:boorusama/core/premiums/providers.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/pages/appearance/appearance_page.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../bookmarks/server_favorites/test_support.dart';
import '../search/following_topics/following_topic_test_utils.dart';

void main() {
  testWidgets(
    'Appearance reads and writes the inverse synced-group preference',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = FavoriteTestStore();
      final harness = FollowingTopicHarness(
        overrides: [
          miscDataStoreProvider.overrideWithValue(store),
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
      final label = find.text('Count Synced Groups as Bookmarks');
      final toggle = find.ancestor(
        of: label,
        matching: find.byType(KurumiSwitchListTile),
      );
      await tester.scrollUntilVisible(
        label,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<KurumiSwitchListTile>(toggle).value, isFalse);
      expect(store.writes, 0);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(tester.widget<KurumiSwitchListTile>(toggle).value, isTrue);
      expect(
        jsonDecode(
          store.values[serverFavoriteSettingsStorageKey]!,
        )['ignoreBookmarkStatus'],
        isFalse,
      );
      harness.container.invalidate(serverFavoriteSettingsProvider);
      await tester.pumpAndSettle();
      expect(tester.widget<KurumiSwitchListTile>(toggle).value, isTrue);
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(tester.widget<KurumiSwitchListTile>(toggle).value, isFalse);
      expect(
        jsonDecode(
          store.values[serverFavoriteSettingsStorageKey]!,
        )['ignoreBookmarkStatus'],
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
