import 'package:boorusama/core/backups/mitemite/relative_date.dart';
import 'package:boorusama/core/widgets/time_pulse.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:intl/intl.dart';
import 'package:kurumi/material.dart';

void main() {
  Widget app(DateTime? date) => BooruLocalization(
    child: MaterialApp(
      home: Scaffold(body: MiteMiteRelativeDate(date: date)),
    ),
  );

  testWidgets('relative age refreshes without replacing the timestamp', (
    tester,
  ) async {
    await tester.runAsync(() => ensureI18nInitialized('en-US'));
    var now = DateTime.utc(2026, 11, 15, 12);
    final timestamp = now.subtract(const Duration(minutes: 2));
    await withClock(Clock(() => now), () async {
      await tester.pumpWidget(app(timestamp));
      expect(find.text('2 minutes ago'), findsOneWidget);
      await tester.longPress(find.text('2 minutes ago'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toLocal()),
        ),
        findsOneWidget,
      );
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('4 minutes ago'), findsOneWidget);
      expect(find.text(timestamp.toString()), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('missing dates show Never and a later attempt replaces it', (
    tester,
  ) async {
    await tester.pumpWidget(app(null));
    expect(find.text('Never'), findsOneWidget);
    expect(find.byType(TimePulse), findsNothing);
    final now = DateTime.utc(2026, 11, 15, 12);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(app(now));
      expect(find.text('Never'), findsNothing);
      expect(find.text('a moment ago'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('offset timestamps preserve the instant and future direction', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 15, 12);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(app(DateTime.parse('2026-11-15T14:05:00+02:00')));
      expect(find.text('5 minutes from now'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('relative dates use the selected locale', (tester) async {
    addTearDown(() => ensureI18nInitialized('en-US'));
    await tester.runAsync(() => ensureI18nInitialized('de-DE'));
    final now = DateTime.utc(2026, 11, 15, 12);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(app(now.subtract(const Duration(minutes: 1))));
      expect(find.text('vor einer Minute'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
