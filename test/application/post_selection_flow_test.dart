// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:selection_mode/selection_mode.dart';

// Project imports:
import 'package:boorusama/core/widgets/widgets.dart';

import '../support/boorusama_test_runtime.dart';
import 'support/app_flow_driver.dart';
import 'support/app_flow_finders.dart';
import 'support/fake_booru_backend.dart';
import 'support/headless_app_harness.dart';

void main() {
  testWidgets(
    'replacing the clicked row closes its menu and preserves committed identities',
    (tester) async {
      final harness = await HeadlessAppHarness.mount(tester);
      final driver = AppFlowDriver(tester: tester, harness: harness);
      await harness.pumpUntilFound(tester, postTile(102));
      await tester.longPress(postTile(101));
      await harness.settle(tester);
      await driver.openPostMenu(101, via: PostMenuOpener.rightClick);
      final controller = postController(tester);
      final selection = SelectionMode.of(tester.element(postTile(101)));
      controller.moveAndInsert(fromIndex: 0, toIndex: 1);
      await harness.settle(tester);
      expect(find.byType(KurumiContextMenuTile), findsNothing);
      expect(
        selection.selectedFrom(controller.items.toList()).toList().single.id,
        101,
      );
      expect(selection.isActive, isTrue);
    },
  );

  for (final via in PostMenuOpener.values) {
    testWidgets(
      'selects posts from the grid menu by ${via.label} and downloads them together',
      (tester) async {
        final backend = FakeBooruBackend();
        final service = MemoryDownloadService();
        final harness = HeadlessAppHarness(
          booruBackend: backend,
          runtime: backend.createRuntime(downloadService: service),
        );
        final driver = AppFlowDriver(tester: tester, harness: harness);

        try {
          await harness.pump(tester);
          await harness.pumpUntilFound(tester, postTile(102));
          await harness.settle(tester);
          final strings = appStrings(tester);

          await driver.openPostMenu(101, via: via);
          await driver.choosePostMenuAction(strings.generic.action.select);
          await tester.tap(postTile(102));
          await tester.pump();

          await tester.tap(
            find.widgetWithText(MultiSelectButton, strings.download.download),
          );
          await harness.pumpUntil(
            tester,
            () => service.requests.length == 2,
            description: 'both selected posts to download',
          );

          expect(
            service.requests.map((request) => request.url),
            unorderedEquals([
              'https://headless.booru.test/posts/101.jpg',
              'https://headless.booru.test/posts/102.jpg',
            ]),
          );
          expect(find.byType(MultiSelectionActionBar), findsOneWidget);
          if (via == PostMenuOpener.rightClick) {
            final controller = postController(tester);
            final before = controller.items.toList();
            final selection = SelectionMode.of(tester.element(postTile(101)));
            final gate = backend.enqueuePostGate(
              siteUrl: backend.config.url,
              query: '',
              page: 1,
            );
            final refresh = controller.refresh(preserveSelection: true);
            await tester.pump();
            expect(
              find.widgetWithText(MultiSelectButton, strings.download.download),
              findsNothing,
            );
            gate.completeSuccess(testPostResult(before.reversed.toList()));
            await refresh;
            await harness.settle(tester);
            expect(selection.isActive, isTrue);
            expect(
              selection
                  .selectedFrom(controller.items.toList())
                  .toList()
                  .map((post) => post.id),
              unorderedEquals([101, 102]),
            );
          }
        } finally {
          await harness.teardown(tester);
        }
      },
    );
  }
}
