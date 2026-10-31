import 'package:boorusama/core/posts/shares/src/share_payloads.dart';
import 'package:boorusama/core/posts/shares/src/unified_post_share_sheet.dart';
import 'package:boorusama/core/settings/types.dart';
import 'package:boorusama/core/widgets/multi_selection_action_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';

import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  for (final quality in [PostQuality.high, PostQuality.original]) {
    testWidgets(
      'unvisited Selection Manager shares honor Post Quality $quality',
      (tester) async {
        final backend = FakeBooruBackend();
        const defaults = Settings.defaultSettings;
        final harness = await HeadlessAppHarness.mount(
          tester,
          booruBackend: backend,
          phone: TestPhone.portrait,
          runtime: backend.createRuntime(
            settings: defaults.copyWith(
              viewer: defaults.viewer.copyWith(postQuality: quality),
            ),
          ),
        );
        await harness.pumpUntilFound(tester, postTile(101));
        await tester.longPress(postTile(101));
        await harness.settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(MultiSelectionActionBar),
            matching: find.byIcon(Icons.more_horiz),
          ),
        );
        await harness.pumpUntilFound(tester, find.text('Share'));
        await tester.tap(find.text('Share'));
        await harness.pumpUntilFound(
          tester,
          find.byType(UnifiedPostShareSheet),
        );
        await harness.settle(tester);
        expect(
          find.byKey(const ValueKey(SharePayloadId.image)),
          quality == PostQuality.original ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey(SharePayloadId.original)),
          findsOneWidget,
        );
        await tester.tap(find.text('Links'));
        await harness.settle(tester);
        expect(find.byKey(const ValueKey('share-bslink-file')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
