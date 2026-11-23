import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/material.dart';
import 'package:boorusama/core/settings/src/pages/appearance/posts_per_page_dialog.dart';

import 'support/headless_app_harness.dart';

void main() {
  testWidgets('production Posts Per Page at 320dp 2x with keyboard', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = HeadlessAppHarness(viewportSize: const Size(320, 640));
    addTearDown(() => h.teardown(tester));
    await h.pump(tester);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showPostsPerPageDialog(context, currentValue: 60),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await h.settle(tester);
    await tester.tap(find.text('Open'));
    await h.settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await h.settle(tester);
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    await tester.ensureVisible(cancel);
    final box = tester.getRect(cancel);
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(320));
    expect(box.bottom, lessThanOrEqualTo(400));
    expect(cancel.hitTestable(), findsOneWidget);
    await tester.tap(cancel);
    await h.settle(tester);
    expect(find.byType(PostsPerPageDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
