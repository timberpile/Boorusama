import 'package:flutter/widgets.dart';
// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../support/boorusama_test_runtime.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'persists a settings change made through the real settings UI',
    (tester) async {
      final harness = HeadlessAppHarness();
      addTearDown(() => harness.teardown(tester));

      await harness.pump(tester);
      await harness.settle(tester);

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

      expect(find.text('Server favorites'), findsNothing);
      expect(find.text('Favorites Sync'), findsNothing);
      final accessibility = find.text('Accessibility');
      await tester.ensureVisible(accessibility);
      await tester.tap(accessibility);
      await tester.pump();
      await harness.settle(tester);

      final reduceAnimations = find.text('Reduce Animations');
      await tester.ensureVisible(reduceAnimations);
      await tester.tap(reduceAnimations);
      await tester.pump();
      await harness.settle(tester);

      final settingsRepository =
          harness.runtime.dependencies.settingsRepository
              as MemorySettingsRepository;
      expect(settingsRepository.savedSettings, isNotEmpty);
      expect(settingsRepository.savedSettings.last.reduceAnimations, isTrue);
    },
  );
}
