import 'package:boorusama/core/debug/src/logging/app_logger.dart';
import 'package:boorusama/core/debug/src/pages/debug_logs_page.dart';
import 'package:boorusama/core/debug/src/providers/providers.dart';
import 'package:boorusama/core/debug/src/types/log_data.dart';
import 'package:boorusama/core/debug/src/types/log_options.dart';
import 'package:boorusama/core/settings/providers.dart';
import 'package:boorusama/core/settings/src/types/settings.dart';
import 'package:boorusama/core/themes/colors/providers.dart';
import 'package:boorusama/core/themes/colors/src/utils.dart';
import 'package:boorusama/foundation/loggers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:readmore/readmore.dart';

void main() {
  testWidgets(
    'newest first with stable equal-time arrival and filtered slivers',
    (
      tester,
    ) async {
      final logger = AppLogger();
      final time = DateTime(2026, 11, 8);
      logger.publishEntries([
        for (var i = 0; i < 4; i++)
          LogData(
            dateTime: time,
            serviceName: i.isEven ? 'Media' : 'Sync',
            safeMessage: 'Entry $i',
            level: LogLevel.info,
          ),
      ]);
      final container = await _mount(tester, logger);
      expect(
        tester.getTopLeft(find.text('Entry 3')).dy,
        lessThan(tester.getTopLeft(find.text('Entry 2')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Entry 2')).dy,
        lessThan(tester.getTopLeft(find.text('Entry 1')).dy),
      );
      // File/clipboard reports deliberately keep capture order.
      expect(
        logger.dump().indexOf('Entry 0'),
        lessThan(logger.dump().indexOf('Entry 3')),
      );
      container.read(selectedDebugLogCategoryProvider.notifier).state = 'Media';
      await tester.pumpAndSettle();
      expect(find.text('Entry 3'), findsNothing);
      expect(find.text('Entry 1'), findsNothing);
      expect(find.text('Entry 2'), findsOneWidget);
      final lists = tester.widgetList<SliverList>(
        find.descendant(
          of: find.byKey(const ValueKey('debug-logs-list')),
          matching: find.byType(SliverList),
        ),
      );
      expect(
        lists
            .map((list) => list.delegate.estimatedChildCount)
            .reduce((a, b) => a! + b!),
        2,
      );
      container.read(selectedDebugLogCategoryProvider.notifier).state =
          'Absent';
      await tester.pumpAndSettle();
      expect(find.byType(ReadMoreText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live rows preserve older reading position and top follows latest',
    (
      tester,
    ) async {
      final logger = AppLogger()
        ..applyOptions(const LogOptions(redactSensitiveDetails: true));
      for (var i = 0; i < 80; i++) {
        logger.info('Media', 'Entry $i', sensitiveMessage: 'PRIVATE $i');
      }
      await _mount(tester, logger);
      final view = find.byType(CustomScrollView);
      final controller = tester.widget<CustomScrollView>(view).controller!;
      controller.jumpTo(500);
      await tester.pumpAndSettle();
      final visible =
          find.byType(ReadMoreText).evaluate().first.widget as ReadMoreText;
      final oldEntry = find.text(visible.data);
      final before = tester.getTopLeft(oldEntry).dy;
      logger.info('Media', 'Newest', sensitiveMessage: 'PRIVATE new');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(oldEntry).dy, closeTo(before, .01));
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(controller.position.minScrollExtent, lessThan(0));
      controller.jumpTo(controller.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Newest'), findsOneWidget);
      logger.info('Media', 'Latest');
      await tester.pumpAndSettle();
      expect(find.text('Latest'), findsOneWidget);
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded older rows survive arrivals and top action reaches latest',
    (tester) async {
      final logger = AppLogger();
      final message = List.generate(1000, (index) => 'Detail$index').join(' ');
      logger.info('Media', message);
      logger.info('Sync', 'Latest before expansion');
      await _mount(tester, logger);
      final old = find.byWidgetPredicate(
        (widget) => widget is ReadMoreText && widget.data == message,
      );
      final row = tester.widget<ReadMoreText>(old);
      final compact = tester.getSize(old).height;
      await tester.tapOnText(
        find.textRange.ofSubstring(row.trimCollapsedText, descendentOf: old),
      );
      await tester.pumpAndSettle();
      final expanded = tester.getSize(old).height;
      expect(expanded, greaterThan(compact));
      final view = find.byType(CustomScrollView);
      final controller = tester.widget<CustomScrollView>(view).controller!;
      controller.jumpTo(150);
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(old).dy;
      logger.info('Sync', 'Latest after expansion');
      await tester.pumpAndSettle();
      expect(tester.getSize(old).height, expanded);
      expect(tester.getTopLeft(old).dy, closeTo(before, .01));
      logger.applyOptions(const LogOptions(redactSensitiveDetails: true));
      await tester.pumpAndSettle();
      expect(tester.getSize(old).height, expanded);
      await tester.drag(view, const Offset(0, 40));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(KurumiScrollToTopButton).hitTestable());
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        closeTo(controller.position.minScrollExtent, .01),
      );
      expect(find.text('Latest after expansion'), findsOneWidget);
      logger.clearLogsAtOrBelow(LogLevel.error);
      await tester.pumpAndSettle();
      expect(find.byType(ReadMoreText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('redaction preserves the captured entry identity', () {
    final logger = AppLogger()
      ..info('Media', 'safe', sensitiveMessage: 'secret');
    final identity = logger.logs.single.identity;
    expect(identity, isNot(isA<LogData>()));
    logger.applyOptions(const LogOptions(redactSensitiveDetails: true));
    expect(logger.logs.single.identity, same(identity));
    expect(logger.logs.single.message, 'safe');
    final captured = logger.captureEntry('Media', 'duplicate observation')!;
    logger.publishEntries([captured, captured]);
    expect(
      logger.logs[1].identity,
      isNot(same(logger.logs[2].identity)),
      reason: 'Two publications remain distinct rows even with equal content',
    );
  });
}

Future<ProviderContainer> _mount(WidgetTester tester, AppLogger logger) async {
  final container = ProviderContainer(
    overrides: [
      appLoggerProvider.overrideWithValue(logger),
      redactSensitiveLogsProvider.overrideWithValue(true),
      settingsProvider.overrideWithValue(Settings.defaultSettings),
      booruChipColorsProvider.overrideWithValue(
        BooruChipColors.colorScheme(const ColorScheme.light()),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    logger.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: BooruLocalization(
        child: MaterialApp(
          theme: ThemeData(extensions: const [KurumiExtendedColorScheme()]),
          builder: (context, child) => KurumiTheme(
            data: KurumiThemeData.fromMaterial(Theme.of(context)),
            child: child!,
          ),
          home: const DebugLogsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
