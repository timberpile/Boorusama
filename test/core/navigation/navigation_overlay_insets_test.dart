import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

import 'package:boorusama/core/navigation/navigation_chrome_controller.dart';
import 'package:boorusama/core/navigation/navigation_overlay_insets.dart';

void main() {
  testWidgets('tracks visible overlap without moving page padding', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    late MediaQueryData page;
    late MediaQueryData overlay;
    await tester.pumpWidget(
      _app(
        container,
        onPage: (data) => page = data,
        onOverlay: (data) => overlay = data,
      ),
    );
    expect(page.padding.bottom, 88);
    expect(overlay.padding.bottom, 88);

    final chrome = container.read(navigationChromeProvider.notifier);
    chrome.userScroll(delta: 44, pixels: 300, outOfRange: false, extent: 88);
    await tester.pumpAndSettle();
    expect(overlay.padding.bottom, 44);
    expect(page.padding.bottom, 88);

    chrome.userScroll(delta: 44, pixels: 344, outOfRange: false, extent: 88);
    await tester.pumpAndSettle();
    expect(overlay.padding.bottom, 24);
    expect(overlay.viewPadding.bottom, 24);
    expect(page.padding.bottom, 88);

    chrome.show();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(overlay.padding.bottom, greaterThan(24));
    expect(overlay.padding.bottom, lessThan(88));
    expect(page.padding.bottom, 88);
    await tester.pumpAndSettle();
    expect(overlay.padding.bottom, 88);
  });

  testWidgets(
    'keeps system view padding and keyboard insets when chrome is covered',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      late MediaQueryData overlay;
      await tester.pumpWidget(
        _app(
          container,
          keyboard: true,
          onPage: (_) {},
          onOverlay: (data) => overlay = data,
        ),
      );
      await tester.pumpAndSettle();
      expect(overlay.padding.bottom, 0);
      expect(overlay.viewPadding.bottom, 24);
      expect(overlay.viewInsets.bottom, 280);
    },
  );
}

Widget _app(
  ProviderContainer container, {
  required ValueChanged<MediaQueryData> onPage,
  required ValueChanged<MediaQueryData> onOverlay,
  bool keyboard = false,
}) {
  final system = MediaQueryData(
    size: const Size(320, 640),
    padding: EdgeInsets.only(bottom: keyboard ? 0 : 24),
    viewPadding: const EdgeInsets.only(bottom: 24),
    viewInsets: EdgeInsets.only(bottom: keyboard ? 280 : 0),
  );
  return UncontrolledProviderScope(
    container: container,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: system,
        child: NavigationOverlayInsetsScope(
          systemMediaQuery: system,
          extent: 88,
          child: MediaQuery(
            data: system.copyWith(padding: const EdgeInsets.only(bottom: 88)),
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    onPage(MediaQuery.of(context));
                    return const SizedBox();
                  },
                ),
                KurumiOverlayMediaQuery(
                  builder: (context) {
                    onOverlay(MediaQuery.of(context));
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
