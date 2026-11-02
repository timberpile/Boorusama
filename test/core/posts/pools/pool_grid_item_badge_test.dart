import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/material.dart';

void main() {
  Future<void> showTile(
    WidgetTester tester, {
    required PoolGridItemKind kind,
    double width = 190,
    double textScale = 1,
    int? total = 29,
    int? displayedCount,
    bool withSource = true,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: BooruLocalization(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: SizedBox(
                      width: width,
                      height: 160,
                      child: PoolGridItem(
                        image: const ColoredBox(color: Colors.blueGrey),
                        name: null,
                        total: total,
                        displayedCount: displayedCount,
                        kind: kind,
                        sourceIcon: withSource
                            ? const ColoredBox(color: Colors.blue)
                            : null,
                        onTap: onTap ?? () {},
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

  for (final kind in PoolGridItemKind.values) {
    testWidgets('uses the white $kind icon without a type text label', (
      tester,
    ) async {
      await showTile(tester, kind: kind);
      final icon = find.byKey(ValueKey('pool-kind-' + kind.name));
      expect(icon, findsOneWidget);
      expect(tester.widget<SvgPicture>(icon).width, 18);
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text(kind.name), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('source is left of type and the right corner stays free', (
    tester,
  ) async {
    await showTile(tester, kind: PoolGridItemKind.collection);
    final source = tester.getRect(
      find.byKey(const ValueKey('pool-source-icon')),
    );
    final badge = tester.getRect(find.byKey(const ValueKey('pool-badge')));
    final tile = tester.getRect(find.byType(PoolGridItem));
    expect(source.right, lessThan(badge.left));
    expect(badge.right, lessThan(tile.right - 4));
    expect(find.text('29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial count falls back to total before hiding the icon', (
    tester,
  ) async {
    await showTile(
      tester,
      kind: PoolGridItemKind.series,
      width: 260,
      total: 987654,
      displayedCount: 98765,
    );
    expect(find.text('98765/987654'), findsOneWidget);

    await showTile(
      tester,
      kind: PoolGridItemKind.series,
      width: 160,
      total: 987654,
      displayedCount: 98765,
    );
    expect(find.text('98765/987654'), findsNothing);
    expect(find.text('987654'), findsOneWidget);

    await showTile(
      tester,
      kind: PoolGridItemKind.series,
      width: 76,
      textScale: 2,
      total: 987654,
      displayedCount: 98765,
    );
    expect(find.text('98765/987654'), findsNothing);
    expect(find.text('987654'), findsNothing);
    expect(find.byKey(const ValueKey('pool-kind-series')), findsOneWidget);
    expect(find.byKey(const ValueKey('pool-source-icon')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the badge still activates the underlying card', (
    tester,
  ) async {
    var taps = 0;
    await showTile(
      tester,
      kind: PoolGridItemKind.collection,
      onTap: () => taps++,
    );
    await tester.tapAt(
      tester.getRect(find.byKey(const ValueKey('pool-badge'))).center,
    );
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown total remains explicit in accessibility text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await showTile(
      tester,
      kind: PoolGridItemKind.related,
      total: null,
      displayedCount: 5,
    );
    expect(find.text('5/?'), findsOneWidget);
    expect(find.bySemanticsLabel('Related Posts · 5/?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
