// Flutter imports:
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Package imports:
import 'package:kurumi/material.dart';

// Project imports:
import 'package:boorusama/core/posts/details_pageview/src/post_details_shortcuts.dart';
import 'package:boorusama/core/posts/details_pageview/widgets.dart';

void main() {
  for (final largeScreen in [false, true]) {
    testWidgets(
      'arrows page horizontally and preserve up/down controls, large=$largeScreen',
      (tester) async {
        final controller = PostDetailsPageViewController(
          initialPage: 0,
          totalPage: 2,
          checkIfLargeScreen: () => largeScreen,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PostDetailsShortcuts(
                controller: controller,
                isLargeScreen: largeScreen,
                child: PageView(
                  controller: controller.pageController,
                  onPageChanged: (page) => controller.currentPage.value = page,
                  children: const [Text('First'), Text('Second')],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(controller.page, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(controller.page, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(controller.page, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(controller.page, 0);
      },
    );
  }

  testWidgets(
    'down from the page lands on the lowest control in view, not one '
    'scrolled far down a side panel',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = PostDetailsPageViewController(
        initialPage: 0,
        totalPage: 1,
        checkIfLargeScreen: () => true,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostDetailsShortcuts(
              controller: controller,
              isLargeScreen: true,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Pause'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Tag'),
                          ),
                          const SizedBox(height: 1500),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Customize'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(
        Focus.of(tester.element(find.text('Pause'))).hasPrimaryFocus,
        isTrue,
      );
    },
  );
}
