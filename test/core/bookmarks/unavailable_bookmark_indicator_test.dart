import 'package:boorusama/core/app_scope.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_unavailable_indicator.dart';
import 'package:boorusama/core/posts/details/src/types/post_presentation_fallback_reason.dart';
import 'package:boorusama/core/themes/theme/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

import '../../application/support/fake_booru_backend.dart';
import '../../application/support/headless_app_harness.dart';

const _missing = PostPresentationFallbackReason.missingProfile;
const _ambiguous = PostPresentationFallbackReason.ambiguousProfile;
const _reader = PostPresentationFallbackReason.unavailableEngine;
const _malformed = PostPresentationFallbackReason.malformedData;
const _temporary = PostPresentationFallbackReason.refreshFailed;

void main() {
  testWidgets('zero counts render no indicator', (tester) async {
    await _pumpFixture(
      tester,
      child: const BookmarkUnavailableIndicator(counts: {}),
    );

    expect(
      find.byKey(const ValueKey('bookmark-unavailable-button')),
      findsNothing,
    );
  });

  testWidgets('groups reasons and exposes the localized total to semantics', (
    tester,
  ) async {
    const counts = {
      _missing: 2,
      _ambiguous: 3,
      _reader: 4,
      _malformed: 1,
      _temporary: 5,
    };
    await _pumpFixture(
      tester,
      child: const BookmarkUnavailableIndicator(counts: counts),
    );

    final semantics = tester.ensureSemantics();
    final button = find.byKey(const ValueKey('bookmark-unavailable-button'));
    expect(tester.getSemantics(button).label, 'Unavailable: 15');
    expect(find.byTooltip('Unavailable: 15'), findsOneWidget);
    semantics.dispose();

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Unavailable bookmarks'), findsOneWidget);
    expect(find.text('A matching profile is required.'), findsOneWidget);
    expect(find.text('Choose an originating account.'), findsOneWidget);
    expect(find.text('No supported public reader.'), findsOneWidget);
    expect(find.text('Access is temporarily unavailable.'), findsOneWidget);
    expect(
      find.text('These bookmarks are still saved and included in exports.'),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsNWidgets(2));
  });

  testWidgets(
    'count refresh updates the button and hides an open popup at zero',
    (
      tester,
    ) async {
      var counts = const {_missing: 2};
      late StateSetter updateCounts;
      await _pumpFixture(
        tester,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateCounts = setState;
            return BookmarkUnavailableIndicator(counts: counts);
          },
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('bookmark-unavailable-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unavailable bookmarks'), findsOneWidget);

      updateCounts(() => counts = const {_missing: 4, _temporary: 1});
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('bookmark-unavailable-button')),
            )
            .label,
        'Unavailable: 5',
      );

      updateCounts(() => counts = const {});
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bookmark-unavailable-button')),
        findsNothing,
      );
      expect(find.text('Unavailable bookmarks'), findsNothing);
    },
  );

  testWidgets('retries only on explicit tap and only for temporary failures', (
    tester,
  ) async {
    var retryCalls = 0;
    var counts = const {_missing: 1, _temporary: 2};
    late StateSetter updateCounts;
    await _pumpFixture(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          updateCounts = setState;
          return BookmarkUnavailableIndicator(
            counts: counts,
            onRetry: () => retryCalls++,
          );
        },
      ),
    );

    await tester.pumpAndSettle();
    expect(retryCalls, 0);
    await tester.tap(find.byKey(const ValueKey('bookmark-unavailable-button')));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(retryCalls, 0);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retryCalls, 1);

    updateCounts(() => counts = const {_missing: 1});
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bookmark-unavailable-button')));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'stays constrained at narrow width, enlarged text and keyboard inset',
    (
      tester,
    ) async {
      await _pumpFixture(
        tester,
        viewport: const Size(320, 640),
        textScale: 2,
        viewInsets: const EdgeInsets.only(bottom: 280),
        child: const BookmarkUnavailableIndicator(
          counts: {
            _missing: 1,
            _ambiguous: 1,
            _reader: 4,
            _temporary: 2,
          },
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('bookmark-unavailable-button')),
      );
      await tester.pumpAndSettle();

      final popup = find.byType(SingleChildScrollView).last;
      final popupSize = tester.getSize(popup);
      expect(popupSize.width, lessThanOrEqualTo(296));
      expect(popupSize.height, lessThanOrEqualTo(0.6 * (640 - 280 - 24)));
      expect(
        find.text('These bookmarks are still saved and included in exports.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps the popup inside a short landscape viewport', (
    tester,
  ) async {
    await _pumpFixture(
      tester,
      viewport: const Size(640, 320),
      child: const BookmarkUnavailableIndicator(
        counts: {_missing: 1, _ambiguous: 1, _reader: 3, _temporary: 1},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('bookmark-unavailable-button')));
    await tester.pumpAndSettle();

    final popup = tester.getSize(find.byType(SingleChildScrollView).last);
    expect(popup.height, lessThanOrEqualTo(0.6 * (320 - 24)));
  });

  testWidgets('Escape and system Back close the Kurumi explanation surface', (
    tester,
  ) async {
    await _pumpFixture(
      tester,
      child: const BookmarkUnavailableIndicator(
        counts: {_missing: 1, _temporary: 1},
        onRetry: _noop,
      ),
    );

    final button = find.byKey(const ValueKey('bookmark-unavailable-button'));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Unavailable bookmarks'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Unavailable bookmarks'), findsNothing);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Unavailable bookmarks'), findsNothing);
  });
}

void _noop() {}

Future<void> _pumpFixture(
  WidgetTester tester, {
  required Widget child,
  Size viewport = const Size(390, 844),
  double textScale = 1,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  final harness = await HeadlessAppHarness.mount(
    tester,
    booruBackend: FakeBooruBackend(),
    viewportSize: viewport,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    BoorusamaAppScope(
      runtime: harness.runtime,
      child: MediaQuery.fromView(
        view: tester.view,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              viewInsets: viewInsets,
            ),
            child: ThemeBuilder(
              useProfileAppearance: false,
              builder: (theme, themeMode) => Builder(
                builder: (context) => MaterialApp(
                  theme: theme,
                  themeMode: themeMode,
                  locale: context.locale,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  builder: (context, child) => KurumiTheme(
                    data: KurumiThemeData.fromMaterial(theme),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Align(
                      alignment: Alignment.topLeft,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
