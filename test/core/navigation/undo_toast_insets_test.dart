import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_overlay_insets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:oktoast/oktoast.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Undo follows live chrome without changing its action at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        tester.view.padding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        addTearDown(dismissAllToast);
        var undone = 0;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => OKToast(child: child!),
              home: Builder(
                builder: (context) {
                  final system = MediaQuery.of(context);
                  return NavigationOverlayInsetsScope(
                    systemMediaQuery: system,
                    extent: 88,
                    child: MediaQuery(
                      // Destination lists deliberately retain their stable padding.
                      data: system.copyWith(
                        padding: const EdgeInsets.only(bottom: 88),
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Scaffold(
                        body: Builder(
                          builder: (context) => TextButton(
                            onPressed: () => Kurumi.showSuccessToast(
                              context,
                              'Removed from group',
                              duration: Duration.zero,
                              actionLabel: 'Undo',
                              onAction: () => undone++,
                            ),
                            child: const Text('Remove'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pumpAndSettle();
        final toast = find.byKey(const ValueKey('kurumi-action-toast'));
        expect(tester.getRect(toast).bottom, closeTo(640 - 88 - 16, 0.5));
        final chrome = container.read(navigationChromeProvider.notifier);
        chrome.userScroll(
          delta: 88,
          pixels: 100,
          outOfRange: false,
          extent: 88,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(toast).bottom, closeTo(640 - 24 - 16, 0.5));
        chrome.show();
        await tester.pumpAndSettle();
        expect(tester.getRect(toast).bottom, closeTo(640 - 88 - 16, 0.5));
        chrome.userScroll(
          delta: 44,
          pixels: 100,
          outOfRange: false,
          extent: 88,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(toast).bottom, closeTo(640 - 44 - 16, 0.5));

        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        tester.view.padding = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(tester.getRect(toast).bottom, closeTo(640 - 240 - 16, 0.5));
        final action = find.widgetWithText(TextButton, 'Undo');
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(undone, 1);
        expect(toast, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
