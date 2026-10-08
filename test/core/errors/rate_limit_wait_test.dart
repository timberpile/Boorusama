import 'package:boorusama/core/errors/types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;

void main() {
  testWidgets(
    'cooldown feedback shows rounded remaining seconds and singular copy',
    (tester) async {
      final start = DateTime.utc(2026, 10, 6);
      var now = start;
      Future<void> pump() => tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Text(
                rateLimitWaitText(
                  context,
                  start.add(const Duration(milliseconds: 2500)),
                  now: now,
                ),
              ),
            ),
          ),
        ),
      );
      await pump();
      expect(
        find.text('Rate limited by the site. Try again in 3 seconds.'),
        findsOneWidget,
      );
      now = start.add(const Duration(seconds: 2));
      await pump();
      expect(
        find.text('Rate limited by the site. Try again in one second.'),
        findsOneWidget,
      );
    },
  );
}
