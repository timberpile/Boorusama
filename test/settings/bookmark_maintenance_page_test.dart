import 'dart:async';

import 'package:boorusama/core/bookmarks/src/providers/bookmark_hydration_provider.dart';
import 'package:boorusama/core/bookmarks/src/providers/bookmark_provider.dart';
import 'package:boorusama/core/bookmarks/src/services/bookmark_hydration_service.dart';
import 'package:boorusama/core/bookmarks/src/types/bookmark_hydration_log.dart';
import 'package:boorusama/core/bookmarks/types.dart';
import 'package:boorusama/core/settings/src/pages/bookmark_maintenance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _HydrationNotifier hydration, {
    bool empty = false,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarkProvider.overrideWith(() => _LibraryNotifier(empty)),
          bookmarkHydrationProvider.overrideWith(() => hydration),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => KurumiTheme(
              data: KurumiThemeData.fromMaterial(Theme.of(context)),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
            home: const BookmarkMaintenancePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty library shows zero candidates and disables network action',
    (tester) async {
      final hydration = _HydrationNotifier();
      await pumpPage(tester, hydration, empty: true);
      await tester.scrollUntilVisible(
        find.text('Incomplete bookmarks: 0'),
        200,
      );
      expect(find.text('Incomplete bookmarks: 0'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(hydration.started, 0);
      await tester.scrollUntilVisible(find.text('Copy log'), 200);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Copy log'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('No posts processed yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bounded log shows outcomes and copies the displayed entries at large text',
    (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final entries = List.generate(
        105,
        (index) => BookmarkHydrationLogEntry(
          timestamp: DateTime.utc(2026, 10, 7, 12),
          domain: 'very-long-domain-for-hydration.example',
          bookmarkId: index + 500,
          postId: index + 1,
          reason: switch (index) {
            103 => BookmarkHydrationLogReason.requestFailed,
            102 => BookmarkHydrationLogReason.missingProfile,
            101 => BookmarkHydrationLogReason.rateLimited,
            100 => BookmarkHydrationLogReason.requestFailed,
            _ => BookmarkHydrationLogReason.updated,
          },
          httpStatusCode: index == 103 ? 403 : null,
          retryAt: index == 101 ? DateTime.utc(2026, 10, 7, 12, 1) : null,
          failureKind: index == 100
              ? BookmarkHydrationFailureKind.invalidResponse
              : null,
          errorDetail: index == 100
              ? 'FormatException: Rule34 API post has no file URL'
              : null,
        ),
      );
      final hydration = _HydrationNotifier(
        initial: BookmarkHydrationProgress(
          total: 105,
          running: true,
          logEntries: entries,
        ),
      );
      await pumpPage(tester, hydration);
      await tester.scrollUntilVisible(find.text('Copy log'), 200);
      await tester.ensureVisible(find.text('Copy log'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Latest 100 entries'), findsOneWidget);
      expect(
        find.textContaining('very-long-domain-for-hydration.example'),
        findsNWidgets(100),
      );
      expect(find.textContaining('Post #5\n'), findsNothing);
      expect(find.textContaining('Post #6\n'), findsOneWidget);
      expect(
        find.textContaining('Failed — could not fetch post (HTTP 403)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Skipped — no matching profile'),
        findsOneWidget,
      );
      await tester.tap(find.text('Copy log'));
      await tester.pumpAndSettle();
      expect(copied!.split('\n\n'), hasLength(100));
      expect(copied!.split('\n\n').first, contains('Post #105\nUpdated'));
      expect(copied!.split('\n\n').last, contains('Post #6\nUpdated'));
      expect(copied, contains('HTTP 403'));
      expect(copied, contains('Skipped — no matching profile'));
      expect(
        copied,
        contains(
          'Failed — invalid post response — FormatException: Rule34 API post has no file URL',
        ),
      );
      expect(
        copied,
        contains('Waiting — rate limited; retry at 2026-10-07T12:01:00.000Z'),
      );
      expect(find.text('Log copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'automatic failed-post retries explain waits and passes and remain cancellable',
    (tester) async {
      final hydration = _HydrationNotifier(
        initial: BookmarkHydrationProgress(
          total: 2,
          updated: 1,
          failed: 1,
          running: true,
          retryAt: DateTime.utc(2026, 10, 7, 12, 1),
        ),
      );
      await pumpPage(tester, hydration);
      await tester.scrollUntilVisible(
        find.textContaining('Automatically retrying 1 failed posts at'),
        200,
      );
      expect(
        find.textContaining('You can cancel while waiting.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      hydration.publish(
        const BookmarkHydrationProgress(
          total: 2,
          updated: 1,
          failed: 1,
          running: true,
          retryPass: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Retrying 1 remaining failed posts (retry pass 1).'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(hydration.cancelled, isTrue);
      expect(find.textContaining('Automatically retrying'), findsNothing);
      expect(find.textContaining('remaining failed posts'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'confirmation and progress fit narrow screens with enlarged text and cancellation keeps the summary',
    (tester) async {
      final hydration = _HydrationNotifier();
      await pumpPage(tester, hydration);
      final button = find.byType(FilledButton);
      await tester.scrollUntilVisible(button, 200);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Update 1 incomplete bookmarks?'),
        findsOneWidget,
      );
      expect(hydration.started, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(hydration.started, 1);
      expect(find.text('Processed 0 / 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(hydration.cancelled, isTrue);
      expect(
        find.text('Cancelled. Completed updates have been kept.'),
        findsOneWidget,
      );
      expect(find.text('Updated 0 · Skipped 0 · Failed 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'log updates during a run and identifies bookmarks without a post ID',
    (tester) async {
      final hydration = _HydrationNotifier(
        initial: const BookmarkHydrationProgress(total: 1, running: true),
      );
      await pumpPage(tester, hydration);
      await tester.scrollUntilVisible(
        find.text('No posts processed yet.'),
        200,
      );
      hydration.publish(
        BookmarkHydrationProgress(
          total: 1,
          skipped: 1,
          logEntries: [
            BookmarkHydrationLogEntry(
              timestamp: DateTime.utc(2026, 10, 7),
              domain: '',
              bookmarkId: 123,
              postId: null,
              reason: BookmarkHydrationLogReason.missingPostId,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Unknown domain · Bookmark #123 (no post ID)'),
        findsOneWidget,
      );
      expect(find.textContaining('Skipped — missing post ID'), findsOneWidget);
      expect(find.text('No posts processed yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'site cooldown shows automatic continuation without terminal failures',
    (tester) async {
      final hydration = _HydrationNotifier(
        initial: const BookmarkHydrationProgress(
          total: 3,
          running: true,
          rateLimitedSites: {'rule34.xxx'},
        ),
      );
      await pumpPage(tester, hydration);
      await tester.scrollUntilVisible(
        find.textContaining('Waiting for the rate limit on: rule34.xxx.'),
        200,
      );
      await tester.ensureVisible(
        find.textContaining('Waiting for the rate limit on: rule34.xxx.'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Hydration will resume automatically.',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Updated 0 · Skipped 0 · Failed 0'),
        200,
      );
      expect(find.text('Updated 0 · Skipped 0 · Failed 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dismissing confirmation never starts hydration', (tester) async {
    final hydration = _HydrationNotifier();
    await pumpPage(tester, hydration);
    await tester.scrollUntilVisible(find.byType(FilledButton), 200);
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(hydration.started, 0);
  });
}

class _LibraryNotifier extends BookmarkLibraryNotifier {
  _LibraryNotifier(this.empty);
  final bool empty;
  @override
  FutureOr<BookmarkLibraryState> build() => BookmarkLibraryState(
    bookmarks: empty ? [] : [Bookmark.empty],
    groups: const [],
    activeTarget: const BookmarkTarget.ungrouped(),
  );
}

class _HydrationNotifier extends BookmarkHydrationNotifier {
  _HydrationNotifier({this.initial = const BookmarkHydrationProgress()});
  final BookmarkHydrationProgress initial;
  @override
  BookmarkHydrationProgress build() => initial;

  void publish(BookmarkHydrationProgress progress) => state = progress;

  var started = 0;
  var cancelled = false;
  @override
  Future<void> start() async {
    started++;
    state = const BookmarkHydrationProgress(total: 1, running: true);
  }

  @override
  void cancel() {
    cancelled = true;
    state = const BookmarkHydrationProgress(total: 1, cancelled: true);
  }
}
