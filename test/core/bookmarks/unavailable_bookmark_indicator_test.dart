import 'package:boorusama/core/bookmarks/src/widgets/bookmark_unavailable_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/src/gen/strings.g.dart' show TranslationProvider;
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'missing-profile popup exposes per-site counts and updates while open',
    (tester) async {
      var counts = const {'rule34.xxx': 2, 'realbooru.com': 1};
      late StateSetter update;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BookmarkUnavailableIndicator(counts: counts);
          },
        ),
      );
      final semantics = tester.ensureSemantics();
      final button = find.byKey(const ValueKey('bookmark-unavailable-button'));
      expect(tester.getSemantics(button).label, 'Unavailable: 3');
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('rule34.xxx'), findsOneWidget);
      expect(find.text('realbooru.com'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('A matching profile is required.'), findsOneWidget);
      expect(
        find.text('These posts are still saved and included in exports.'),
        findsNothing,
      );
      update(() => counts = const {'rule34.xxx': 1});
      await tester.pumpAndSettle();
      expect(tester.getSemantics(button).label, 'Unavailable: 1');
      expect(find.text('realbooru.com'), findsNothing);
      update(() => counts = const {});
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      expect(find.text('Unavailable posts'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('site popup fits narrow width, enlarged text and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await _pump(
      tester,
      const BookmarkUnavailableIndicator(
        counts: {
          'a-very-long-website-name-for-unavailable-bookmarks.example.com':
              12345,
          '': 1,
        },
      ),
      scale: 2,
    );
    await tester.tap(find.byKey(const ValueKey('bookmark-unavailable-button')));
    await tester.pumpAndSettle();
    expect(find.text('Unknown website'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        builder: (context, child) => KurumiTheme(
          data: KurumiThemeData.fromMaterial(Theme.of(context)),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
