import 'package:boorusama/core/bookmarks/src/widgets/bookmark_seen_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final columns in [2, 5]) {
      testWidgets(
        '14dp borderless Unseen overlay at 320dp, 200% text, $columns columns, $brightness',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 700);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var taps = 0;
          final theme = ThemeData(brightness: brightness);
          Future<void> pump({bool selecting = false, bool unseen = true}) =>
              tester.pumpWidget(
                BooruLocalization(
                  child: MaterialApp(
                    theme: theme,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(2)),
                      child: KurumiTheme(
                        data: KurumiThemeData.fromMaterial(theme),
                        child: child!,
                      ),
                    ),
                    home: Scaffold(
                      body: GridView.count(
                        crossAxisCount: columns,
                        children: [
                          BookmarkSeenIndicator(
                            unseen: unseen,
                            selecting: selecting,
                            child: InkWell(
                              onTap: () => taps++,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
          await pump();
          final badge = find.byKey(const ValueKey('bookmark-unseen-dot'));
          final indicator = find.byType(BookmarkSeenIndicator);
          expect(
            tester.getSize(badge),
            const Size.square(14),
          );
          final bounds = tester.getRect(indicator);
          final mark = tester.getRect(badge);
          expect(mark.top - bounds.top, 6);
          expect(bounds.right - mark.right, 6);
          final decoration =
              tester.widget<Container>(badge).decoration! as BoxDecoration;
          expect(decoration.border, isNull);
          expect(decoration.shape, BoxShape.circle);
          final semantics = tester.ensureSemantics();
          expect(find.bySemanticsLabel('Unseen'), findsOneWidget);
          await tester.tapAt(mark.center);
          expect(
            taps,
            1,
            reason: 'The badge must not intercept thumbnail gestures',
          );
          semantics.dispose();
          await pump(selecting: true);
          expect(
            badge,
            findsNothing,
            reason: 'Preview owns the top-right during selection',
          );
          await pump(unseen: false);
          expect(badge, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
