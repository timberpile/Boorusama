import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('popup scrolling never reaches the underlying page', (
    tester,
  ) async {
    final controller = AnchorController();
    addTearDown(controller.dispose);
    var pageNotifications = 0;
    var popupNotifications = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              pageNotifications++;
              return false;
            },
            child: ListView(
              children: [
                KurumiAnchor(
                  controller: controller,
                  overlayBuilder: (_) => SizedBox(
                    width: 200,
                    height: 180,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (_) {
                        popupNotifications++;
                        return false;
                      },
                      child: ListView(
                        key: const ValueKey('popup'),
                        children: [
                          for (var i = 0; i < 30; i++)
                            SizedBox(height: 40, child: Text('Item $i')),
                        ],
                      ),
                    ),
                  ),
                  child: TextButton(
                    onPressed: controller.show,
                    child: const Text('Open'),
                  ),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    pageNotifications = 0;
    final popup = find.byKey(const ValueKey('popup'));
    for (final delta in [1000.0, -2000.0, -2000.0, 2000.0]) {
      await tester.drag(popup, Offset(0, delta));
      await tester.pumpAndSettle();
    }
    expect(popupNotifications, greaterThan(0));
    expect(pageNotifications, 0);
    controller.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(pageNotifications, greaterThan(0));
  });

  testWidgets('titled divider aligns its label with the rule at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const SizedBox(
              width: 200,
              child: KurumiContextMenuDivider(title: 'Recent'),
            ),
          ),
        ),
      ),
    );
    final title = tester.getRect(find.text('Recent'));
    final divider = tester.getRect(find.byType(Divider));
    expect(title.left, 12);
    expect(title.right, lessThan(divider.left));
    expect(title.center.dy, divider.center.dy);
    expect(
      tester.widget<Text>(find.text('Recent')).style!.color,
      tester.widget<Divider>(find.byType(Divider)).color,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('titled divider reaches the same right edge as a plain divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: Column(
              children: [
                KurumiContextMenuDivider(key: ValueKey('plain')),
                KurumiContextMenuDivider(
                  key: ValueKey('titled'),
                  title: 'Recent',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Rect line(String key) => tester.getRect(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(line('titled').right, line('plain').right);
    expect(tester.getSize(find.byKey(const ValueKey('plain'))).height, 4);
    final titled = tester.getRect(find.byKey(const ValueKey('titled')));
    final title = tester.getRect(find.text('Recent'));
    expect(title.top - titled.top, 2);
    expect(titled.bottom - title.bottom, 2);
    expect(tester.takeException(), isNull);
  });
}
