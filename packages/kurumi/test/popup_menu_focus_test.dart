import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('styled trigger keeps menu semantics and keyboard focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final focus = FocusNode();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KurumiPopupMenuButton(
                semanticLabel: 'Order',
                buttonBuilder: (context, onPressed) => TextButton(
                  focusNode: focus,
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Oldest'),
                ),
                items: [
                  KurumiPopupMenuItem(
                    title: const Text('Newest'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Newest'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Newest'), findsNothing);
      expect(focus.hasPrimaryFocus, isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      semantics.dispose();
    }
  });

  for (final custom in [false, true]) {
    testWidgets(
      'trigger tooltip preserves rooted popup semantics (custom=$custom)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(640, 1200);
        tester.view.devicePixelRatio = 2;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                appBar: KurumiAppBar(
                  title: const Text('Received folder'),
                  actions: [
                    KurumiPopupMenuButton(
                      semanticLabel: 'More',
                      tooltip: 'More',
                      icon: const Icon(Icons.more_vert),
                      child: custom ? const Text('Open') : null,
                      items: [
                        KurumiPopupMenuItem(
                          title: const Text('Action'),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.tap(find.byType(KurumiPopupMenuButton));
          await tester.pumpAndSettle();
          expect(find.byTooltip('More'), findsOneWidget);
          expect(find.semantics.byLabel('Action'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.semantics.byLabel('Action'), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      },
    );
  }

  for (final custom in [false, true]) {
    testWidgets(
      'provided popup focus opens and restores its trigger (custom=$custom)',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: KurumiPopupMenuButton(
                  focusNode: focus,
                  items: [
                    KurumiPopupMenuItem(
                      title: const Text('Action'),
                      onTap: () {},
                    ),
                  ],
                  child: custom ? const Text('Open') : null,
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        expect(focus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Action'), findsNothing);
        expect(focus.hasPrimaryFocus, isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
