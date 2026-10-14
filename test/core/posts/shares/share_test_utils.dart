import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Call from tester.runAsync so native I/O can progress between pumps.
Future<void> pumpUntilShareCondition(
  WidgetTester tester,
  bool Function() completed, {
  required String reason,
}) async {
  // A hang guard, not a performance requirement. Stop as soon as work finishes.
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    await tester.pump();
    if (completed()) return;
    if (DateTime.now().isAfter(deadline)) fail(reason);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

bool shareActionEnabled(WidgetTester tester, String tooltip) =>
    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed !=
    null;
