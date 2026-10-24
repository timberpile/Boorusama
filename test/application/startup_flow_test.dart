import 'package:flutter/widgets.dart';
// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import 'package:boorusama/core/navigation/app_navigation_shell.dart';
import 'package:boorusama/core/settings/src/pages/settings_page.dart';

import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'starts from the test runtime and navigates between primary screens',
    (tester) async {
      final harness = HeadlessAppHarness();
      addTearDown(() => harness.teardown(tester));

      await harness.pump(tester);
      await harness.settle(tester);

      expect(find.byType(AppNavigationShell), findsOneWidget);

      final settingsIcon = find.byIcon(Symbols.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.last);
      } else {
        await tester.tap(find.byKey(const Key('nav-menu-toggle')).first);
        await tester.pump();
        await harness.settle(tester);
        await tester.tap(find.text('Settings').last);
      }
      await tester.pump();
      await harness.settle(tester);

      expect(find.byType(SettingsPage), findsOneWidget);

      final closeSettings = find.byTooltip('Close');
      if (closeSettings.evaluate().isNotEmpty) {
        await tester.tap(closeSettings.last);
      } else {
        await tester.tap(find.byTooltip('Back').last);
      }
      await tester.pump();
      await harness.settle(tester);

      expect(find.byType(AppNavigationShell), findsOneWidget);
    },
  );
}
