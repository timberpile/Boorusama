import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  for (final customChild in [false, true]) {
    for (final scrolling in [false, true]) {
      for (final nested in [false, true]) {
        for (final tooltip in [false, true]) {
          testWidgets(
            'popup actions remain accessible with customChild=$customChild scrolling=$scrolling nested=$nested tooltip=$tooltip',
            (tester) async {
              final semantics = tester.ensureSemantics();
              try {
                var selected = false;
                final button = KurumiPopupMenuButton(
                  semanticLabel: 'More',
                  items: [
                    KurumiPopupMenuItem(
                      title: const Text('Edit'),
                      onTap: () => selected = true,
                    ),
                  ],
                  child: customChild
                      ? const SizedBox.square(
                          dimension: 48,
                          child: Icon(Icons.more_vert),
                        )
                      : null,
                );
                final opener = tooltip
                    ? Tooltip(message: 'More', child: button)
                    : button;
                final page = Scaffold(
                  body: scrolling
                      ? ListView(
                          children: [
                            Align(alignment: Alignment.topRight, child: opener),
                          ],
                        )
                      : Align(alignment: Alignment.topRight, child: opener),
                );
                await tester.pumpWidget(
                  MaterialApp(
                    home: nested
                        ? Navigator(
                            onGenerateRoute: (_) =>
                                MaterialPageRoute<void>(builder: (_) => page),
                          )
                        : page,
                  ),
                );
                if (customChild && tooltip) {
                  final opener = find.semantics
                      .byLabel('More')
                      .evaluate()
                      .single;
                  expect(
                    opener.getSemanticsData().hasAction(SemanticsAction.tap),
                    isTrue,
                  );
                  opener.owner!.performAction(opener.id, SemanticsAction.tap);
                } else {
                  await tester.tap(find.byType(KurumiPopupMenuButton));
                }
                await tester.pumpAndSettle();
                expect(find.text('Edit'), findsOneWidget);
                expect(
                  tester.semantics.simulatedAccessibilityTraversal(),
                  contains(isSemantics(label: 'Edit', hasTapAction: true)),
                );
                final edit = find.semantics.byLabel('Edit').evaluate().single;
                edit.owner!.performAction(edit.id, SemanticsAction.tap);
                await tester.pumpAndSettle();
                expect(selected, true);
                expect(find.text('Edit'), findsNothing);
              } finally {
                await tester.pumpWidget(const SizedBox.shrink());
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
  testWidgets(
    'disabled custom opener keeps its label without semantic actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Tooltip(
                message: 'More',
                child: KurumiPopupMenuButton(
                  enabled: false,
                  semanticLabel: 'More',
                  items: [
                    KurumiPopupMenuItem(
                      title: const Text('Edit'),
                      onTap: () {},
                    ),
                  ],
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Text('Decoration'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final opener = find.semantics.byLabel('More').evaluate().single;
        expect(
          opener.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(find.semantics.byLabel('Decoration').evaluate(), isEmpty);
        opener.owner!.performAction(opener.id, SemanticsAction.tap);
        await tester.tap(find.byType(KurumiPopupMenuButton));
        await tester.pumpAndSettle();
        expect(find.text('Edit'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      }
    },
  );
}
