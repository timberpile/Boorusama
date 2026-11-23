import 'package:boorusama/core/bookmarks/src/services/bookmark_read_projection.dart';
import 'package:boorusama/core/bookmarks/src/widgets/bookmark_seen_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

void main() {
  testWidgets(
    'Read Status Eye stays fixed across all choices at 320dp and 200% text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var value = BookmarkSeenFilter.all;
      await tester.pumpWidget(
        BooruLocalization(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: KurumiTheme(
                data: KurumiThemeData.fromMaterial(Theme.of(context)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, update) => BookmarkSeenFilterButton(
                    value: value,
                    onSelected: (next) => update(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Read Status: All'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      for (final choice in ['Unseen', 'Seen', 'All']) {
        await tester.tap(find.byType(BookmarkSeenFilterButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice).last);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Read Status: $choice'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(value, BookmarkSeenFilter.all);
    },
  );
}
