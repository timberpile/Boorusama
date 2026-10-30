import 'package:boorusama/core/posts/listing/src/widgets/post_list_configuration_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: BooruLocalization(
          child: MaterialApp(
            builder: (context, child) =>
                // ignore: deprecated_member_use
                MaterialUiCompatibilityBridge(
                  child: KurumiTheme(
                    data: KurumiThemeData.fromMaterial(Theme.of(context)),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: child!,
                    ),
                  ),
                ),
            home: Scaffold(
              body: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('horizontal scrolling leaves overflow fixed at scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        PostListConfigurationHeader(
          hiddenCount: 12345,
          postCount: 987654321,
          hasBlacklist: true,
          blacklistControls: const Text('Rules'),
          trailing: IconButton(
            key: const ValueKey('fixed-overflow'),
            tooltip: 'More',
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ),
        scale: scale,
      );
      final before = tester.getTopRight(
        find.byKey(const ValueKey('fixed-overflow')),
      );
      await tester.drag(
        find.byKey(const ValueKey('timeline-toolbar-content')),
        const Offset(-250, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopRight(find.byKey(const ValueKey('fixed-overflow'))),
        before,
      );
      expect(
        find.byKey(const ValueKey('fixed-overflow')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'zero hidden remains actionable and popup does not resize toolbar',
    (tester) async {
      await pump(
        tester,
        const PostListConfigurationHeader(
          hiddenCount: 0,
          postCount: 10,
          hasBlacklist: true,
          blacklistControls: Text('Temporarily revealed rule'),
        ),
      );
      final toolbar = find.byType(PostListConfigurationHeader);
      final height = tester.getSize(toolbar).height;
      await tester.tap(find.byKey(const ValueKey('timeline-blacklist-button')));
      await tester.pumpAndSettle();
      expect(find.text('Temporarily revealed rule'), findsOneWidget);
      expect(tester.getSize(toolbar).height, height);
      expect(find.text('0'), findsOneWidget);
      await tester.tapAt(const Offset(310, 500));
      await tester.pumpAndSettle();
      expect(find.text('Temporarily revealed rule'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no matches keeps count but omits blacklist action', (
    tester,
  ) async {
    await pump(
      tester,
      const PostListConfigurationHeader(
        hiddenCount: 0,
        postCount: 5,
        blacklistControls: SizedBox.shrink(),
      ),
    );
    expect(
      find.byKey(const ValueKey('timeline-blacklist-button')),
      findsNothing,
    );
    expect(find.textContaining('5'), findsOneWidget);
  });
}
