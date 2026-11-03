import 'package:boorusama/core/posts/pools/pool_grid_item.dart';
import 'package:boorusama/core/config_widgets/website_logo.dart';
import 'package:boorusama/core/images/providers.dart';
import 'package:boorusama/core/developer_options/providers.dart';
import 'package:boorusama/core/posts/sources/types.dart';

import '../../../application/support/fake_image_dio.dart';
import '../details/progressive_image_test_utils.dart';

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
    Widget? sourceIcon,
    VoidCallback? onTap,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deterministicFaviconDioOverride(),
          defaultImageCacheManagerProvider.overrideWithValue(
            TestImageCache({
              PostSource.from('https://example.test')
                      .whenWeb((s) => s.faviconUrl, () => ''):
                  lowerPng,
              'https://icons.test/custom.png': lowerPng,
            }),
          ),
          automaticMediaLoadingEnabledProvider.overrideWithValue(true),
        ],
        child: BooruLocalization(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: Directionality(
                      textDirection: direction,
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
                              ? sourceIcon ??
                                    const ColoredBox(color: Colors.blue)
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
      ),
    );
    if (sourceIcon != null) {
      await tester.runAsync(
        () => pumpUntil(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
          reason: 'decoded source icon',
        ),
      );
    }
    await tester.pumpAndSettle();
  }

  for (final kind in PoolGridItemKind.values) {
    testWidgets('uses the white $kind icon without a type text label', (
      tester,
    ) async {
      await showTile(tester, kind: kind);
      final icon = find.byKey(ValueKey('pool-kind-' + kind.name));
      expect(icon, findsOneWidget);
      expect(tester.widget<SvgPicture>(icon).width, 16);
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
    expect(source.size, const Size(24, 24));
    expect(badge.height, 24);
    expect(source.top, badge.top);
    expect(source.bottom, badge.bottom);
    expect(badge.left - source.right, 4);
    expect(source.left - tile.left, 6);
    expect(source.top - tile.top, 6);
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
      width: 140,
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

  testWidgets('RTL overlay mirrors the shared 24 dp geometry', (tester) async {
    await showTile(
      tester,
      kind: PoolGridItemKind.related,
      direction: TextDirection.rtl,
      textScale: 2,
    );
    final source = tester.getRect(
      find.byKey(const ValueKey('pool-source-icon')),
    );
    final badge = tester.getRect(find.byKey(const ValueKey('pool-badge')));
    final tile = tester.getRect(find.byType(PoolGridItem));
    expect(source.size, const Size(24, 24));
    expect(badge.height, 24);
    expect(source.top, badge.top);
    expect(source.left - badge.right, 4);
    expect(tile.right - source.right, 6);
    expect(source.top - tile.top, 6);
    expect(tester.takeException(), isNull);
  });

  for (final variant in ['favicon', 'custom', 'fallback']) {
    testWidgets(
      '$variant source rendering retains the shared overlay geometry',
      (tester) async {
        await showTile(
          tester,
          kind: PoolGridItemKind.related,
          sourceIcon: ConfigAwareWebsiteLogo(
            url: variant == 'fallback' ? null : 'https://example.test',
            customIconUrl: variant == 'custom'
                ? 'https://icons.test/custom.png'
                : null,
            fit: BoxFit.contain,
          ),
        );
        final source = tester.getRect(
          find.byKey(const ValueKey('pool-source-icon')),
        );
        final badge = tester.getRect(find.byKey(const ValueKey('pool-badge')));
        expect(source.size, const Size(24, 24));
        expect(tester.getRect(find.byType(ConfigAwareWebsiteLogo)), source);
        expect(source.top, badge.top);
        expect(source.bottom, badge.bottom);
        expect(badge.left - source.right, 4);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
